extends Node

var billing_client: BillingClient

func _enter_tree() -> void:
	if !PlatformServices.is_android():
		queue_free()


func _ready() -> void:
	billing_client = BillingClient.new()
	billing_client.connected.connect(_on_connected) # No params
	billing_client.disconnected.connect(_on_disconnected) # No params
	billing_client.connect_error.connect(_on_connect_error) # response_code: int, debug_message: String
	billing_client.query_product_details_response.connect(_on_query_product_details_response) # response: Dictionary
	billing_client.query_purchases_response.connect(_on_query_purchases_response) # response: Dictionary
	billing_client.on_purchase_updated.connect(_on_purchase_updated) # response: Dictionary
	billing_client.consume_purchase_response.connect(_on_consume_purchase_response) # response: Dictionary
	billing_client.acknowledge_purchase_response.connect(_on_acknowledge_purchase_response) # response: Dictionary

	billing_client.start_connection()

	
func _on_connected() -> void:
	print("Google Play Billing Client Connected")
	#BillingClient.query_product_details([PlatformServices.PURCHASE_STRINGS[PlatformServices.PURCHASE.AD_FREE]], BillingClient.ProductType.INAPP)
	_query_purchases()
	
	
func _on_disconnected() -> void:
	pass
	
func _on_connect_error(response_code: int, debug_message: String) -> void:
	print("Error connecting to Google Play Billing Client")
	print("Error code " + str(response_code))
	print(debug_message)
	
func _on_query_product_details_response(query_result: Dictionary) -> void:
	if query_result.response_code == BillingClient.BillingResponseCode.OK:
		print("Product details query success")
		@warning_ignore("untyped_declaration")
		# Think this is a dictionary or string, but not 100% sure, ignoring for now
		for available_product in query_result.result_array:
			print(available_product)
	else:
		print("Product details query failed")
		print("response_code: ", query_result.response_code, "debug_message: ", query_result.debug_message)
	
func _on_query_purchases_response(query_result: Dictionary) -> void:
	if query_result.response_code == BillingClient.BillingResponseCode.OK:
		print("Purchase query success")
		for purchase_result: Dictionary in query_result.result_array:
			_process_purchase(purchase_result)
	else:
		print("Purchase query failed")
		print("response_code: ", query_result.response_code, "debug_message: ", query_result.debug_message)
	
func _on_purchase_updated(result: Dictionary) -> void:
	if result.response_code == BillingClient.BillingResponseCode.OK:
		print("Purchase update received")
		for purchase_result: Dictionary in result.result_array:
			_process_purchase(purchase_result)
	else:
		print("Purchase update error")
		print("response_code: ", result.response_code, "debug_message: ", result.debug_message)
	
func _on_consume_purchase_response() -> void:
	pass
	
func _on_acknowledge_purchase_response(result: Dictionary) -> void:
	if result.response_code == BillingClient.BillingResponseCode.OK:
		print("Acknowledge purchase success")
		_handle_purchase_token(result.token, true)
	else:
		print("Acknowledge purchase failed")
		print("response_code: ", result.response_code, "debug_message: ", result.debug_message, "purchase_token: ", result.token)
	
func _query_purchases() -> void:
	billing_client.query_purchases(BillingClient.ProductType.INAPP)
	
func purchase(item: String) -> void:
	var result: Dictionary = billing_client.purchase(item)
	if result.response_code == BillingClient.BillingResponseCode.OK:
		print("Billing flow launch success")
	else:
		print("Billing flow launch failed")
		print("response_code: ", result.response_code, "debug_message: ", result.debug_message)

func _process_purchase(_incoming_purchase: Dictionary) -> void:
	pass
	# Ad free example, see documentation for other purchases
	#if PlatformServices.PURCHASE_STRINGS[PlatformServices.PURCHASE.AD_FREE] in incoming_purchase.product_ids and \
			#incoming_purchase.purchase_state == BillingClient.PurchaseState.PURCHASED:
		#if not incoming_purchase.is_acknowledged:
			#billing_client.acknowledge_purchase(incoming_purchase.purchase_token)
		#elif incoming_purchase.is_acknowledged:
			#AdManager.get_ad_free()
	
@warning_ignore("untyped_declaration")
func _handle_purchase_token(_purchase_token, purchase_successful: bool) -> void:
	if purchase_successful:
		AdManager.get_ad_free()
