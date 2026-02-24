extends Node

signal store_opened
signal store_closed
signal day_started(day_number: int)
signal day_ended(day_number: int)

signal money_changed(new_amount: float)
signal transaction_completed(amount: float)

signal product_picked_up(product_data: Resource)
signal product_dropped(product_data: Resource)
signal product_placed(product_data: Resource, shelf: Node)
signal shelf_stock_changed(shelf: Node, product_id: String, current: int, max_stock: int, side_name: String)
signal shelf_emptied(shelf: Node)

signal checkout_started(counter: Node, customer: Node)
signal checkout_completed(counter: Node, customer: Node, total: float)
signal checkout_queue_changed(counter: Node, queue_size: int)

signal customer_entered(customer: Node)
signal customer_left(customer: Node)
signal customer_wants_product(customer: Node, product_id: String)
signal customer_satisfied(customer: Node)
signal customer_unsatisfied(customer: Node, reason: String)

signal interaction_prompt_show(text: String)
signal interaction_prompt_hide
signal player_interacted(target: Node)

signal customer_entered_aisle(customer: Node, aisle: Node)
signal customer_left_aisle(customer: Node, aisle: Node)

signal upgrade_purchased(upgrade_id: String, new_level: int)
