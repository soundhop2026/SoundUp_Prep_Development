extends Node2D

# ─── Choose Your Plan Scene ─────────────────────────────────────────────────
# Reached only after Parent Gate verification succeeds (press-and-hold on
# premium_intro.tscn). This scene is where the actual purchase decision
# happens — Monthly, Yearly, Restore Purchases, or Not Now.
#
# Layout: side-by-side outlined cards (approved over the earlier stacked
# solid-purple version) — easier at-a-glance comparison, lighter/more
# consistent with the rest of the app's cream-and-line-art look.
#
# BILLING — real integration, Android only (GodotGooglePlayBilling plugin
# v3.3.0, addons/GodotGooglePlayBilling/). iOS StoreKit is separate,
# not-yet-started work — _is_billing_supported_platform() below still gates
# on ["Android", "iOS"], so on iOS this currently falls through to the
# "Subscriptions Not Available" dialog until that integration exists.
#
# ── Google Play Console setup required before this works on a real device ──
# ONE subscription product with TWO base plans (Google's recommended catalog
# model — not two separate subscription products) so a monthly<->yearly
# switch is a native in-subscription plan change, not two overlapping
# subscriptions. These IDs must be created to match EXACTLY (case-sensitive)
# in Play Console -> Monetize -> Products -> Subscriptions, or every purchase
# attempt fails with ITEM_UNAVAILABLE / DEVELOPER_ERROR:
#   Subscription product ID: "soundhop_subscription"
#     Base plan ID: "monthly"   $9.99
#     Base plan ID: "yearly"    $99.99
# App also needs an internal testing track live with a license tester
# account added before ANY purchase (even a test one) can succeed.
#
# Routing contract (unchanged from the stub):
#   success -> continue directly to the next set
#   cancel  -> return to this same scene, no progress lost
# ─────────────────────────────────────────────────────────────────────────────

const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"

const BG_COLOR    : Color = Color("#FDF0E4")
const PURPLE      : Color = Color("#4B0082")
const AMBER       : Color = Color("#FFB703")
const GRAY_TEXT   : Color = Color(0.4, 0.36, 0.42)

const CARD_W : float = 320.0
const CARD_H : float = 230.0
const CARD_GAP : float = 40.0
const CARDS_Y : float = 150.0

const SUBSCRIPTION_PRODUCT_ID : String = "soundhop_subscription"   # one product, two base plans below
const MONTHLY_BASE_PLAN_ID : String = "monthly"
const YEARLY_BASE_PLAN_ID  : String = "yearly"

var _font : Font = null
var _billing : BillingClient = null
var _billing_ready : bool = false   # true once query_product_details_response confirms the subscription product exists

