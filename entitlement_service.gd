class_name EntitlementService
extends Node

# Subscription entitlement, as verified by Google Play / the App Store. Hosted
# as a child of the SaveManager autoload (no autoload of its own), one shared
# billing client for the whole app.
#
# Policy (product owner, final):
#   - Valid subscription = premium access. Expired = none.
#   - Access is whatever the STORE last said. There are no app-managed grace
#     periods, no legacy allowances and no time extensions; a connectivity
#     problem never creates an entitlement. A fresh launch starts UNVERIFIED
#     (no premium) until the store answers; the saved `subscribed` flag from
#     earlier builds is NOT evidence and is never read for access.
#   - Confirmed loss (a clean "not entitled" answer) interrupts all premium
#     gameplay immediately. An UNKNOWN answer (offline, store error, time-out)
#     changes nothing and interrupts nothing: it is not confirmed loss.
#   - Billing grace period / retry / account hold are the STORE's business: the
#     store keeps or drops the subscription and we only read the answer.
#
# Ordering (no silence windows): every request has a generation; only the latest
# generation may change state. A purchase / restore / transaction event bumps an
# event counter; an answer issued before the latest event may predate it, so it
# is discarded and the question asked again. The first "not entitled" answer
# that follows a purchase/restore confirmation is verified once more before
# access is revoked. Refunds and revocations stay effective because any answer
# issued after the event applies at once.

signal entitlement_changed(entitled: bool)
signal entitlement_lost
signal entitlement_gained
signal verification_settled
signal restore_finished(result: int)

enum State { UNVERIFIED, ENTITLED, NOT_ENTITLED }
enum Result { ENTITLED, NOT_ENTITLED, UNKNOWN }

const ANDROID_PRODUCT_ID : String = "soundhop_subscription"
const IOS_PRODUCT_IDS : Array[String] = [
	"com.acron.learningsounds.monthly",
	"com.acron.learningsounds.yearly",
]
const PERIODIC_REFRESH_SEC : float = 900.0   # re-check while entitled and the app stays open
const REQUEST_TIMEOUT_SEC  : float = 20.0    # no answer in time = UNKNOWN

var state : int = State.UNVERIFIED

# Tests only: when set, replaces the platform query. Called as
# fake_store.call(generation, explicit); the test answers with deliver().
var fake_store : Callable = Callable()

var _event_epoch       : int  = 0
var _gen               : int  = 0
var _pending_gen       : int  = 0
var _pending_epoch     : int  = 0
var _pending_explicit  : bool = false
var _confirmed_by_event : bool = false   # access was granted by a purchase/restore event, not yet corroborated by a query

var _timeout_timer  : Timer = null
var _periodic_timer : Timer = null

var _billing           : BillingClient = null
var _billing_connected : bool = false

var _storekit          : GDScriptStoreKit2 = null
var _ios_seen          : Dictionary = {}
var _ios_errors        : int  = 0
var _ios_sync_pending  : bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while a scene has the tree paused
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_request_timeout)
	add_child(_timeout_timer)
	_periodic_timer = Timer.new()
	_periodic_timer.wait_time = PERIODIC_REFRESH_SEC
	_periodic_timer.one_shot = false
	_periodic_timer.timeout.connect(_on_periodic)
	add_child(_periodic_timer)

	match OS.get_name():
		"Android": _android_init()
		"iOS":     _ios_init()
	# QA convenience only: a developer build on a desktop has no store to ask.
	# DebugConfig.DEBUG_MODE is false in every committed and release build.
	if DebugConfig.DEBUG_MODE and not _has_store():
		state = State.ENTITLED
	refresh("launch")


func is_entitled() -> bool:
	return state == State.ENTITLED


func is_pending() -> bool:
	return _pending_gen != 0


func billing_client() -> BillingClient:
	return _billing


func storekit() -> GDScriptStoreKit2:
	return _storekit


func is_billing_connected() -> bool:
	return _billing_connected


# Waits (at most one request time-out) for the first store answer after launch,
# so an entry point does not turn a subscriber away during the launch query.
# Returns at once when state is already known or nothing is in flight. This
# waits for the STORE; it never grants anything by itself.
func settle() -> void:
	if state != State.UNVERIFIED or _pending_gen == 0:
		return
	await verification_settled


# ─── Asking the store ─────────────────────────────────────────────────────────
func refresh(_reason: String = "") -> void:
	if _pending_gen != 0:
		return   # a question is already in flight; its answer covers this
	_issue(false)


# Explicit Restore: user-initiated, supersedes any automatic request, and its
# answer is authoritative. Completion is reported through restore_finished.
func restore() -> void:
	_issue(true)


func _has_store() -> bool:
	return fake_store.is_valid() or _billing != null or _storekit != null


