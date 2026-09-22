extends RefCounted
class_name MallStoreIcons

## MallStoreIcons
##
## One atlas of per-store pictograms for the mall wayfinding icons.
## STORE_ICONS maps each exact store name from
## Resources/Data/Stores/store_directory.tres to a cell index; unknown names
## (test stubs, old saves) resolve to the dedicated fallback storefront cell.
## Atlas: 256x96, 8x4 grid of 32x24 cells; cells 25-31 are empty spares.

const ATLAS: Texture2D = preload("res://Resources/Art/UI/mall_store_icons.png")
const GRID := Vector2i(8, 4)
const CELL := Vector2i(32, 24)
const FALLBACK_CELL := 24

const STORE_ICONS := {
	"Deb's Department Store": 0,
	"Shears": 1,
	"Radio Hut Electronics": 2,
	"Tilt! Arcade": 3,
	"Pay-less Shoes": 4,
	"BK Toyz": 5,
	"The Intelligent Pet Store": 6,
	"Photo Hut": 7,
	"Four-Starr Sports Outlet": 8,
	"Hobby Haven": 9,
	"Walden Pond Books": 10,
	"Roasters Coffee": 11,
	"Bed Bath and Bodyworks": 12,
	"J-Mart": 13,
	"Macies Department": 14,
	"Downtown Video Rentals": 15,
	"Food Court": 16,
	"Comics-n-more": 17,
	"Reed's Music Emporium": 18,
	"Candy's Confection Store": 19,
	"The Hot Topic": 20,
	"KY Jewelry": 21,
	"Whiteside Cinema": 22,
	"Furniture Castle Liquidator": 23,
}


## get_icon(store_name) -> AtlasTexture
##
## Returns the pictogram region for a store name, or the generic storefront
## cell when the name is not in the directory.
static func get_icon(store_name: String) -> AtlasTexture:
	return _cell_texture(STORE_ICONS.get(store_name, FALLBACK_CELL))


## get_cell_region(cell_index) -> Rect2
##
## Pixel rect of one atlas cell.
static func get_cell_region(cell_index: int) -> Rect2:
	var column := cell_index % GRID.x
	var row := cell_index / GRID.x
	return Rect2(column * CELL.x, row * CELL.y, CELL.x, CELL.y)


static func _cell_texture(cell_index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = get_cell_region(cell_index)
	texture.filter_clip = true
	return texture
