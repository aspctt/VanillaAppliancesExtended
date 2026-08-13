--// Reorder Containers Data
--// Reorder Containers, Workshop 2901962885 - Original design, MIT licensed
--// aspctt - 10.08.2026
--// Where a container's chosen position is stored.
--//
--// Everything lives in one table on the player, keyed by a stable identifier for the
--// container, holding a plain number. That is deliberate on both counts.
--//
--// It was first written the other way, storing a small table on the container's own
--// item so a dropped bag would carry its order to whoever picked it up. In game the
--// order kept reverting: nested tables written into an InventoryItem's mod data do not
--// reliably survive, and vanilla itself only ever writes flat scalars there. A nested
--// table on the player is fine and is what the game's own hotbar order uses, so the
--// order lives there instead.
--//
--// Storing it per player also makes multiplayer simpler and more correct. A player owns
--// their own mod data, so nothing has to be sent to the server, and one player's choice
--// of order no longer follows a shared crate around to everyone else.

QolcReorderData = {}

--// Tuning
-- Dragging renumbers in steps rather than 1, 2, 3, so a manually typed priority can sit
-- between two dragged containers without renumbering everything again.
QolcReorderData.PRIORITY_STEP = 10

-- Containers with no chosen position sort after those that have one, in the order the
-- game built them.
QolcReorderData.PRIORITY_UNSET = 100000

local ORDER_KEY = "QolcReorder"
local OPTIONS_KEY = "QolcReorderOptions"

local DEFAULT_OPTIONS = {
	LockInventory = false,
	LockLoot = false,
	SortLoot = false
}

--// Functions
-- Identifies a container across sessions. An item's id is written into the save, so a
-- bag keeps its place after being dropped and picked up again. A world container is
-- keyed by where it stands, since it is not going anywhere.
function QolcReorderData.GetKey(Player, Inventory)
	if not Player or not Inventory then return nil end

	if Inventory == Player:getInventory() then
		return "inv:" .. tostring(Inventory:getType())
	end

	local Item = Inventory:getContainingItem()
	if Item then
		return "item:" .. tostring(Item:getID())
	end

	local Object = Inventory:getParent()
	local Square = Object and Object:getSquare()
	if Square then
		return "obj:" .. tostring(Square:getX())
			.. "," .. tostring(Square:getY())
			.. "," .. tostring(Square:getZ())
			.. ":" .. tostring(Inventory:getType())
	end

	return "type:" .. tostring(Inventory:getType())
end

local function GetTable(Player)
	local ModData = Player and Player:getModData()
	if not ModData then return nil end

	local Orders = ModData[ORDER_KEY]
	if not Orders then
		Orders = {}
		ModData[ORDER_KEY] = Orders
	end

	return Orders
end

function QolcReorderData.GetPriority(Player, Inventory)
	local Orders = GetTable(Player)
	local Key = QolcReorderData.GetKey(Player, Inventory)
	if not Orders or not Key then return nil end

	local Value = tonumber(Orders[Key])
	return Value
end

-- A nil priority clears the entry, which puts the container back in the game's own order
-- rather than leaving a stale number behind.
function QolcReorderData.SetPriority(Player, Inventory, Priority)
	local Orders = GetTable(Player)
	local Key = QolcReorderData.GetKey(Player, Inventory)
	if not Orders or not Key then return end

	Orders[Key] = Priority and tonumber(Priority) or nil

	-- A player owns their own mod data, so this is the whole of what multiplayer needs
	if isClient() then Player:transmitModData() end
end

function QolcReorderData.GetOptions(Player)
	local ModData = Player and Player:getModData()
	if not ModData then return nil end

	local Options = ModData[OPTIONS_KEY]
	if not Options then
		Options = {}
		ModData[OPTIONS_KEY] = Options
	end

	-- Fills in any field missing from a character saved before an option existed
	for Name, Value in pairs(DEFAULT_OPTIONS) do
		if Options[Name] == nil then Options[Name] = Value end
	end

	return Options
end