func _issue(explicit: bool) -> void:
	if not _has_store():
		verification_settled.emit()
		if explicit:
			restore_finished.emit(Result.UNKNOWN)
		return
	_gen += 1
	_pending_gen      = _gen
	_pending_epoch    = _event_epoch
	_pending_explicit = explicit
	_timeout_timer.start(REQUEST_TIMEOUT_SEC)
	if fake_store.is_valid():
		fake_store.call(_pending_gen, explicit)
	elif _billing != null:
		_android_request()
	elif _storekit != null:
		_ios_request(explicit)


func _clear_pending() -> void:
	_pending_gen = 0
	_ios_sync_pending = false
	if _timeout_timer != null:
		_timeout_timer.stop()


func _on_request_timeout() -> void:
	if _pending_gen == 0:
		return
	var explicit : bool = _pending_explicit
	_clear_pending()
	verification_settled.emit()
	if explicit:
		restore_finished.emit(Result.UNKNOWN)


func _on_periodic() -> void:
	refresh("periodic")


# The store's answer to request `gen`. Anything but the latest generation is
# discarded.
func deliver(gen: int, result: int) -> void:
	if gen != _pending_gen:
		return
	var explicit : bool = _pending_explicit
	var stale : bool = _event_epoch != _pending_epoch
	_clear_pending()
	if result == Result.UNKNOWN:
		verification_settled.emit()
		if explicit:
			restore_finished.emit(Result.UNKNOWN)
		return
	if stale:
		# A purchase, restore or refund happened after this question was asked.
		# Its answer may predate that event, so ask again.
		_issue(explicit)
		return
	_apply(result, explicit)


func _apply(result: int, explicit: bool) -> void:
	if result == Result.ENTITLED:
		_confirmed_by_event = false
		_set_state(State.ENTITLED)
	else:
		if not explicit and _confirmed_by_event and state == State.ENTITLED:
			# The first "not entitled" after a purchase/restore confirmed access:
			# verify once before revoking (covers store lag, no silence window).
			_confirmed_by_event = false
			_issue(false)
			return
		_confirmed_by_event = false
		_set_state(State.NOT_ENTITLED)
	verification_settled.emit()
	if explicit:
		restore_finished.emit(result)


# ─── Events that change the entitlement picture ───────────────────────────────
# A purchase, a restore or a StoreKit transaction confirmed access.
func confirm_entitled() -> void:
	_event_epoch += 1
	_confirmed_by_event = true
	_set_state(State.ENTITLED)
	verification_settled.emit()


# A refund / revocation / expiry event: re-check. Any answer issued after this
# event applies at once.
func note_revocation() -> void:
	_event_epoch += 1
	_confirmed_by_event = false
	refresh("revocation")


# Test / QA hook: sets the state without interrupting anything.
func debug_set_state(entitled: bool) -> void:
	state = State.ENTITLED if entitled else State.NOT_ENTITLED
	_confirmed_by_event = false
	SaveManager.mirror_entitlement(entitled)
	_update_periodic()


func _set_state(new_state: int) -> void:
	var old : int = state
	if new_state == old:
		return
	state = new_state
	SaveManager.mirror_entitlement(new_state == State.ENTITLED)
	_update_periodic()
	entitlement_changed.emit(new_state == State.ENTITLED)
	if new_state == State.ENTITLED:
		entitlement_gained.emit()
	else:
		if old == State.ENTITLED:
			entitlement_lost.emit()
		_interrupt_premium()


func _update_periodic() -> void:
	if _periodic_timer == null:
		return
	if state == State.ENTITLED:
		if _periodic_timer.is_stopped():
			_periodic_timer.start()
	else:
		_periodic_timer.stop()


# Confirmed loss: every premium gameplay scene stops now. Nothing is written.
func _interrupt_premium() -> void:
	var tree : SceneTree = get_tree()
	if tree == null:
		return
	tree.call_group(PremiumGameplay.GROUP, "interrupt_for_entitlement_loss")
	var scene : Node = tree.current_scene
	if scene != null and PremiumGameplay.is_registered(scene.scene_file_path) \
			and not scene.has_method("interrupt_for_entitlement_loss"):
		PremiumGameplay.route_to_paywall(tree)


# ─── Android (Google Play Billing) ────────────────────────────────────────────
func _android_init() -> void:
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	_billing = BillingClient.new()
	add_child(_billing)
	_billing.connected.connect(_on_android_connected)
	_billing.disconnected.connect(_on_android_disconnected)
	_billing.connect_error.connect(_on_android_connect_error)
	_billing.query_purchases_response.connect(_on_android_query_response)
	_billing.on_purchase_updated.connect(_on_android_purchase_updated)
	_billing.start_connection()


func _android_request() -> void:
	if _billing_connected:
		_billing.query_purchases(BillingClient.ProductType.SUBS)
	else:
		_billing.start_connection()   # the query goes out as soon as the connection is up


func _on_android_connected() -> void:
	_billing_connected = true
	if _pending_gen != 0:
		_billing.query_purchases(BillingClient.ProductType.SUBS)