func _base_plan_id(plan_id: String) -> String:
	return MONTHLY_BASE_PLAN_ID if plan_id == "monthly" else YEARLY_BASE_PLAN_ID


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	SceneBackground.set_color(BG_COLOR)
	_init_billing()

	var bg := ColorRect.new()
	bg.color        = BG_COLOR
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_make_label("SoundHop", Vector2(0, 16), Vector2(1280, 56),
		40, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
	_make_label("Choose Your Plan", Vector2(0, 76), Vector2(1280, 36),
		26, PURPLE, HORIZONTAL_ALIGNMENT_CENTER)

	_build_monthly_card()
	_build_yearly_card()
	_build_restore_btn()
	_build_not_now_btn()
	_build_platform_note()
	_build_copyright_label()


func _build_monthly_card() -> void:
	var start_x : float = (1280.0 - (CARD_W * 2.0 + CARD_GAP)) / 2.0
	var card := _make_card(Vector2(start_x, CARDS_Y))

	_make_label("Monthly", Vector2(0, 22), Vector2(CARD_W, 32),
		22, PURPLE, HORIZONTAL_ALIGNMENT_CENTER, card)
	_make_label("Full Access", Vector2(0, 58), Vector2(CARD_W, 24),
		15, GRAY_TEXT, HORIZONTAL_ALIGNMENT_CENTER, card)
	_price_label(card, "$9.99", "/month", 100.0)

	var btn := _card_button()
	btn.pressed.connect(_purchase_plan.bind("monthly", card))
	card.add_child(btn)


func _build_yearly_card() -> void:
	var start_x : float = (1280.0 - (CARD_W * 2.0 + CARD_GAP)) / 2.0
	var card := _make_card(Vector2(start_x + CARD_W + CARD_GAP, CARDS_Y))

	_make_label("★ Best Value", Vector2(0, 16), Vector2(CARD_W, 22),
		14, AMBER, HORIZONTAL_ALIGNMENT_CENTER, card)
	_make_label("Yearly", Vector2(0, 40), Vector2(CARD_W, 32),
		22, PURPLE, HORIZONTAL_ALIGNMENT_CENTER, card)
	_make_label("Full Access", Vector2(0, 76), Vector2(CARD_W, 24),
		15, GRAY_TEXT, HORIZONTAL_ALIGNMENT_CENTER, card)
	_price_label(card, "$99.99", "/year", 118.0)
	_make_label("Pay for 10 months.\nGet 2 months free.", Vector2(0, 158), Vector2(CARD_W, 44),
		13, GRAY_TEXT, HORIZONTAL_ALIGNMENT_CENTER, card)

	var btn := _card_button()
	btn.pressed.connect(_purchase_plan.bind("yearly", card))
	card.add_child(btn)


func _price_label(card: Panel, price: String, suffix: String, y: float) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled  = true
	rtl.fit_content     = false
	rtl.scroll_active   = false
	rtl.position        = Vector2(0, y)
	rtl.size            = Vector2(CARD_W, 40)
	rtl.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	if _font:
		rtl.add_theme_font_override("normal_font", _font)
		rtl.add_theme_font_override("bold_font", _font)
	rtl.add_theme_color_override("default_color", PURPLE)
	rtl.text = "[center][font_size=30]%s[/font_size][font_size=15]%s[/font_size][/center]" % [price, suffix]
	card.add_child(rtl)


func _make_card(pos: Vector2) -> Panel:
	var card := Panel.new()
	card.position     = pos
	card.size         = Vector2(CARD_W, CARD_H)
	card.pivot_offset = Vector2(CARD_W, CARD_H) / 2.0
	var sty := StyleBoxFlat.new()
	sty.bg_color                   = BG_COLOR
	sty.border_color               = PURPLE
	sty.border_width_left          = 2
	sty.border_width_right         = 2
	sty.border_width_top           = 2
	sty.border_width_bottom        = 2
	sty.corner_radius_top_left     = 16
	sty.corner_radius_top_right    = 16
	sty.corner_radius_bottom_left  = 16
	sty.corner_radius_bottom_right = 16
	card.add_theme_stylebox_override("panel", sty)
	add_child(card)
	return card


func _card_button() -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.size = Vector2(CARD_W, CARD_H)
	var blank := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(s, blank)
	return btn


func _pill_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text     = text
	btn.position = pos
	btn.size     = size
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color",         PURPLE)
	btn.add_theme_color_override("font_hover_color",   AMBER)
	btn.add_theme_color_override("font_pressed_color", AMBER)
	btn.add_theme_color_override("font_focus_color",   PURPLE)
	var sty := StyleBoxFlat.new()
	sty.bg_color                   = BG_COLOR
	sty.border_color               = PURPLE
	sty.border_width_left          = 2
	sty.border_width_right         = 2
	sty.border_width_top           = 2
	sty.border_width_bottom        = 2
	sty.corner_radius_top_left     = int(size.y / 2.0)
	sty.corner_radius_top_right    = int(size.y / 2.0)
	sty.corner_radius_bottom_left  = int(size.y / 2.0)
	sty.corner_radius_bottom_right = int(size.y / 2.0)
	for s in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(s, sty)
	add_child(btn)
	return btn


func _build_restore_btn() -> void:
	const W : float = 360.0
	const H : float =  50.0
	var btn := _pill_button("↻  Restore Purchases", Vector2((1280.0 - W) / 2.0, 410.0), Vector2(W, H))
	btn.pressed.connect(_on_restore_pressed)


func _build_not_now_btn() -> void:
	const W : float = 360.0
	const H : float =  50.0
	var btn := _pill_button("Not Now", Vector2((1280.0 - W) / 2.0, 470.0), Vector2(W, H))
	btn.pressed.connect(_on_not_now_pressed)


func _build_platform_note() -> void:
	_make_label("Subscriptions are available on Android phones, tablets, and iPhone/iPad.",
		Vector2(0, 534), Vector2(1280, 24), 14, GRAY_TEXT, HORIZONTAL_ALIGNMENT_CENTER)


# ─── Billing ─────────────────────────────────────────────────────────────────
func _is_billing_supported_platform() -> bool:
	return OS.get_name() in ["Android", "iOS"]


# GodotGooglePlayBilling's BillingClient safely no-ops everywhere (its own
# _plugin_singleton stays null) on any platform other than a real Android
# export, so it's safe to always instantiate/connect here rather than
# gating construction itself — only the actual purchase/restore ACTIONS
# need the OS.get_name() == "Android" gate, matching where real money
# could move.
func _init_billing() -> void:
	if OS.get_name() != "Android":
		return
	_billing = BillingClient.new()
	add_child(_billing)
	_billing.connected.connect(_on_billing_connected)
	_billing.connect_error.connect(_on_billing_connect_error)
	_billing.query_product_details_response.connect(_on_query_product_details_response)
	_billing.query_purchases_response.connect(_on_query_purchases_response)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.acknowledge_purchase_response.connect(_on_acknowledge_purchase_response)
	_billing.start_connection()


func _on_billing_connected() -> void:
	_billing.query_product_details(
		PackedStringArray([SUBSCRIPTION_PRODUCT_ID]), BillingClient.ProductType.SUBS)


func _on_billing_connect_error(response_code: int, debug_message: String) -> void:
	printerr("[billing] connect_error ", response_code, ": ", debug_message)


func _on_query_product_details_response(response: Dictionary) -> void:
	if response.get("response_code", -1) == BillingClient.BillingResponseCode.OK:
		_billing_ready = true
	else:
		printerr("[billing] query_product_details failed: ", response)


func _highlight_card(card: Panel) -> void:
	var t := create_tween()
	t.tween_property(card, "scale", Vector2(1.04, 1.04), 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_IN)


func _purchase_plan(plan_id: String, card: Panel) -> void:
	_highlight_card(card)

	if not _is_billing_supported_platform():
		await get_tree().create_timer(0.15).timeout   # let the highlight register first
		_show_unsupported_platform_dialog()
		return

	if OS.get_name() != "Android" or _billing == null or not _billing_ready:
		# Not yet connected/product details not confirmed (e.g. brand-new
		# connection still in flight, or Play Store unreachable) — iOS also
		# lands here for now since StoreKit isn't wired in yet.
		await get_tree().create_timer(0.15).timeout
		_show_unsupported_platform_dialog()
		return

	var result : Dictionary = _billing.purchase_subscription(SUBSCRIPTION_PRODUCT_ID, _base_plan_id(plan_id))
	if result.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		printerr("[billing] purchase_subscription launch failed: ", result)
	# On success the native Play Billing dialog takes over; on_purchase_updated
	# fires with the result once the user completes or cancels it.


# Fires once per purchase attempt result, whether from this session's own
# purchase_subscription() call or (rarely) an out-of-band update.
func _on_purchase_updated(response: Dictionary) -> void:
	var code : int = response.get("response_code", -1)
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		_on_purchase_cancelled()
		return
	if code != BillingClient.BillingResponseCode.OK:
		printerr("[billing] on_purchase_updated error ", code, ": ", response)
		return
	for purchase in response.get("purchases", []):
		if purchase.get("purchase_state", -1) == BillingClient.PurchaseState.PURCHASED:
			# Acknowledge in the background — Google auto-refunds an
			# unacknowledged purchase within 3 days, but the UX doesn't wait
			# on it; access is granted the moment Play confirms PURCHASED.
			if not purchase.get("is_acknowledged", false):
				_billing.acknowledge_purchase(purchase.get("purchase_token", ""))
			_on_purchase_success()
			return


func _on_acknowledge_purchase_response(response: Dictionary) -> void:
	if response.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		printerr("[billing] acknowledge_purchase failed: ", response)


func _on_purchase_success() -> void:
	# Platform dialog is native and closes itself on success — nothing to
	# dismiss here. Unlock + save, then continue straight through, no
	# confirmation screen.
	SaveManager.set_subscribed(true)
	_continue_granted()


func _on_purchase_cancelled() -> void:
	pass   # native dialog closed itself — stay right here, no progress lost


func _on_restore_pressed() -> void:
	if SaveManager.is_subscribed():
		_continue_granted()
		return
	if OS.get_name() != "Android" or _billing == null:
		_show_no_purchases_dialog()
		return
	_billing.query_purchases(BillingClient.ProductType.SUBS)


func _on_query_purchases_response(response: Dictionary) -> void:
	if response.get("response_code", -1) != BillingClient.BillingResponseCode.OK:
		printerr("[billing] query_purchases failed: ", response)
		_show_no_purchases_dialog()
		return
	for purchase in response.get("purchases", []):
		if purchase.get("purchase_state", -1) == BillingClient.PurchaseState.PURCHASED:
			if not purchase.get("is_acknowledged", false):
				_billing.acknowledge_purchase(purchase.get("purchase_token", ""))
			SaveManager.set_subscribed(true)
			_continue_granted()
			return
	_show_no_purchases_dialog()


func _on_not_now_pressed() -> void:
	# Declining here returns to the Title Scene, not back into the Parent
	# Gate. prep_set_index is never advanced past Set 2 until the boundary is
	# actually passed, so this costs the player nothing — pressing Play again
	# routes straight back into Prep at Set 2, free to replay Set 1-2.
	get_tree().change_scene_to_file("res://title.tscn")


# ─── Simple dismissible message dialog — shared by the unsupported-platform
# ─── and no-purchases-found cases below ─────────────────────────────────────
func _show_message_dialog(title: String, body: String) -> void:
	var dim := ColorRect.new()
	dim.color        = Color(0.0, 0.0, 0.0, 0.55)
	dim.size         = get_viewport_rect().size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index      = 100
	add_child(dim)

	const CARD_W2 : float = 560.0
	const CARD_H2 : float = 260.0
	var card := Panel.new()
	card.position = Vector2((1280.0 - CARD_W2) / 2.0, (720.0 - CARD_H2) / 2.0)
	card.size     = Vector2(CARD_W2, CARD_H2)
	card.z_index  = 101
	var sty := StyleBoxFlat.new()
	sty.bg_color                   = BG_COLOR
	sty.border_color               = PURPLE
	sty.border_width_left          = 3
	sty.border_width_right         = 3
	sty.border_width_top           = 3
	sty.border_width_bottom        = 3
	sty.corner_radius_top_left     = 20
	sty.corner_radius_top_right    = 20
	sty.corner_radius_bottom_left  = 20
	sty.corner_radius_bottom_right = 20
	sty.shadow_color               = Color(0.0, 0.0, 0.0, 0.35)
	sty.shadow_size                = 16
	card.add_theme_stylebox_override("panel", sty)
	dim.add_child(card)

	_make_label(title, Vector2(0, 26), Vector2(CARD_W2, 34),
		22, PURPLE, HORIZONTAL_ALIGNMENT_CENTER, card)
	_make_label(body, Vector2(30, 76), Vector2(CARD_W2 - 60, 70), 17, PURPLE, HORIZONTAL_ALIGNMENT_CENTER, card)

	var close_btn := Button.new()
	close_btn.text     = "Close"
	close_btn.size     = Vector2(160, 48)
	close_btn.position = Vector2((CARD_W2 - 160.0) / 2.0, 180.0)
	if _font:
		close_btn.add_theme_font_override("font", _font)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color",         Color.WHITE)
	close_btn.add_theme_color_override("font_hover_color",   AMBER)
	close_btn.add_theme_color_override("font_pressed_color", AMBER)
	var bsty := StyleBoxFlat.new()
	bsty.bg_color                   = PURPLE
	bsty.corner_radius_top_left     = 14
	bsty.corner_radius_top_right    = 14
	bsty.corner_radius_bottom_left  = 14
	bsty.corner_radius_bottom_right = 14
	for s in ["normal", "hover", "pressed", "focus"]:
		close_btn.add_theme_stylebox_override(s, bsty)
	close_btn.pressed.connect(func(): dim.queue_free())   # dismiss -> already on Choose Your Plan
	card.add_child(close_btn)


# ─── Unsupported platform (e.g. Windows/macOS during dev, or iOS until ──────
# ─── StoreKit is wired in) ──────────────────────────────────────────────────
func _show_unsupported_platform_dialog() -> void:
	_show_message_dialog("Subscriptions Not Available",
		"Subscriptions are available on Android phones,\ntablets, and iPhone/iPad.")


# ─── Restore Purchases found nothing ────────────────────────────────────────
func _show_no_purchases_dialog() -> void:
	_show_message_dialog("No Purchases Found",
		"We couldn't find an active subscription\nfor this Google Play account.")


# ─── Routing once access is granted — same context pattern as premium_intro ─
func _continue_granted() -> void:
	match PremiumIntroState.context_id:
		"prep":
			if PrepLevelProgress.has_next():
				PrepLevelProgress.advance()
				get_tree().change_scene_to_file("res://prep_game.tscn")
			else:
				SaveManager.set_prep_completed()
				PrepLevelProgress.reset()
				LevelTransition.next_level_id = "level1"
				LevelTransition.level_name    = "Level 1"
				get_tree().change_scene_to_file("res://level_transition.tscn")


func _build_copyright_label() -> void:
	const BOTTOM_MARGIN : float = 50.0
	var lbl := Label.new()
	lbl.text                 = "© 2026 Acron Inc. All rights reserved."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position              = Vector2(-24.0, get_viewport_rect().size.y - BOTTOM_MARGIN)
	lbl.size                  = Vector2(get_viewport_rect().size.x, 20.0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", PURPLE)
	if _font:
		lbl.add_theme_font_override("font", _font)
	add_child(lbl)


func _make_label(text: String, pos: Vector2, sz: Vector2, fsize: int, col: Color,
		halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, parent: Node = null) -> Label:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = halign
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	if _font:
		lbl.add_theme_font_override("font", _font)
	(parent if parent else self).add_child(lbl)
	return lbl
