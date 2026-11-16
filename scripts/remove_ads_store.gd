extends Node
## The single StoreKit 2 entitlement owner; absent on desktop/web.
## The verified Apple purchase is the authority. The local profile only
## suppresses ads while offline for a previously entitled player.
signal changed
const PRODUCT_ID := "com.rsm.starrun.remove_ads"
var host: Node
var owned := false
var ready := false
var checked := false
var busy := false
var localized_price := ""
var message := "Connecting to the App Store..."
var _iap: Node
var _flow: Object

func initialize(owner: Node, locally_owned: bool) -> void:
	host = owner
	owned = locally_owned
	if OS.get_name() != "iOS":
		message = "Purchases are available on iPhone."
		changed.emit()
		return
	call_deferred("_start_store")

func _start_store() -> void:
	var path := "res://addons/godot-iap/godot_iap.gd"
	if not ResourceLoader.exists(path):
		message = "StoreKit is not available in this build."
		changed.emit()
		return
	_iap = get_node_or_null("/root/GodotIapPlugin")
	if _iap == null:
		var script: Script = load(path)
		if script == null:
			message = "StoreKit failed to initialize."
			changed.emit()
			return
		_iap = script.new()
		add_child(_iap)
	_iap.purchase_error.connect(_purchase_failed)
	_open_connection()

func _open_connection() -> void:
	if not await _iap.init_connection():
		message = "Could not connect to the App Store. Try again later."
		changed.emit()
		return
	ready = true
	# Transaction recovery is authoritative. Never infer ownership from a tap
	# or a product listing. Confirm against Apple before finishing a purchase.
	_flow = _iap.create_purchase_flow({
		"confirm_with_backend": _iap.confirm_on_device_ios({"grant": _grant_verified}),
		"is_consumable": func(_product_id: String) -> bool: return false,
	})
	_flow.purchase_processed.connect(_purchase_processed)
	_fetch_product()
	_recover_entitlement()

func _fetch_product() -> void:
	var types: Script = load("res://addons/godot-iap/types.gd")
	var request: Variant = types.ProductRequest.new()
	request.skus.assign([PRODUCT_ID])
	request.type = types.ProductQueryType.IN_APP
	var products: Array = await _iap.fetch_products(request)
	for product in products:
		if str(product.id) == PRODUCT_ID:
			localized_price = str(product.display_price)
			break
	changed.emit()

func _recover_entitlement() -> void:
	var recovered: Variant = await _flow.recover_purchases(true)
	if recovered is Array:
		checked = true
		message = "Ads removed" if owned else "One purchase removes banner ads."
	else:
		message = "Unable to verify purchases. Ads remain hidden until the store responds."
	changed.emit()

func _grant_verified(purchase: Dictionary, is_consumable: bool) -> bool:
	if is_consumable or str(purchase.get("productId", "")) != PRODUCT_ID:
		return false
	if str(purchase.get("store", "")) != "apple":
		return false
	owned = true
	# Persist before the SDK finishes its verified transaction.
	if is_instance_valid(host):
		if not bool(host.call("_on_remove_ads_entitled")):
			return false
	message = "Ads removed. Thanks for supporting Star/Run."
	changed.emit()
	return true

func _purchase_processed(purchase: Dictionary, status: Object) -> void:
	if str(purchase.get("productId", "")) != PRODUCT_ID:
		return
	busy = false
	if str(status.status) == "entitled":
		message = "Ads removed. Thanks for supporting Star/Run."
	elif str(status.status) in ["invalid", "failed"]:
		message = "Purchase was not completed. You have not been charged by Star/Run."
	changed.emit()

func _purchase_failed(error: Dictionary) -> void:
	busy = false
	var code := str(error.get("code", ""))
	message = "Purchase cancelled." if code.contains("cancel") else "Purchase unavailable. Please try again."
	changed.emit()

func buy() -> void:
	if owned:
		message = "Ads are already removed."
		changed.emit()
		return
	if not ready or busy:
		return
	busy = true
	message = "Opening Apple's secure purchase sheet..."
	changed.emit()
	var types: Script = load("res://addons/godot-iap/types.gd")
	var platforms: Variant = types.RequestPurchasePropsByPlatforms.new()
	platforms.apple = types.RequestPurchaseIosProps.new()
	platforms.apple.sku = PRODUCT_ID
	var props: Variant = types.RequestPurchaseProps.in_app(platforms)
	# Completion is sent through the verified purchase flow, not this return.
	await _iap.request_purchase(props)

func restore() -> void:
	if not ready or busy:
		return
	busy = true
	message = "Checking your Apple purchases..."
	changed.emit()
	var result: Variant = await _iap.restore_purchases()
	if result == null or not bool(result.success):
		message = "Could not restore purchases. Check your Apple Account and try again."
	else:
		var recovered: Variant = await _flow.recover_purchases(true)
		if recovered is Array:
			checked = true
			message = "Ads removed" if owned else "No prior Remove Ads purchase found."
		else:
			message = "Could not verify previous purchases. Try again."
	busy = false
	changed.emit()

func _exit_tree() -> void:
	if _flow != null and _flow.has_method("dispose"):
		_flow.dispose()