# A purchase completed (from the plan screen, or out of band). PURCHASED is
# confirmation straight from Play; acknowledge it in the background.
func _on_android_purchase_updated(response: Dictionary) -> void:
	if response.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		return
	for purchase in response.get("purchases", []):
		var product_ids = purchase.get("product_ids", null)
		if product_ids != null and not (ANDROID_PRODUCT_ID in product_ids):
			continue
		if purchase.get("purchase_state", -1) == BillingClient.PurchaseState.PURCHASED:
			if not purchase.get("is_acknowledged", false):
				_billing.acknowledge_purchase(purchase.get("purchase_token", ""))
			confirm_entitled()
			return


func _on_android_disconnected() -> void:
	_billing_connected = false


func _on_android_connect_error(_code: int, _message: String) -> void:
	_billing_connected = false
	if _pending_gen != 0:
		deliver(_pending_gen, Result.UNKNOWN)


# Only a response code of OK is an answer. A listed PURCHASED subscription is
# ENTITLED; an OK response without one is NOT_ENTITLED. Billing grace is the
# store's call (the purchase stays listed); account-hold subscriptions are not
# listed (include_suspended_subs stays false). Anything else is UNKNOWN.
func _on_android_query_response(response: Dictionary) -> void:
	if response.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		if _pending_gen != 0:
			deliver(_pending_gen, Result.UNKNOWN)
		return
	var entitled : bool = false
	for purchase in response.get("purchases", []):
		var product_ids = purchase.get("product_ids", null)
		if product_ids != null and not (ANDROID_PRODUCT_ID in product_ids):
			continue
		if purchase.get("purchase_state", -1) == BillingClient.PurchaseState.PURCHASED:
			entitled = true
			if not purchase.get("is_acknowledged", false):
				_billing.acknowledge_purchase(purchase.get("purchase_token", ""))
	if _pending_gen != 0:
		deliver(_pending_gen, Result.ENTITLED if entitled else Result.NOT_ENTITLED)


# ─── iOS (StoreKit 2) ─────────────────────────────────────────────────────────
func _ios_init() -> void:
	_storekit = GDScriptStoreKit2.new()
	_storekit.product_info_received.connect(_on_ios_product_info)
	_storekit.transaction_state_changed.connect(_on_ios_transaction)
	_storekit.synchronized.connect(_on_ios_synchronized)


func _ios_request(explicit: bool) -> void:
	_ios_seen.clear()
	_ios_errors = 0
	if explicit:
		_ios_sync_pending = true
		_storekit.sync()   # AppStore.sync(); the queries follow once it reports back
	else:
		_ios_send_queries()


func _ios_send_queries() -> void:
	for product_id in IOS_PRODUCT_IDS:
		_storekit.request_product_info(product_id)


# iOS only (connected in _ios_init). `error` is the native AppStore.sync()
# failure description, empty when the sync completed cleanly.
func _on_ios_synchronized(error: String) -> void:
	if not (_ios_sync_pending and _pending_gen != 0):
		return
	_ios_sync_pending = false
	if not error.is_empty():
		# The store could not complete the sync. That is not a clean
		# NOT_ENTITLED answer, so nothing is known: UNKNOWN changes no state
		# and interrupts nothing, per the existing contract.
		deliver(_pending_gen, Result.UNKNOWN)
		return
	_ios_send_queries()


# Either product purchased = ENTITLED. NOT_ENTITLED needs a clean answer for
# BOTH products. Any error leaves the outcome UNKNOWN. Answers are keyed by
# product id, so duplicate lookups from other screens cannot skew the result.
func _on_ios_product_info(info: GDScriptStoreKit2.ProductInfo) -> void:
	if _pending_gen == 0 or _ios_sync_pending:
		return
	if not info.error.is_empty():
		_ios_errors += 1
	elif info.product_id in IOS_PRODUCT_IDS:
		_ios_seen[info.product_id] = info.is_purchased
	var any_purchased : bool = false
	for purchased in _ios_seen.values():
		if purchased:
			any_purchased = true
	if any_purchased:
		deliver(_pending_gen, Result.ENTITLED)
	elif _ios_seen.size() >= IOS_PRODUCT_IDS.size():
		deliver(_pending_gen, Result.NOT_ENTITLED)
	elif _ios_seen.size() + _ios_errors >= IOS_PRODUCT_IDS.size():
		deliver(_pending_gen, Result.UNKNOWN)


func _on_ios_transaction(transaction: GDScriptStoreKit2.TransactionData) -> void:
	if not transaction.error.is_empty() or not (transaction.product_id in IOS_PRODUCT_IDS):
		return
	match transaction.transaction_state:
		GDScriptStoreKit2.TransactionState.PURCHASED, GDScriptStoreKit2.TransactionState.RESTORED:
			confirm_entitled()
		GDScriptStoreKit2.TransactionState.REFUNDED, GDScriptStoreKit2.TransactionState.EXPIRED:
			note_revocation()
