---@alias Model string
---@alias Skin integer

---@alias SpawnShape "circle"|"square"|"point"

---@alias SelectionBox {[1]: Vector, [2]: Angle, [3]: Vector, [4]: Vector}

---@alias EntityType "Physics Prop" | "Entity" | "Effect"
---@alias SpawnedEntityInfo {[1]: Entity, [2]: EntityType}

---Immutable properties
---@class PanelProps

---Mutable properties
---@class PanelState
---@field showSelection boolean
---@field selectionCenter Vector
---@field searchRadius number
---@field selectionAlpha number
---@field selectionBoxes SelectionBox[]
---@field visualizeSpawn boolean
---@field visualizeSearch boolean
---@field spawnRadius number
---@field spawnShape SpawnShape
---@field modelArray string[]

---Main control panel UI
---@class PanelChildren
---@field modelList DTextEntry
---@field modelGallery DIconLayout
---@field visualizeSearch DCheckBoxLabel
---@field visualizeSpawn DCheckBoxLabel
---@field searchRadius DNumSlider
---@field clearList DButton
---@field filterDuplicates DCheckBoxLabel
---@field filterRagdolls DCheckBoxLabel
---@field filterPlayers DCheckBoxLabel
---@field filterProps DCheckBoxLabel
---@field modelCount DLabel
---@field spawnGroup DComboBox
---@field spawnRadius DNumSlider
---@field spawnShape DComboBox
