extends Resource
class_name StoreDirectoryData

## StoreDirectoryData
##
## The mall's full store directory: 24 store names. At game start the list
## is shuffled and dealt 6 stores per zone (4 zones x 6 stores = 24).
## Each round of a zone is one store; the store name replaces what used to
## be the challenge name in UI.

@export var store_names: Array[String] = []
