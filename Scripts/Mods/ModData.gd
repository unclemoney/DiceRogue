extends Resource
class_name ModData

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var price: int = 100
## Sell refund override. -1 (default) means the seller refunds half of `price`
## (GameController._on_mod_sold). 0 or more is an exact sell price.
@export var sell_price: int = -1