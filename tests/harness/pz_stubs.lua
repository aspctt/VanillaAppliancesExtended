--// Project Zomboid API Stubs
--// aspctt - 09.08.2026
--// Fakes the slice of the game the compendium touches, so mods can run headless.

--// Harness
-- Control surface the specs drive. MoodleType is injected by TestRunner from the
-- shipped jar, so a constant that no longer exists is simply nil here too.
Harness = {}
Harness.EventHandlers = {}
Harness.ClientCommands = {}
Harness.TriggeredEvents = {}
Harness.MissingText = {}
Harness.OpenWindows = {}
Harness.Players = {}
Harness.Moodles = {}
Harness.Draws = {}
Harness.Pages = {}
Harness.Squares = {}
Harness.ScreenX = 1920
Harness.ScreenY = 1080
Harness.HasPlayer = true

function Harness.SetMoodle(Type, Level)
	if Type == nil then error("SetMoodle called with a nil MoodleType") end
	Harness.Moodles[Type] = Level
end

function Harness.SetScreenSize(Width, Height)
	Harness.ScreenX = Width
	Harness.ScreenY = Height
end

function Harness.ClearDraws()
	Harness.Draws = {}
end

function Harness.Fire(Name, A, B, C, D)
	local Handlers = Harness.EventHandlers[Name]
	if not Handlers then return 0 end
	for _, Handler in ipairs(Handlers) do
		Handler(A, B, C, D)
	end
	return #Handlers
end

function Harness.FireFrames(Count)
	for _ = 1, Count do
		Harness.Fire("OnPreUIDraw")
	end
end

function Harness.HandlerCount(Name)
	local Handlers = Harness.EventHandlers[Name]
	if not Handlers then return 0 end
	return #Handlers
end

-- Finds the most recent draw whose texture path contains Fragment
function Harness.FindDraw(Fragment)
	for Index = #Harness.Draws, 1, -1 do
		local Draw = Harness.Draws[Index]
		if Draw.Texture and Draw.Texture.Path and string.find(Draw.Texture.Path, Fragment, 1, true) then
			return Draw
		end
	end
	return nil
end

-- Returns the texture path of each draw, in the order they were issued
function Harness.DrawOrder()
	local Order = {}
	for Index, Draw in ipairs(Harness.Draws) do
		Order[Index] = Draw.Texture.Path
	end
	return Order
end

--// Events
-- Auto-creates an event object the first time a mod touches one, so new mods do not
-- need this file updated.
Events = setmetatable({}, {
	__index = function(Table, Name)
		local Event = {}
		Harness.EventHandlers[Name] = Harness.EventHandlers[Name] or {}

		function Event.Add(Handler)
			table.insert(Harness.EventHandlers[Name], Handler)
		end

		function Event.Remove(Handler)
			for Index, Existing in ipairs(Harness.EventHandlers[Name]) do
				if Existing == Handler then
					table.remove(Harness.EventHandlers[Name], Index)
					return
				end
			end
		end

		rawset(Table, Name, Event)
		return Event
	end
})

--// Rendering
UIManager = {}

function UIManager.DrawTexture(Texture, X, Y, Width, Height, Alpha)
	table.insert(Harness.Draws, {
		Texture = Texture,
		Alpha = Alpha,
		Height = Height,
		Width = Width,
		X = X,
		Y = Y
	})
end

-- Size stands in for the real texture's pixel dimensions. Kept so a spec can catch an
-- icon being drawn larger than the box it is meant to sit in.
Harness.TextureSize = 32

function getTexture(Path)
	return { Path = Path, Size = Harness.TextureSize }
end

--// Core
local CoreStub = {}

function CoreStub:getScreenWidth()
	return Harness.ScreenX
end

function CoreStub:getScreenHeight()
	return Harness.ScreenY
end

-- Bound keys. Vanilla ships Hotbar 1 to 8, and the game returns -1 for a binding that
-- does not exist, which is what makes clicking an unbound slot do nothing.
Harness.BoundKeys = {
	["Hotbar 1"] = 2, ["Hotbar 2"] = 3, ["Hotbar 3"] = 4, ["Hotbar 4"] = 5,
	["Hotbar 5"] = 6, ["Hotbar 6"] = 7, ["Hotbar 7"] = 8, ["Hotbar 8"] = 9
}

function CoreStub:getKey(Name)
	return Harness.BoundKeys[Name] or -1
end

-- A UIFont name, not a font. Vanilla hands back "Small", "Medium" and so on, which the
-- caller then looks up in the UIFont table.
-- The two highlight colours the game picks between to say yes or no. Only their channels
-- are ever read, so a spec can tell which one a feature chose.
local function NewColour(R, G, B)
	local Colour = {}
	function Colour:getR() return R end
	function Colour:getG() return G end
	function Colour:getB() return B end
	return Colour
end

function CoreStub:getGoodHighlitedColor() return NewColour(0, 1, 0) end
function CoreStub:getBadHighlitedColor() return NewColour(1, 0, 0) end

function CoreStub:getOptionTooltipFont()
	return Harness.TooltipFont
end

Harness.TooltipFont = "Small"

-- Vanilla's tooltip padding at each font, measured from the game. The real field has no
-- getter, so a mod adding a row has to match these or drift as the player changes font.
Harness.TooltipPadLeft = { Small = 8, Medium = 10, Large = 11 }

function getCore()
	return CoreStub
end

--// Clock
-- Mods that pace themselves off elapsed time read this. Specs move it by hand so a
-- test never has to wait on a real second.
Harness.NowMs = 0

function Harness.Advance(Milliseconds)
	Harness.NowMs = Harness.NowMs + Milliseconds
end

function getTimestampMs()
	return Harness.NowMs
end

--// Character Stats
-- Build 42 replaced every named accessor, getFatigue and setFatigue among them, with a
-- keyed pair taking a CharacterStat. Both CharacterStat and the real bounds behind it
-- are injected by TestRunner straight from the shipped jar, so a constant this build no
-- longer has reads nil here exactly as it would in game.
local function NewStats()
	local Values = {}
	local Stats = {}

	local function Bounds(Stat)
		return QOLC_STAT_BOUNDS and QOLC_STAT_BOUNDS[Stat] or nil
	end

	function Stats:get(Stat)
		if Stat == nil then
			error("Stats:get was given a nil CharacterStat. The constant does not exist in this build.")
		end
		if Values[Stat] ~= nil then return Values[Stat] end

		local Limits = Bounds(Stat)
		return Limits and Limits.Default or 0
	end

	-- The real Stats.set runs the value through CharacterStat.clamp before storing it,
	-- so a mod that overshoots sees what the game would keep, not what it asked for.
	function Stats:set(Stat, Value)
		if Stat == nil then
			error("Stats:set was given a nil CharacterStat. The constant does not exist in this build.")
		end

		local Limits = Bounds(Stat)
		if Limits then
			if Value < Limits.Min then Value = Limits.Min end
			if Value > Limits.Max then Value = Limits.Max end
		end

		Values[Stat] = Value
		return true
	end

	return Stats
end

Harness.NewStats = NewStats

--// Java Collections
-- ArrayList and friends are indexed from zero through get(), which is the single most
-- common way lua written against this API goes wrong.
local function NewJavaList(Items)
	local List = {}
	function List:size() return #Items end
	function List:get(Index) return Items[Index + 1] end
	function List:getItemByIndex(Index) return Items[Index + 1] end

	-- Real ArrayList.contains, which mods use to test for another mod by id
	function List:contains(Value)
		for _, Item in ipairs(Items) do
			if Item == Value then return true end
		end
		return false
	end

	return List
end

Harness.NewJavaList = NewJavaList

--// Containers
-- Declared before the player, which builds one at file scope. ContainingItem is the bag
-- an inventory belongs to, Parent is the world object holding it. A player's own
-- inventory has neither.
function Harness.NewContainer(Type, ContainingItem, Parent)
	local Container = {}
	Container.Class = "ItemContainer"
	Container.Type = Type or "bag"
	Container.Items = {}

	function Container:getType() return self.Type end
	function Container:getContainingItem() return ContainingItem end
	function Container:getParent() return Parent end

	function Container:contains(Item)
		for _, Held in ipairs(self.Items) do
			if Held == Item then return true end
		end
		return false
	end

	function Container:getItemWithIDRecursiv(Id)
		for _, Item in ipairs(self.Items) do
			if Item:getID() == Id then return Item end
		end
		return nil
	end

	-- A Java ArrayList, indexed from zero through get()
	function Container:getItems()
		local Items = self.Items
		local List = {}
		function List:size() return #Items end
		function List:get(Index) return Items[Index + 1] end
		return List
	end

	return Container
end

-- A propane tank, which is a drainable measured in uses rather than a fluid container
function Harness.NewPropaneTank(Fraction)
	local Tank = Harness.NewDrainable(5000, Fraction)
	Tank.Class = "InventoryItem"
	Tank.Id = Harness.NextItemId
	Harness.NextItemId = Harness.NextItemId + 1

	function Tank:getFullType() return "Base.PropaneTank" end
	function Tank:getName() return "Propane Tank" end
	function Tank:getID() return self.Id end

	return Tank
end

Harness.NextItemId = 1

function Harness.NewInventoryItem(Name, WorldItem)
	local Item = {}
	Item.Class = "InventoryItem"
	Item.ModData = {}
	Item.Name = Name or "Bag"
	Item.Id = Harness.NextItemId
	Harness.NextItemId = Harness.NextItemId + 1

	function Item:getModData() return self.ModData end
	function Item:getName() return self.Name end
	function Item:getID() return self.Id end
	function Item:getWorldItem() return WorldItem end

	return Item
end

function Harness.NewWorldObject(X, Y, Z)
	local Square = {}
	function Square:getX() return X or 0 end
	function Square:getY() return Y or 0 end
	function Square:getZ() return Z or 0 end

	local Object = {}
	Object.Class = "IsoWorldInventoryObject"
	function Object:getSquare() return Square end

	return Object, Square
end

-- A crate or a locker. Carries mod data and transmits it, same as any IsoObject.
function Harness.NewIsoObject()
	local Object = {}
	Object.Class = "IsoObject"
	Object.ModData = {}
	Object.Transmits = 0

	function Object:getModData() return self.ModData end
	function Object:transmitModData() self.Transmits = self.Transmits + 1 end

	return Object
end

--// Player
local function NewMoodles(Levels)
	local Moodles = {}

	function Moodles:getMoodleLevel(Type)
		if Type == nil then
			error("getMoodleLevel was given a nil MoodleType. The constant does not exist in this build.")
		end
		return Levels[Type] or 0
	end

	return Moodles
end

-- IsLocal defaults true. On a real client OnPlayerUpdate also fires for every remote
-- player in range, which is what the remote case is here to reproduce.
function Harness.NewPlayer(Number, IsLocal)
	local Player = {}
	Player.Class = "IsoPlayer"
	Player.Levels = {}
	Player.Perks = {}
	Player.Traits = {}
	Player.ReadPages = {}
	Player.Said = {}
	Player.ModData = {}
	Player.Stats = NewStats()
	Player.Moodles = NewMoodles(Player.Levels)
	Player.Number = Number or 0
	Player.IsLocal = IsLocal ~= false
	Player.Username = "Player" .. tostring(Number or 0)
	Player.Asleep = false
	Player.Transmits = 0

	function Player:getMoodles() return self.Moodles end
	function Player:getModData() return self.ModData end
	function Player:getStats() return self.Stats end
	function Player:isLocalPlayer() return self.IsLocal end
	function Player:getPlayerNum() return self.Number end
	function Player:isAsleep() return self.Asleep end
	function Player:getUsername() return self.Username end
	function Player:getInventory() return self.Inventory end
	function Player:transmitModData() self.Transmits = self.Transmits + 1 end
	function Player:getWornItems() return NewJavaList(self.WornItems) end

	-- A bag being carried rather than worn provides no hotbar slots
	function Player:isHandItem(Item) return self.HandItem == Item end

	function Player:getPrimaryHandItem() return self.PrimaryHand end
	function Player:getSecondaryHandItem() return self.SecondaryHand end

	-- Nil until a spec places them, the same as a character who is not in the world yet.
	-- Anything reading it has to cope with that.
	function Player:getSquare() return self.Square end
	function Player:setSquare(Square) self.Square = Square end

	-- An untrained skill reads zero rather than nil, same as the real getPerkLevel
	function Player:getPerkLevel(Perk)
		if Perk == nil then error("getPerkLevel was given a nil Perk") end
		return self.Perks[Perk] or 0
	end

	function Player:setPerkLevel(Perk, Level) self.Perks[Perk] = Level end

	-- Reading. Pages read are tracked per book type rather than per copy, which is what
	-- lets a character recognise a second copy of one they have already opened.
	function Player:getAlreadyReadPages(Type) return self.ReadPages[Type] or 0 end
	function Player:setAlreadyReadPages(Type, Pages) self.ReadPages[Type] = Pages end
	function Player:tooDarkToRead() return self.TooDark == true end
	function Player:Say(Text) table.insert(self.Said, Text) end

	function Player:hasTrait(Trait)
		if Trait == nil then error("hasTrait was given a nil CharacterTrait") end
		return self.Traits[Trait] == true
	end

	function Player:setTrait(Trait, Value) self.Traits[Trait] = Value end

	-- Enough of the character surface for a timed action to run
	function Player:faceThisObject() end
	function Player:setMetabolicTarget() end
	function Player:playSound(Name) return Name end
	function Player:stopOrTriggerSound() end
	function Player:isTimedActionInstant() return false end

	function Player:getDescriptor()
		local Descriptor = {}
		function Descriptor:getForename() return "Test" end
		function Descriptor:getSurname() return "Survivor" end
		return Descriptor
	end

	function Player:SetMoodle(Type, Level)
		if Type == nil then error("SetMoodle called with a nil MoodleType") end
		self.Levels[Type] = Level
	end

	Player.Inventory = Harness.NewContainer("inventory")
	Player.WornItems = {}
	Harness.Players[Player.Number] = Player

	return Player
end

-- A worn garment offering hotbar attachment points, e.g. a holster providing "Holster"
function Harness.NewWornItem(Provides)
	local Item = Harness.NewInventoryItem("Clothing")
	Item.Provides = Provides or {}

	function Item:getAttachmentsProvided() return NewJavaList(self.Provides) end
	function Item:setAttachedSlot(Index) self.AttachedSlot = Index end

	return Item
end

-- The player getPlayer() hands back. Its moodles read the shared Harness.Moodles table
-- so Harness.SetMoodle keeps driving it.
local PlayerStub = Harness.NewPlayer(0, true)
PlayerStub.Levels = Harness.Moodles
PlayerStub.Moodles = NewMoodles(Harness.Moodles)

Harness.Player = PlayerStub

function getPlayer()
	if not Harness.HasPlayer then return nil end
	return PlayerStub
end

--// Sandbox
-- Server controlled balance. Seeded from the defaults TestRunner parsed out of
-- 42/media/sandbox-options.txt, so these numbers are never restated here.
SandboxVars = { QoLC = {} }

function Harness.ResetSandbox()
	SandboxVars.QoLC = {}
	if not QOLC_SANDBOX_DEFAULTS then return end
	for Name, Value in pairs(QOLC_SANDBOX_DEFAULTS) do
		SandboxVars.QoLC[Name] = Value
	end
end

-- A save made before a feature existed has no values at all, which the mod has to cope
-- with. This is how a spec reproduces that.
function Harness.ClearSandbox()
	SandboxVars.QoLC = nil
end

Harness.ResetSandbox()

--// Translation
-- Build 42 translations are flat json. TestRunner parses every file in the mod's
-- Translate folder into one Translations table, so a key resolves here the same way it
-- would in game regardless of which file declared it.
function getText(Key, ...)
	local Value = Translations and Translations[Key]
	if Value == nil then
		Harness.MissingText[Key] = true
		return Key
	end

	-- The game runs these through String.format. Only positional %1 and %2 are worth
	-- reproducing, which is all vanilla uses in the strings this mod touches.
	local Args = { ... }
	for Index, Argument in ipairs(Args) do
		Value = string.gsub(Value, "%%" .. Index, tostring(Argument))
	end
	return Value
end

function getTextOrNull(Key)
	if Translations and Translations[Key] ~= nil then return Translations[Key] end
	return nil
end

--// File IO
-- Only reached if a mod calls PZAPI.ModOptions save or load. Reads yield no lines,
-- so options keep their declared defaults during tests.
function getFileReader()
	local Reader = {}
	function Reader:readLine() return nil end
	function Reader:close() end
	return Reader
end

function getFileWriter()
	local Writer = {}
	function Writer:write() end
	function Writer:close() end
	return Writer
end

--// Module Loading
-- Mod files declare their vanilla dependencies with require, e.g. require "ISUI/ISPanel".
-- The runner has already loaded every stub by the time any mod file runs, so this only
-- has to not be nil. Anything genuinely missing fails later on use, with a better error
-- than a require would give.
Harness.Required = {}

function require(Path)
	Harness.Required[Path] = true
	return _G[string.match(tostring(Path), "([^/]+)$")] or {}
end

--// Utility
luautils = luautils or {}

function luautils.split(Text, Separator)
	local Parts = {}
	for Part in string.gmatch(Text, "([^" .. Separator .. "]+)") do
		table.insert(Parts, Part)
	end
	return Parts
end

--// UI Elements
-- Minimal ISUIElement surface. Mods resize panels vanilla built, so width and height
-- have to round trip.
local function NewElement(Width, Height)
	local Element = {}
	Element.Width = Width
	Element.Height = Height

	function Element:setWidth(Value) self.Width = Value end
	function Element:setHeight(Value) self.Height = Value end
	function Element:getWidth() return self.Width end
	function Element:getHeight() return self.Height end
	function Element:setVisible(Value) self.Visible = Value end

	return Element
end

Harness.NewElement = NewElement

--// Character Screen
-- Mirrors what vanilla ISCharacterScreen:create leaves behind, taken from
-- media\lua\client\XpSystem\ISUI\ISCharacterScreen.lua. Only the fields the compendium
-- touches are reproduced. If vanilla changes these, the specs should be updated with it.
Harness.VanillaAvatar = {
	BorderSpacing = 10,
	Border = 2,
	Width = 128,
	Height = 256,
	TextWidth = 40
}

ISCharacterScreen = {}

function ISCharacterScreen:create()
	local Vanilla = Harness.VanillaAvatar
	self.avatarX = Vanilla.BorderSpacing + 1 + Vanilla.Border
	self.avatarY = Vanilla.BorderSpacing + 1 + Vanilla.Border
	self.avatarWidth = Vanilla.Width
	self.avatarHeight = Vanilla.Height
	self.avatarPanel = NewElement(self.avatarWidth, self.avatarHeight)
	self.xOffset = self.avatarX + self.avatarWidth + Vanilla.BorderSpacing + 2 + Vanilla.TextWidth
	Harness.CreateCallCount = (Harness.CreateCallCount or 0) + 1
end

-- Builds a screen instance and runs whatever create chain the mods have layered on
function Harness.NewCharacterScreen()
	local Screen = {}
	ISCharacterScreen.create(Screen)
	return Screen
end

--// Drainable Items
-- Models DrainableComboItem. The game stores fill as a 0 to 1 fraction and derives the
-- integer use count from it, so both views have to stay consistent here too.
function Harness.NewDrainable(MaxUses, Fraction)
	local Item = {}
	Item.MaxUses = MaxUses
	Item.Fraction = Fraction or 1
	Item.Condition = 100
	Item.SyncCount = 0

	function Item:getMaxUses() return self.MaxUses end
	function Item:getCurrentUsesFloat() return self.Fraction end
	function Item:setCurrentUsesFloat(Value) self.Fraction = Value end
	function Item:getCondition() return self.Condition end
	function Item:setCondition(Value) self.Condition = Value end
	function Item:syncItemFields() self.SyncCount = self.SyncCount + 1 end

	function Item:getCurrentUses()
		return math.floor(self.Fraction * self.MaxUses + 0.5)
	end

	function Item:setCurrentUses(Count)
		self.Fraction = Count / self.MaxUses
	end

	return Item
end

--// Crafting
-- Stands in for CraftRecipeData. The real lists are Java ArrayLists, so they are indexed
-- from zero through get(). Inputs defaults to everything the recipe is holding, consumed
-- and kept alike, which is what the real getAllInputItems returns.
local function NewItemList(Item)
	local List = {}
	function List:size() return Item ~= nil and 1 or 0 end
	function List:get(Index)
		if Index == 0 then return Item end
		return nil
	end
	return List
end

function Harness.NewCraftRecipeData(Created, Consumed, Kept, Inputs)
	local All = Inputs
	if not All then
		All = {}
		if Consumed ~= nil then table.insert(All, Consumed) end
		if Kept ~= nil then table.insert(All, Kept) end
	end

	local Data = {}
	function Data:getAllCreatedItems() return NewItemList(Created) end
	function Data:getAllConsumedItems() return NewItemList(Consumed) end
	function Data:getAllKeepInputItems() return NewItemList(Kept) end
	function Data:getAllInputItems() return NewJavaList(All) end

	-- What processDestroyAndUsedItems leaves behind. A performed recipe has already eaten
	-- its inputs by the time it returns, so anything a mod wants to measure about them has
	-- to be read first. Reproduced here so that ordering is a test rather than a comment.
	function Data:Destroy() All = {} end

	return Data
end

--// Script Manager
-- Item definitions the compendium patches at runtime. Seeded with the vanilla values
-- from media\scripts\generated\items\drainable.txt.
-- BodyLocation starts nil on the sling items on purpose. Item scripts parse before mod
-- lua runs, so a location registered from lua does not exist yet when the item is read,
-- and the game leaves it null. That is what makes the item unwearable, so the stub has
-- to reproduce it rather than pretend the script value stuck.
Harness.ScriptItems = {
	["Base.BlowTorch"] = { UseDelta = 0.1 },
	["Base.PropaneTank"] = { UseDelta = 0.0002 },
	-- Ammo boxes and magazines, seeded with the icons vanilla actually ships. Note how
	-- many share one, that duplication is the thing the compendium fixes.
	["Base.Bullets9mmBox"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets45Box"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets44Box"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets38Box"] = { Icon = "HandgunAmmoBox" },
	["Base.Bullets357Box"] = { Icon = "HandgunAmmoBox" },
	["Base.ShotgunShellsBox"] = { Icon = "ShotgunAmmoBox" },
	["Base.308Box"] = { Icon = "RifleAmmo308" },
	["Base.556Box"] = { Icon = "RifleAmmo308" },
	["Base.3030Box"] = { Icon = "RifleAmmo308" },
	["Base.9mmClip"] = { Icon = "BerettaClip" },
	["Base.45Clip"] = { Icon = "BerettaClip" },
	["Base.44Clip"] = { Icon = "BerettaClip" },
	["Base.556Clip"] = { Icon = "m16clip" },
	["Base.M14Clip"] = { Icon = "M14Clip" },

	["Base.SlingAFront"] = { BodyLocation = nil },
	["Base.SlingABack"] = { BodyLocation = nil },

	-- Food, seeded from the real values in media\scripts. Vanilla files all of these
	-- under one Food heading, and the rot time is the only thing separating what spoils
	-- from what keeps. TinnedBeans and Yeast genuinely carry no rot time at all.
	["Base.Tomato"] = { DisplayCategory = "Food", DaysTotallyRotten = 12 },
	["Base.Potato"] = { DisplayCategory = "Food", DaysTotallyRotten = 280 },
	["Base.Cabbage"] = { DisplayCategory = "Food", DaysTotallyRotten = 4 },
	["Base.Honey"] = { DisplayCategory = "Food", DaysTotallyRotten = 730 },
	["Base.TinnedBeans"] = { DisplayCategory = "Food" },
	["Base.Yeast"] = { DisplayCategory = "Food" },

	-- A mod using a large number to mean "never rots" rather than food that spoils
	["Modded.EternalRation"] = { DisplayCategory = "Food", DaysTotallyRotten = 999999999 },

	-- Not food, so it must be left exactly as vanilla filed it
	["Base.Pan"] = { DisplayCategory = "Cooking" },
	["Base.Axe"] = { DisplayCategory = "ToolWeapon" },

	-- Clothing, seeded from the three fabric types build 42 defines. RippedSheets is one
	-- of only three vanilla items carrying both a fabric and a tooltip of its own, which
	-- must not be overwritten.
	["Base.Tshirt"] = { FabricType = "Cotton" },
	["Base.Jeans"] = { FabricType = "Denim" },
	["Base.JacketLeather"] = { FabricType = "Leather" },
	["Base.RippedSheets"] = { FabricType = "Cotton", Tooltip = "Tooltip_RippedSheets" },

	-- A fabric the game might add later, with no translation of ours to show for it
	["Base.SilkShirt"] = { FabricType = "Silk" },
}

-- Skill books, the twenty four families build 42 ships, five volumes each. Generated
-- rather than listed because the shape is entirely regular and a hand written list of a
-- hundred and twenty would rot silently.
--
-- Ten families draw as Book_Generic tinted through IconColorMask, which is exactly the
-- problem the compendium's icons solve, so the stub carries that distinction rather than
-- pretending every book already has art of its own.
Harness.DoParamsFor = {}

Harness.SkillBookFamilies = {
	"Aiming", "Blacksmith", "Butchering", "Carpentry", "Carving", "Cooking",
	"Electrician", "Farming", "FirstAid", "Fishing", "FlintKnapping", "Foraging",
	"Glassmaking", "Husbandry", "LongBlade", "Maintenance", "Masonry", "Mechanic",
	"MetalWelding", "Pottery", "Reloading", "Tailoring", "Tracking", "Trapping"
}

local TINTED = {
	Blacksmith = true, Butchering = true, Carving = true, FlintKnapping = true,
	Glassmaking = true, LongBlade = true, Masonry = true, Pottery = true,
	Tailoring = true, Tracking = true
}

for _, Family in ipairs(Harness.SkillBookFamilies) do
	for Volume = 1, 5 do
		Harness.ScriptItems["Base.Book" .. Family .. tostring(Volume)] = {
			DisplayCategory = "SkillBook",
			Icon = TINTED[Family] and "Book_Generic" or "Book8",
			IconColorMask = TINTED[Family] and "Book_Generic_Mask" or nil
		}
	end
end

local function NewScriptItem(Name)
	local Definition = Harness.ScriptItems[Name]
	if not Definition then return nil end

	local Item = {}
	function Item:getUseDelta() return Definition.UseDelta end
	function Item:getBodyLocation() return Definition.BodyLocation end
	function Item:getIcon() return Definition.Icon end
	function Item:getFullName() return Name end

	function Item:getDisplayCategory() return Definition.DisplayCategory end
	function Item:getFabricType() return Definition.FabricType end
	function Item:getTooltip() return Definition.Tooltip end

	-- The real one is a private field with no getter, so a mod cannot read it back. Only
	-- the stub exposes it, which is what lets a spec prove the tint was turned off.
	function Item:QolcIconColorMask() return Definition.IconColorMask end

	-- Zero on anything that does not spoil, which is how the game distinguishes tinned
	-- food from fresh
	function Item:getDaysTotallyRotten() return Definition.DaysTotallyRotten or 0 end

	function Item:setBodyLocation(Location)
		if type(Location) ~= "table" or not Location.IsItemBodyLocation then
			error("setBodyLocation expects an ItemBodyLocation, got " .. type(Location))
		end
		Definition.BodyLocation = Location
	end

	-- Real DoParam parses a "Key = Value" string, so parse it here rather than
	-- letting a malformed string quietly pass a test
	function Item:DoParam(Param)
		local Key, Value = string.match(Param, "^%s*(%w+)%s*=%s*(.+)%s*$")
		if not Key then error("DoParam could not parse: " .. tostring(Param)) end
		local Number = tonumber(Value)
		Definition[Key] = Number or Value

		-- Counted per item as well as in total. A single total is shared by every feature
		-- that patches a script, so one spec asserting "nothing happened on a second pass"
		-- would break the moment an unrelated feature legitimately writes something.
		Harness.DoParamCalls = (Harness.DoParamCalls or 0) + 1
		Harness.DoParamsFor[Name] = (Harness.DoParamsFor[Name] or 0) + 1
	end

	return Item
end

ScriptManager = {}
ScriptManager.instance = {}

function ScriptManager.instance:getItem(Name)
	return NewScriptItem(Name)
end

-- The real getAllItems returns a Java ArrayList of every script item, indexed from zero.
-- Order is not guaranteed by the game, so nothing should depend on it.
function getAllItems()
	local All = {}
	for Name in pairs(Harness.ScriptItems) do
		table.insert(All, Name)
	end
	table.sort(All)

	local List = {}
	function List:size() return #All end
	function List:get(Index) return NewScriptItem(All[Index + 1]) end
	return List
end

--// Loot Distributions
-- Seeded with only the tables the compendium touches. Weights are irrelevant here,
-- what matters is that the table exists and carries an items list, exactly as the
-- vanilla ones do.
local function NewLootTable()
	return { rolls = 4, items = {} }
end

Harness.ProceduralNames = {
	"ArmyStorageOutfit", "ArmySurplusOutfit", "LockerArmyBedroom",
	"GunStoreAccessories", "FirearmWeapons",
	"PawnShopGunsSpecial", "PoliceStorageOutfit", "PoliceLockers",
}

Harness.VehicleNames = {
	"PoliceTruckBed", "PoliceGloveBox", "PoliceSeatFront",
	"PoliceStateSeatFront", "PoliceSheriffSeatFront",
	"PoliceSWATTruckBed", "PoliceSWATGloveBox",
}

ProceduralDistributions = { list = {} }
VehicleDistributions = {}

for _, Name in ipairs(Harness.ProceduralNames) do
	ProceduralDistributions.list[Name] = NewLootTable()
end

for _, Name in ipairs(Harness.VehicleNames) do
	VehicleDistributions[Name] = NewLootTable()
end

-- Vanilla aliases several parents onto the same underlying table. Reproduced so a
-- spec can prove the compendium does not add the same item twice through them.
VehicleDistributions.Police = {
	TruckBed = VehicleDistributions.PoliceTruckBed,
	GloveBox = VehicleDistributions.PoliceGloveBox,
	SeatFrontRight = VehicleDistributions.PoliceSeatFront,
}
VehicleDistributions.PoliceState = {
	TruckBed = VehicleDistributions.PoliceTruckBed,
	GloveBox = VehicleDistributions.PoliceGloveBox,
	SeatFrontRight = VehicleDistributions.PoliceStateSeatFront,
}
VehicleDistributions.PoliceSheriff = {
	TruckBed = VehicleDistributions.PoliceTruckBed,
	GloveBox = VehicleDistributions.PoliceGloveBox,
	SeatFrontRight = VehicleDistributions.PoliceSheriffSeatFront,
}

-- Returns the weight an item was registered at, or nil, plus how many times it
-- appears. Items lists are flat pairs of name then weight.
function Harness.LootWeight(Container, ItemName)
	if not Container or not Container.items then return nil, 0 end
	local Weight, Count = nil, 0
	for Index = 1, #Container.items - 1, 2 do
		if Container.items[Index] == ItemName then
			Weight = Container.items[Index + 1]
			Count = Count + 1
		end
	end
	return Weight, Count
end

--// Zombies
function Harness.NewZombie(OutfitName)
	local Items = {}
	local Inventory = {}

	function Inventory:AddItem(Name) table.insert(Items, Name) end
	function Inventory:contains(Name)
		for _, Existing in ipairs(Items) do
			if Existing == Name or Existing == "Base." .. Name then return true end
		end
		return false
	end
	function Inventory:getItems() return Items end

	local Zombie = {}
	function Zombie:getOutfitName() return OutfitName end
	function Zombie:getInventory() return Inventory end
	return Zombie
end

-- Deterministic by default so loot rolls can be tested exactly. Harness.NextRandom
-- is the value ZombRand will return.
Harness.NextRandom = 0

function ZombRand(Low, High)
	if High == nil then
		High = Low
		Low = 0
	end
	local Value = Low + Harness.NextRandom
	if Value >= High then return High - 1 end
	return Value
end

--// Hotbar
ISHotbar = ISHotbar or {}
ISHotbarAttachDefinition = ISHotbarAttachDefinition or {}
ISHotbarAttachDefinition.replacements = { { replacement = {} } }
ISAttachItemHotbar = ISAttachItemHotbar or {}
keyBinding = keyBinding or {}

-- Both are called with a dot and a single argument, BodyLocations.getGroup("Human"),
-- so getGroup takes the name directly rather than a self.
--
-- The two groups take DIFFERENT argument types in build 42, and getting that wrong is
-- a load time crash in game. BodyLocationGroup.getOrCreateLocation takes an
-- ItemBodyLocation object, AttachedLocationGroup.getOrCreateLocation still takes a
-- string. Both are enforced here so a mistake fails a test rather than the game.

--// Item Body Locations
-- A closed registry in build 42. Nothing registers custom entries for a mod, not the
-- item script loader nor ScriptManager, so a mod has to call register itself.
ItemBodyLocation = { Registered = {} }

-- Mirrors ResourceLocation.of: splits on a colon, defaults the namespace to "base",
-- and lowercases both halves.
function Harness.ResourceLocation(Text)
	if not Text or Text == "" then error("Identifier cannot be null or empty") end

	local Namespace, Path = string.match(Text, "^([^:]+):(.+)$")
	if not Namespace then
		Namespace, Path = "base", Text
	end
	return string.lower(Namespace), string.lower(Path)
end

-- Mirrors ItemBodyLocation.register, which passes allowDefault = false into
-- RegistryReset.createLocation and so refuses the base namespace. Vanilla registers
-- its own 114 with allowDefault = true, which is why bare names work only for it.
function ItemBodyLocation.register(Name)
	if type(Name) ~= "string" then
		error("ItemBodyLocation.register expects a string, got " .. type(Name))
	end

	local Namespace, Path = Harness.ResourceLocation(Name)
	if Namespace == "base" then
		error("Default namespace '" .. Namespace .. ":" .. Path .. "' is not allowed!")
	end

	local Location = { Name = Name, Id = Namespace .. ":" .. Path, IsItemBodyLocation = true }
	ItemBodyLocation.Registered[Location.Id] = Location
	return Location
end

BodyLocations = { Groups = {} }

function BodyLocations.getGroup(Name)
	if not BodyLocations.Groups[Name] then
		local Group = { Locations = {} }

		function Group:getOrCreateLocation(Location)
			if type(Location) ~= "table" or not Location.IsItemBodyLocation then
				error("expected argument of type ItemBodyLocation, got "
					.. (type(Location) == "string" and "String" or type(Location)))
			end
			self.Locations[Location.Id] = Location
			return Location
		end

		BodyLocations.Groups[Name] = Group
	end
	return BodyLocations.Groups[Name]
end

AttachedLocations = { Groups = {} }

function AttachedLocations.getGroup(Name)
	if not AttachedLocations.Groups[Name] then
		local Group = { Locations = {} }

		function Group:getOrCreateLocation(Id)
			if type(Id) ~= "string" then
				error("AttachedLocationGroup:getOrCreateLocation expects a string, got " .. type(Id))
			end
			if not self.Locations[Id] then
				local Location = { Id = Id }
				function Location:setAttachmentName(AttachName)
					self.AttachmentName = AttachName
					return self
				end
				self.Locations[Id] = Location
			end
			return self.Locations[Id]
		end

		AttachedLocations.Groups[Name] = Group
	end
	return AttachedLocations.Groups[Name]
end

--// Mods
-- No other mods active unless a spec says otherwise.
Harness.ActiveMods = {}

function getActivatedMods()
	local Mods = {}
	function Mods:contains(Name)
		for _, Active in ipairs(Harness.ActiveMods) do
			if Active == Name then return true end
		end
		return false
	end
	return Mods
end

--// Input
-- Any Keyboard.KEY_* resolves to a stable dummy code, for mods that add keybinds.
Keyboard = setmetatable({}, {
	__index = function(Table, Name)
		rawset(Table, Name, 0)
		return 0
	end
})

Harness.MouseX = 0
Harness.MouseY = 0

function Harness.SetMouse(X, Y)
	Harness.MouseX = X
	Harness.MouseY = Y
end

function getMouseX() return Harness.MouseX end
function getMouseY() return Harness.MouseY end

--// Object Identity
-- The real instanceof walks the Java class hierarchy, so a mod testing for IsoObject
-- matches a player. Stubs declare a class name and this walks the same chain, or a
-- mod's IsoObject branch would silently never run in tests.
local CLASS_PARENTS = {
	IsoWorldInventoryObject = "IsoObject",
	IsoGameCharacter = "IsoMovingObject",
	IsoMovingObject = "IsoObject",
	IsoPlayer = "IsoGameCharacter"
}

function instanceof(Object, ClassName)
	if type(Object) ~= "table" then return false end

	local Current = Object.Class
	while Current do
		if Current == ClassName then return true end
		Current = CLASS_PARENTS[Current]
	end
	return false
end

--// Events From Java
-- Java side code raises events with triggerEvent rather than Events.X, and build 42's
-- inventory window uses it to announce each phase of a container refresh.
function triggerEvent(Name, A, B, C, D)
	table.insert(Harness.TriggeredEvents, { Name = Name, A = A, B = B })
	return Harness.Fire(Name, A, B, C, D)
end

--// Networking
-- Every sendClientCommand is recorded rather than sent, so a spec can assert on what a
-- client would have asked the server to do without needing a server. Also how a spec
-- proves a feature sends nothing at all.
function sendClientCommand(Player, Module, Command, Request)
	table.insert(Harness.ClientCommands, {
		Player = Player,
		Module = Module,
		Command = Command,
		Request = Request
	})
end

function Harness.LastCommand(Command)
	for Index = #Harness.ClientCommands, 1, -1 do
		local Entry = Harness.ClientCommands[Index]
		if not Command or Entry.Command == Command then return Entry end
	end
	return nil
end

-- isClient is true on a multiplayer client, false in singleplayer. isServer is true only
-- on a dedicated server. Both false is singleplayer, which is the default here.
Harness.IsClient = false
Harness.IsServer = false

function isClient() return Harness.IsClient end
function isServer() return Harness.IsServer end

--// Installed Mods
-- getActivatedMods returns a java ArrayList of mod ids, indexed from zero, the ids being
-- the id= line from each mod.info. A spec adds one to stand another mod up beside this
-- one and prove the compendium gets out of its way.
-- Seeded before any mod file loads, because a guard deciding whether a feature installs
-- itself at all runs at file scope and has already made its decision by the time a spec
-- could change this. QOLC_EXTRA_MODS carries the other mods for the run, see the second
-- pass in run-tests.ps1.
Harness.ActivatedMods = { "QoLCompendium" }

if QOLC_EXTRA_MODS then
	for _, Name in ipairs(QOLC_EXTRA_MODS) do
		table.insert(Harness.ActivatedMods, Name)
	end
end

function getActivatedMods()
	return NewJavaList(Harness.ActivatedMods)
end

--// UI Elements
-- Enough of ISUIElement for a mod to lay things out and be measured. Positions are real
-- numbers that round trip, because ordering mods are judged entirely on those.
-- Positions live on the lowercase fields, because vanilla reads self.width, self.height,
-- self.x and self.y directly as often as it calls the getters. Only exposing the
-- accessors leaves those reads nil, and the failure surfaces as a comparison against nil
-- somewhere far from the cause.
local function NewUIElement(X, Y, Width, Height)
	local Element = {}
	Element.x = X or 0
	Element.y = Y or 0
	Element.width = Width or 0
	Element.height = Height or 0
	Element.Children = {}
	Element.Visible = true
	Element.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }

	function Element:setX(Value) self.x = Value end
	function Element:setY(Value) self.y = Value end
	function Element:getX() return self.x end
	function Element:getY() return self.y end
	function Element:setWidth(Value) self.width = Value end
	function Element:setHeight(Value) self.height = Value end
	function Element:getWidth() return self.width end
	function Element:getHeight() return self.height end
	function Element:getBottom() return self.y + self.height end
	function Element:getAbsoluteY() return self.y end
	function Element:getIsVisible() return self.Visible end
	function Element:setVisible(Value) self.Visible = Value end
	function Element:bringToTop() self.OnTop = true end
	function Element:setImage(Texture) self.Image = Texture end
	function Element:setTooltip(Text) self.Tooltip = Text end
	function Element:setOnClick(Handler) self.OnClick = Handler end
	function Element:setAlwaysOnTop(Value) self.AlwaysOnTop = Value end
	function Element:setCapture(Value) self.Capture = Value end
	function Element:setOnlyNumbers(Value) self.OnlyNumbers = Value end
	function Element:setText(Text) self.Text = Text end
	function Element:getText() return self.Text end
	function Element:initialise() end
	function Element:instantiate() end
	-- Vanilla's addChild sets the parent link, and mods rely on it to convert mouse
	-- coordinates. Leaving it off makes any drag silently do nothing.
	function Element:addChild(Child)
		table.insert(self.Children, Child)
		Child.parent = self
	end

	function Element:removeChild(Child)
		for Index, Existing in ipairs(self.Children) do
			if Existing == Child then
				table.remove(self.Children, Index)
				return
			end
		end
	end

	function Element:addToUIManager() Harness.OpenWindows[self] = true end
	function Element:removeFromUIManager() Harness.OpenWindows[self] = nil end

	-- Click a button the way a player would
	function Element:Click()
		if self.OnClick then self.OnClick(self) end
	end

	return Element
end

Harness.NewUIElement = NewUIElement

function Harness.OpenWindowCount()
	local Count = 0
	for _ in pairs(Harness.OpenWindows) do Count = Count + 1 end
	return Count
end

local function NewWidgetClass()
	local Class = {}
	Class.__index = Class

	function Class:new(X, Y, Width, Height, Text, Target, OnClick)
		local Element = NewUIElement(X, Y, Width, Height)
		Element.Text = Text
		Element.Target = Target
		if OnClick then
			Element.OnClick = function() OnClick(Target) end
		end
		return Element
	end

	function Class:derive(Name)
		local Derived = {}
		Derived.__index = Derived
		Derived.Name = Name
		Derived.new = self.new
		Derived.derive = self.derive
		return Derived
	end

	return Class
end

ISPanel = NewWidgetClass()
ISButton = NewWidgetClass()
ISLabel = NewWidgetClass()
ISTextEntryBox = NewWidgetClass()

-- ISLabel measures its own text, which mods use to centre it
function ISLabel:new(X, Y, Height, Text)
	local Element = NewUIElement(X, Y, string.len(tostring(Text or "")) * 6, Height)
	Element.Text = Text
	return Element
end

function ISTextEntryBox:new(Text, X, Y, Width, Height)
	local Element = NewUIElement(X, Y, Width, Height)
	Element.Text = Text
	return Element
end

ISTickBox = NewWidgetClass()

function ISTickBox:new(X, Y, Width, Height)
	local Element = NewUIElement(X, Y, Width, Height)
	Element.selected = {}
	Element.Options = {}

	function Element:addOption(Text)
		table.insert(self.Options, Text)
		return #self.Options
	end

	function Element:setSelected(Index, Value) self.selected[Index] = Value end
	function Element:isSelected(Index) return self.selected[Index] end

	return Element
end

UIFont = setmetatable({}, {
	__index = function(Table, Name)
		rawset(Table, Name, Name)
		return Name
	end
})

--// Inventory Page
-- Models the parts of ISInventoryPage that container ordering depends on, taken from
-- media\lua\client\ISUI\ISInventoryPage.lua. The important detail reproduced here is
-- that vanilla reads the backpacks ARRAY, not the screen: scroll height comes from the
-- last entry, and selection walks it in order. A mod that only moves buttons visually
-- leaves both wrong, and these stubs are what make that visible in a test.
ISInventoryPage = {}
ISInventoryPage.__index = ISInventoryPage

function ISInventoryPage:titleBarHeight() return 16 end

function ISInventoryPage:createChildren() end

-- Vanilla recycles container buttons through a pool rather than building new ones each
-- refresh, so the object showing one container this frame may have been showing another
-- last frame. Reproduced because it is exactly where an icon and an inventory can drift
-- apart, and creating fresh buttons every time hides that entirely.
function ISInventoryPage:addContainerButton(Container, Texture, Name, Tooltip)
	local Index = #self.backpacks + 1
	local Button

	if #self.buttonPool > 0 then
		Button = table.remove(self.buttonPool, 1)
		Button:setX(0)
		Button:setY(((Index - 1) * self.buttonSize) - 1)
	else
		Button = NewUIElement(0, ((Index - 1) * self.buttonSize) - 1, self.buttonSize, self.buttonSize)
		Button.OriginalCalls = {}
		function Button:onMouseDown() table.insert(self.OriginalCalls, "down") end
		function Button:onMouseMove() table.insert(self.OriginalCalls, "move") end
		function Button:onMouseMoveOutside() table.insert(self.OriginalCalls, "moveOutside") end
		function Button:onMouseUpOutside() table.insert(self.OriginalCalls, "upOutside") end

		-- Vanilla's onBackpackMouseUp selects the container. Reproduced because that is
		-- what makes releasing a drag over another button open it, and a stub that
		-- merely records the call cannot show that.
		function Button:onMouseUp()
			table.insert(self.OriginalCalls, "up")
			local Page = self.parent and self.parent.parent
			if Page and Page.onBackpackClick then Page:onBackpackClick(self) end
		end
	end

	Button.Class = "ISButton"
	Button.inventory = Container
	Button.tooltip = Tooltip
	Button.name = Name

	-- The icon vanilla picks is derived from the container, so it always matches the
	-- inventory the button carries. A spec can compare the two to catch a desync.
	Button.Image = "icon:" .. Container:getType()

	self.containerButtonPanel:addChild(Button)
	self.backpacks[Index] = Button
	return Button
end

-- Selecting a container goes through the button, never through its position, which is
-- what makes reordering the array safe in the first place.
function ISInventoryPage:selectContainer(Button)
	self.inventory = Button.inventory
	self.SelectedInventory = Button.inventory
end

function ISInventoryPage:onBackpackClick(Button)
	self:selectContainer(Button)
end

function ISInventoryPage:refreshBackpacks()
	self.buttonPool = self.buttonPool or {}
	for Index, Button in ipairs(self.backpacks) do
		self.containerButtonPanel:removeChild(Button)
		table.insert(self.buttonPool, Index, Button)
	end

	self.backpacks = {}
	self.RefreshCount = (self.RefreshCount or 0) + 1

	triggerEvent("OnRefreshInventoryWindowContainers", self, "begin")

	for _, Container in ipairs(self.Containers) do
		self:addContainerButton(Container, nil, Container:getType(), nil)
	end

	triggerEvent("OnRefreshInventoryWindowContainers", self, "beforeFloor")
	triggerEvent("OnRefreshInventoryWindowContainers", self, "buttonsAdded")

	-- Everything below reads the array, which is the whole point
	for _, Button in ipairs(self.backpacks) do
		if Button.inventory == self.inventory then self.selectedButton = Button end
	end

	local Last = self.backpacks[#self.backpacks]
	self.containerButtonPanel.ScrollHeight = Last and Last:getBottom() or 0

	triggerEvent("OnRefreshInventoryWindowContainers", self, "end")
end

-- OnCharacter false builds a loot window instead of the player's own inventory
function Harness.NewInventoryPage(PlayerNum, OnCharacter)
	local Page = NewUIElement(0, 0, 400, 500)
	setmetatable(Page, ISInventoryPage)

	Page.player = PlayerNum or 0
	Page.onCharacter = OnCharacter ~= false
	Page.buttonSize = 32
	Page.backpacks = {}
	Page.Containers = {}
	Page.containerButtonPanel = NewUIElement(0, 0, 32, 400)

	-- The panel is a child of the page in vanilla, and onBackpackMouseUp reaches the
	-- page through self.parent.parent, so the link has to exist here too.
	Page:addChild(Page.containerButtonPanel)

	return Page
end

-- Mirrors the part of build 42's ISInventoryPage:prerender that draws the weight and the
-- title, which is all the compendium touches. Both go through drawTextRight, the weight
-- anchored to the pin button and the title to a gap measured from a placeholder rather
-- than from the label actually drawn. That placeholder is the bug.
local WEIGHT_PLACEHOLDER = "9999.99 / 9999"

function ISInventoryPage:prerender()
	self.VanillaPrerenders = (self.VanillaPrerenders or 0) + 1

	local Weight = self.weightLabel or "12.34 / 50"
	self:drawTextRight(Weight, self.pinButton:getX() - 1, 0, 1, 1, 1, 1)

	if self.title and not self.onCharacter then
		local Reserved = getTextManager():MeasureStringX(UIFont.Small, WEIGHT_PLACEHOLDER) + 30

		-- Vanilla appends the campfire's remaining fuel, or a note that a vehicle seat is
		-- occupied, to the title before drawing it. A spec sets titleSuffix to get that.
		local Text = self.title .. (self.titleSuffix or "")
		self:drawTextRight(Text, self.width - 20 - Reserved, 4, 1, 1, 1, 1)
	end
end

-- A loot window with a title and a weight, laid out the way vanilla lays one out
function Harness.NewLootWindow(Title, WeightLabel, Width)
	local Page = Harness.NewInventoryPage(0, false)
	Page.width = Width or 400
	Page.title = Title or "Crate"
	Page.weightLabel = WeightLabel
	Page.Drawn = {}

	Page.pinButton = NewUIElement(Page.width - 40, 0, 16, 16)

	function Page:drawTextRight(Text, X, Y)
		table.insert(self.Drawn, {
			Text = Text, X = X, Y = Y,
			Left = X - getTextManager():MeasureStringX(UIFont.Small, Text)
		})
	end

	function Page:Find(Text)
		for _, Draw in ipairs(self.Drawn) do
			if Draw.Text == Text then return Draw end
		end
		return nil
	end

	return Page
end

-- Reads the button order off the screen rather than out of the array, so a spec can
-- prove the two agree
function Harness.ButtonOrderByPosition(Page)
	local Sorted = {}
	for Index, Button in ipairs(Page.backpacks) do
		Sorted[Index] = Button
	end
	table.sort(Sorted, function(A, B) return A:getY() < B:getY() end)

	local Names = {}
	for Index, Button in ipairs(Sorted) do
		Names[Index] = Button.inventory:getType()
	end
	return Names
end

function Harness.ButtonOrderByArray(Page)
	local Names = {}
	for Index, Button in ipairs(Page.backpacks) do
		Names[Index] = Button.inventory:getType()
	end
	return Names
end

--// Text And Sound
function getTextManager()
	local Manager = {}
	function Manager:getFontHeight() return 12 end
	function Manager:MeasureStringX(_Font, Text) return string.len(tostring(Text or "")) * 6 end
	return Manager
end

Harness.UISounds = {}

function getSoundManager()
	local Manager = {}
	function Manager:playUISound(Name) table.insert(Harness.UISounds, Name) end
	return Manager
end

--// Hotbar
-- Models the parts of ISHotbar that slot ordering depends on, from
-- media\lua\client\Hotbar\ISHotbar.lua. Two behaviours matter and are reproduced
-- exactly: refresh rebuilds availableSlot in its own canonical order with Back forced
-- to the front, which is what any ordering mod has to undo afterwards, and
-- getSlotIndexAt clamps a click past the last slot onto the last slot rather than
-- reporting a miss.
ISHotbar = {}
ISHotbar.__index = ISHotbar

Harness.HotkeyPresses = {}

function ISHotbar:getSlotDef(Name)
	if not Name then return nil end
	return { type = Name, name = Name, attachments = {} }
end

function ISHotbar:compareWornItems()
	return self.WornChanged and true or false
end

function ISHotbar:getKeyForIndex(Index)
	return getCore():getKey("Hotbar " .. tostring(Index))
end

ISHotbar.onKeyStartPressed = function(Key)
	table.insert(Harness.HotkeyPresses, { Key = Key, Phase = "start" })
end

ISHotbar.onKeyPressed = function(Key)
	table.insert(Harness.HotkeyPresses, { Key = Key, Phase = "press" })
end

function ISHotbar:getSlotIndexAt(X, Y)
	if X >= 0 and X < self.width and Y >= 0 and Y < self.height then
		local Index = math.floor((X - self.margins) / (self.slotWidth + self.slotPad)) + 1
		Index = math.max(Index, 1)
		return math.min(Index, #self.availableSlot)
	end
	return -1
end

function ISHotbar:savePosition()
	local ModData = self.chr:getModData()
	ModData.hotbar = {}

	for Index, Slot in ipairs(self.availableSlot) do
		ModData.hotbar[Index] = Slot.slotType
	end

	self.SaveCount = (self.SaveCount or 0) + 1
	if isClient() then self.chr:transmitModData() end
end

function ISHotbar:loadPosition()
	local ModData = self.chr:getModData()
	if not ModData.hotbar then return end

	self.availableSlot = {}
	for Index, SlotType in ipairs(ModData.hotbar) do
		self.availableSlot[Index] = { slotType = SlotType, name = SlotType, def = self:getSlotDef(SlotType) }
	end
end

-- Rebuilds in the game's own order: Back first, then whatever the worn clothing
-- provides, in the order it provides it. Items follow their slot type across the
-- rebuild, exactly as vanilla reattaches them.
function ISHotbar:refresh()
	self.needsRefresh = false

	-- Vanilla returns here unless worn items actually changed, because
	-- OnClothingUpdated also fires for blood, holes and wetness. Everything below,
	-- including savePosition and its transmitModData, is skipped on those.
	local Changed = false
	if not self.wornItems then
		self.wornItems = {}
		Changed = true
	elseif self:compareWornItems() then
		Changed = true
	end

	if not Changed then return end

	local Carried = {}
	for Index, Slot in ipairs(self.availableSlot) do
		Carried[Slot.slotType] = self.attachedItems[Index]
	end

	self.availableSlot = {}
	self.attachedItems = {}

	for Index, SlotType in ipairs(self.SlotTypes) do
		self.availableSlot[Index] = { slotType = SlotType, name = SlotType, def = self:getSlotDef(SlotType) }
		if Carried[SlotType] then
			self.attachedItems[Index] = Carried[SlotType]
			Carried[SlotType]:setAttachedSlot(Index)
		end
	end

	self.RefreshCount = (self.RefreshCount or 0) + 1
	self:savePosition()
end

function ISHotbar:onMouseUp(X, Y)
	self.VanillaMouseUps = (self.VanillaMouseUps or 0) + 1
end

function ISHotbar:doMenu(SlotIndex)
	self.LastMenuIndex = SlotIndex
end

function ISHotbar:onRightMouseUp(X, Y)
	self:doMenu(self:getSlotIndexAt(X, Y))
end

function ISHotbar:setSizeAndPosition()
	self:setWidth(self.margins * 2 + (self.slotWidth + self.slotPad) * #self.availableSlot)
end

function ISHotbar:render()
	self.RenderCount = (self.RenderCount or 0) + 1
end

-- SlotTypes is what the character's clothing currently provides, Back included. It is
-- the order the game would rebuild in, which an ordering mod then has to correct.
function Harness.NewHotbar(Player, SlotTypes)
	local Hotbar = Harness.NewUIElement(0, 0, 400, 76)
	setmetatable(Hotbar, ISHotbar)

	Hotbar.SlotTypes = SlotTypes or { "Back" }
	Hotbar.character = Player
	Hotbar.chr = Player
	Hotbar.availableSlot = {}
	Hotbar.attachedItems = {}
	Hotbar.slotWidth = 60
	Hotbar.slotHeight = 60
	Hotbar.slotPad = 4
	Hotbar.margins = 4
	Hotbar.borderColor = { r = 0.8, g = 0.8, b = 0.8, a = 0.8 }
	Hotbar.textColor = { r = 1, g = 1, b = 1, a = 1 }
	Hotbar.font = UIFont.Small
	Hotbar.MouseX = 0
	Hotbar.MouseY = 0
	Hotbar.Drawn = {}

	function Hotbar:getMouseX() return self.MouseX end
	function Hotbar:getMouseY() return self.MouseY end
	function Hotbar:drawRect(...) table.insert(self.Drawn, { Kind = "rect", ... }) end
	function Hotbar:drawRectBorderStatic(...) table.insert(self.Drawn, { Kind = "border", ... }) end
	function Hotbar:drawText(...) table.insert(self.Drawn, { Kind = "text", ... }) end

	-- Width and height are recorded so a spec can prove an icon stays inside its cell.
	-- drawTexture paints at the texture's own size, which is how a 32 pixel glyph ends
	-- up spilling across the slots beside an 18 pixel button.
	function Hotbar:drawTexture(Texture, X, Y)
		local Size = Texture and Texture.Size or 0
		table.insert(self.Drawn, { Kind = "texture", Texture = Texture, X = X, Y = Y, W = Size, H = Size })
	end

	function Hotbar:drawTextureScaled(Texture, X, Y, W, H)
		table.insert(self.Drawn, { Kind = "texture", Texture = Texture, X = X, Y = Y, W = W, H = H })
	end

	Harness.SetHotbarSlots(Hotbar, Hotbar.SlotTypes)

	-- Two refreshes, because the first is the one the mod deliberately sits out while
	-- the game is still building the bar
	Hotbar:refresh()
	Hotbar:refresh()
	Hotbar:setSizeAndPosition()

	return Hotbar
end

-- Sets what the bar can show and dresses the character to match, since the game derives
-- one from the other. Back is always available and comes from no garment.
function Harness.SetHotbarSlots(Hotbar, SlotTypes)
	Hotbar.SlotTypes = SlotTypes

	local Provided = {}
	for _, SlotType in ipairs(SlotTypes) do
		if SlotType ~= "Back" then table.insert(Provided, SlotType) end
	end

	Hotbar.character.WornItems = { Harness.NewWornItem(Provided) }
end

function Harness.SlotOrder(Hotbar)
	local Names = {}
	for Index, Slot in ipairs(Hotbar.availableSlot) do
		Names[Index] = Slot.slotType
	end
	return Names
end

--// Item Tooltip
-- ObjectTooltip is built on the Java side, so a mod can only reserve room while it
-- measures and draw into that room afterwards. Both halves are reproduced: setHeight is
-- called once with the measured content height, and DrawText records what was written.
local function NewObjectTooltip()
	local Tooltip = {}
	Tooltip.Texts = {}

	-- Where vanilla draws the item name and every stat row, measured from the game per
	-- tooltip font because the real padLeft has no getter and cannot be read from lua.
	-- Anything a mod adds has to land on the same column at every font size.
	Tooltip.padLeft = Harness.TooltipPadLeft[Harness.TooltipFont] or 8

	function Tooltip:DrawText(Font, Text, X, Y, R, G, B, A)
		table.insert(self.Texts, { Font = Font, Text = Text, X = X, Y = Y, R = R, G = G, B = B, A = A })
	end

	return Tooltip
end

ISToolTipInv = {}
ISToolTipInv.__index = ISToolTipInv

-- Mirrors the shape of vanilla's render: measure the item, set the height once, then
-- draw. The measured height is what a mod has to grow to fit a row of its own in.
ISToolTipInv.MeasuredHeight = 120

function ISToolTipInv:render()
	self.VanillaRenders = (self.VanillaRenders or 0) + 1

	-- Vanilla writes the item name and its stat rows at padLeft. Recorded so a spec can
	-- require anything a mod adds to share that column rather than trusting a number.
	self.tooltip:DrawText(UIFont.Small, "Encumbrance:", self.tooltip.padLeft, 20, 1, 1, 1, 1)
	self.VanillaRowX = self.tooltip.padLeft

	self:setHeight(ISToolTipInv.MeasuredHeight)
end

function Harness.NewItemTooltip(Item)
	local Panel = Harness.NewUIElement(0, 0, 200, 0)
	setmetatable(Panel, ISToolTipInv)

	Panel.item = Item
	Panel.tooltip = NewObjectTooltip()

	return Panel
end

--// Clothing
-- Covered parts, holes and patches are what RecipeCodeOnCreate.ripClothing turns into a
-- strip count, max(covered - (holes + patches), 1). The defaults describe a pristine
-- jacket, so a spec only states the ones it is actually about.
function Harness.NewGarment(Fabric, Type, Covered, Holes, Patches)
	local Item = Harness.NewInventoryItem("Jacket")
	Item.Type = Type or "Base.Jacket_Test"
	Item.Covered = Covered or 7
	Item.Holes = Holes or 0
	Item.Patches = Patches or 0

	function Item:getFabricType() return Fabric end
	function Item:getFullType() return self.Type end
	function Item:getNbrOfCoveredParts() return self.Covered end
	function Item:getHolesNumber() return self.Holes end
	function Item:getPatchesNumber() return self.Patches end

	return Item
end

--// Weapons
-- Condition runs 0 to conditionMax, and the max differs per item, which is why anything
-- reading it has to work in fractions rather than raw numbers.
function Harness.NewWeapon(Condition, ConditionMax)
	local Weapon = Harness.NewInventoryItem("Axe")
	Weapon.Condition = Condition or 10
	Weapon.ConditionMax = ConditionMax or 10

	function Weapon:getCondition() return self.Condition end
	function Weapon:setCondition(Value) self.Condition = Value end
	function Weapon:getConditionMax() return self.ConditionMax end
	function Weapon:IsWeapon() return true end
	function Weapon:getTex() return getTexture("media/ui/Axe.png") end

	return Weapon
end

-- Food, books and the like report a max of zero, so they have no condition to show
function Harness.NewPlainItem()
	local Item = Harness.NewInventoryItem("Apple")
	function Item:getCondition() return 0 end
	function Item:getConditionMax() return 0 end
	function Item:IsWeapon() return false end
	return Item
end

--// Equipped Item Panel
-- Mirrors ISEquippedItem, which draws the item in each hand into two boxes and reads
-- getCondition only to decide what may be dragged in. Nothing is drawn for condition.
ISEquippedItem = {}
ISEquippedItem.__index = ISEquippedItem

function ISEquippedItem:render()
	self.VanillaRenders = (self.VanillaRenders or 0) + 1

	-- Vanilla draws the item icon here. Recording how much had already been drawn lets a
	-- spec prove a mod painted behind the icon rather than across it.
	self.DrawnBeforeVanilla = #self.Drawn
end

function Harness.NewEquippedItemPanel(Player)
	local Panel = Harness.NewUIElement(0, 0, 100, 100)
	setmetatable(Panel, ISEquippedItem)

	Panel.chr = Player

	-- Vanilla's own proportions. The main hand box is square and the off hand box is
	-- three quarters as tall as it is wide, TEXTURE_HEIGHT = TEXTURE_WIDTH * 0.75, which
	-- is what turns a box filling fill into an ellipse on the second slot.
	Panel.mainHand = { x = 0, y = 0, width = 48, height = 48 }
	Panel.offHand = { x = 0, y = 60, width = 48, height = 36 }
	Panel.Drawn = {}

	function Panel:drawRect(X, Y, W, H, A, R, G, B)
		table.insert(self.Drawn, { Kind = "rect", X = X, Y = Y, W = W, H = H, A = A, R = R, G = G, B = B })
	end

	-- The round slots are drawn as a disc clipped to the filled band, so a spec has to
	-- see both the texture and the clip that shaped it.
	function Panel:drawTextureScaled(Texture, X, Y, W, H, A, R, G, B)
		table.insert(self.Drawn, {
			Kind = "texture", Texture = Texture,
			X = X, Y = Y, W = W, H = H, A = A, R = R, G = G, B = B,
			Stencil = self.Stencil
		})
	end

	function Panel:setStencilRect(X, Y, W, H)
		self.Stencil = { X = X, Y = Y, W = W, H = H }
	end

	function Panel:clearStencilRect()
		self.Stencil = nil
	end

	return Panel
end

--// World Objects
-- A fuel pump. Vanilla recognises one by getPipedFuelAmount() > 0, which covers both
-- having power and having fuel left, so that is the whole of what a pump needs here.
function Harness.NewFuelPump(Fuel)
	local Pump = {}
	Pump.Class = "IsoObject"
	Pump.Fuel = Fuel or 22000

	function Pump:getPipedFuelAmount() return self.Fuel end
	function Pump:setPipedFuelAmount(Value) self.Fuel = Value end
	function Pump:getSquare() return nil end

	return Pump
end

-- Anything else on the square, so a spec can prove a right click that lands on a wall
-- or a sign still finds the pump beside it.
function Harness.NewSceneryWith(Neighbours)
	local Objects = Neighbours or {}

	local Square = {}
	function Square:getObjects()
		local List = {}
		function List:size() return #Objects end
		function List:get(Index) return Objects[Index + 1] end
		return List
	end

	local Object = {}
	Object.Class = "IsoObject"
	function Object:getSquare() return Square end

	return Object
end

--// Timed Actions
-- Queued actions are recorded rather than run. A spec performs them by hand so it can
-- check the state before and after.
Harness.ActionQueue = {}

ISTimedActionQueue = {}

function ISTimedActionQueue.add(Action)
	table.insert(Harness.ActionQueue, Action)
	return Action
end

ISBaseTimedAction = {}
ISBaseTimedAction.__index = ISBaseTimedAction

function ISBaseTimedAction:derive(Name)
	local Class = {}
	Class.__index = Class
	Class.Name = Name
	Class.derive = ISBaseTimedAction.derive
	setmetatable(Class, { __index = ISBaseTimedAction })
	return Class
end

function ISBaseTimedAction.new(Class, Character)
	local Action = setmetatable({}, Class)
	Action.character = Character
	return Action
end

function ISBaseTimedAction:perform() self.Performed = true end
function ISBaseTimedAction:stop() self.Stopped = true end
function ISBaseTimedAction:setActionAnim() end

--// Skills
-- Perks are java singletons: compared by identity, never by name, and carrying their own
-- id. getType returns the perk itself, which is what lets vanilla call it on a perk it
-- already holds. Built on demand so a spec never has to declare one.
Perks = setmetatable({}, {
	__index = function(Table, Key)
		local Perk = {}

		function Perk:getId() return Key end
		function Perk:getName() return Key end
		function Perk:getType() return Perk end

		rawset(Table, Key, Perk)
		return Perk
	end
})

Harness.Xp = {}

function Harness.ClearXp()
	Harness.Xp = {}
end

-- Mirrors LuaManager.GlobalObject.addXp, which is the reason a mod may award experience
-- from shared code without checking where it is running. On a server it sends a packet,
-- in singleplayer it applies the experience directly, and on a multiplayer client it
-- deliberately does nothing at all, because the server owns the character's skills.
function addXp(Character, Perk, Amount)
	if isClient() then return end
	if Perk == nil then error("addXp was given a nil Perk") end

	Harness.Xp[Perk] = (Harness.Xp[Perk] or 0) + Amount
end

--// Generators
-- Fuel runs zero to ten and getFuelPercentage is fuel times ten, which is the scale the
-- game itself uses. totalPowerUsing is what the generator burns in an in game hour before
-- the GeneratorFuelConsumption sandbox multiplier is applied.
function Harness.NewGenerator(Fuel, PowerUsing, Activated, X, Y, Z)
	local Generator = {}
	Generator.Class = "IsoGenerator"
	Generator.Fuel = Fuel or 10
	Generator.PowerUsing = PowerUsing or 0.1
	Generator.Activated = Activated ~= false

	function Generator:getFuel() return self.Fuel end
	function Generator:getFuelPercentage() return self.Fuel * 10 end
	function Generator:getTotalPowerUsing() return self.PowerUsing end
	function Generator:isActivated() return self.Activated end
	function Generator:getSquare() return self.Square end

	-- The generator's own draw, and the one place the sandbox multiplier is already
	-- folded in: the real one returns 0.02 times GeneratorFuelConsumption.
	function Generator:getBasePowerConsumption()
		local Rate = SandboxVars and tonumber(SandboxVars.GeneratorFuelConsumption)
		return 0.02 * (Rate or 1)
	end

	Generator.Square = Harness.NewGridSquare(X or 100, Y or 100, Z or 0)
	return Generator
end

-- A square that reports where it is and whether it can carry power
function Harness.NewGridSquare(X, Y, Z, Outside, Solid)
	local Square = {}
	Square.Outside = Outside == true
	Square.Solid = Solid ~= false

	function Square:getX() return X end
	function Square:getY() return Y end
	function Square:getZ() return Z end
	function Square:isOutside() return self.Outside end
	function Square:isSolidFloor() return self.Solid end
	function Square:getFloor() return self.Solid and {} or nil end

	return Square
end

IsoUtils = IsoUtils or {}

function IsoUtils.DistanceToSquared(X1, Y1, X2, Y2)
	local DX = X1 - X2
	local DY = Y1 - Y2
	return (DX * DX) + (DY * DY)
end

-- Every highlight drawn this frame, so a spec can count the area covered and read back
-- the colour the generator's state chose.
Harness.Highlights = {}

function Harness.ClearHighlights()
	Harness.Highlights = {}
end

function addAreaHighlight(X, Y, X2, Y2, Z, R, G, B, A)
	table.insert(Harness.Highlights, { X = X, Y = Y, Z = Z, R = R, G = G, B = B, A = A })
end

-- Mirrors the parts of build 42's ISGeneratorInfoWindow the compendium touches. getRichText
-- is a plain function rather than a method, which is how vanilla declares it.
ISGeneratorInfoWindow = {}
ISGeneratorInfoWindow.__index = ISGeneratorInfoWindow

function ISGeneratorInfoWindow.getRichText(Object, DisplayStats)
	if not DisplayStats then return " <INDENT:10> " end
	return "Fuel: " .. tostring(math.ceil(Object:getFuelPercentage())) .. "% <LINE> Condition: 100"
end

function ISGeneratorInfoWindow:prerender() self.VanillaPrerenders = (self.VanillaPrerenders or 0) + 1 end
function ISGeneratorInfoWindow:setVisible(Visible) self.Visible = Visible end
function ISGeneratorInfoWindow:removeFromUIManager() self.Removed = true end

function Harness.NewGeneratorWindow(Generator)
	local Window = setmetatable({}, ISGeneratorInfoWindow)
	Window.object = Generator
	return Window
end

--// Experience
-- getPerkBoost is the profession and trait boost level, 0 to 3, and is what the skills
-- tooltip and the character creation screen both report.
function Harness.NewXp(Boosts)
	local Xp = {}
	function Xp:getPerkBoost(Perk) return Boosts[Perk] or 0 end
	function Xp:getMultiplier() return 0 end
	return Xp
end

-- Mirrors the tail of build 42's ISSkillProgressBar:updateTooltip, which is the part the
-- compendium rewrites. Vanilla appends the boost line for levels one to three and nothing
-- at all otherwise, and does not exclude Fitness or Strength here even though the game
-- gives them nothing for the second and third.
ISSkillProgressBar = {}
ISSkillProgressBar.__index = ISSkillProgressBar

function ISSkillProgressBar:updateTooltip()
	self.VanillaUpdates = (self.VanillaUpdates or 0) + 1
	self.message = self.perk:getName() .. " level 1"

	local Boost = self.char:getXp():getPerkBoost(self.perk:getType())
	local Percent = nil
	if Boost == 1 then Percent = "75%"
	elseif Boost == 2 then Percent = "100%"
	elseif Boost == 3 then Percent = "125%" end

	if Percent then
		self.message = self.message .. " <LINE> " .. getText("IGUI_XP_tooltipxpboost", Percent)
	end
end

function Harness.NewSkillBar(Perk, Boost, Player)
	Player = Player or Harness.NewPlayer(0, true)
	Player.Xp = Harness.NewXp({ [Perk] = Boost or 0 })
	function Player:getXp() return self.Xp end

	local Bar = setmetatable({}, ISSkillProgressBar)
	Bar.char = Player
	Bar.perk = Perk

	return Bar
end

-- Mirrors CharacterCreationProfession:drawXpBoostMap, which draws the same number through
-- one right aligned call. Vanilla already leaves Fitness and Strength out here.
CharacterCreationProfession = {}
CharacterCreationProfession.__index = CharacterCreationProfession

function CharacterCreationProfession:drawXpBoostMap(Y, Item)
	self.VanillaDraws = (self.VanillaDraws or 0) + 1

	local Level = Item.item.level
	local Percent = "+ 75%"
	if Level == 2 then Percent = "+ 100%"
	elseif Level >= 3 then Percent = "+ 125%" end

	if Item.item.perk ~= Perks.Fitness and Item.item.perk ~= Perks.Strength then
		self:drawTextRight(Percent, 0, Y)
	end

	return Y + 20
end

function Harness.NewCreationScreen()
	local Screen = setmetatable({}, CharacterCreationProfession)
	Screen.Drawn = {}

	function Screen:drawTextRight(Text) table.insert(self.Drawn, Text) end

	return Screen
end

--// Handcraft Action
-- Mirrors media\lua\shared\Entity\TimedActions\ISHandcraftAction.lua. Only the two
-- methods the compendium wraps are reproduced.
--
-- performRecipe is where vanilla actually executes a recipe. It is called from perform in
-- singleplayer and from complete on a server, which is why a mod hooks it rather than
-- either of those and gets the authoritative side for free.
--
-- getDuration returns craftRecipe:getTime(character) * 5. The real getTime shortens a
-- craft by a twentieth of its base time per skill level above the requirement, but only
-- for skills the recipe names in SkillRequired or xpAward. Ripping names none, so it
-- returns the flat script time however good the character is, which is what the stub
-- reproduces and what the compendium is here to change.
local function NewHandcraftLogic(Data)
	local Logic = {}
	function Logic:getRecipeData() return Data end
	return Logic
end

function Harness.NewCraftRecipe(Name, Time)
	local Recipe = {}
	function Recipe:getName() return Name end
	function Recipe:getTime() return Time or 80 end
	return Recipe
end

ISHandcraftAction = ISBaseTimedAction:derive("ISHandcraftAction")

function ISHandcraftAction:performRecipe()
	self.VanillaPerforms = (self.VanillaPerforms or 0) + 1

	local Data = self.logic and self.logic:getRecipeData()
	if Data and Data.Destroy then Data:Destroy() end
end

function ISHandcraftAction:getDuration()
	if self.character:isTimedActionInstant() then return 1 end
	if not self.craftRecipe then return -1 end

	return self.craftRecipe:getTime(self.character) * 5
end

function Harness.NewHandcraftAction(Character, Recipe, Data)
	local Action = ISBaseTimedAction.new(ISHandcraftAction, Character)
	Action.character = Character
	Action.craftRecipe = Recipe
	Action.logic = NewHandcraftLogic(Data)

	return Action
end

--// Context Menus
-- Records what a mod added, so a spec can find an option by name and click it.
-- Options live on a lowercase "options" because that is the field vanilla uses, and mods
-- that adjust an entry vanilla added have to walk it by that name. Click dispatches the
-- way ISContextMenu really does, target first and then the parameters.
local function NewContextMenu()
	local Menu = {}
	Menu.options = {}

	function Menu:addOption(Name, Target, Handler, P1, P2, P3)
		local Option = {
			name = Name, target = Target, onSelect = Handler,
			param1 = P1, param2 = P2, param3 = P3
		}

		function Option:Click()
			if self.notAvailable or not self.onSelect then return end
			self.onSelect(self.target, self.param1, self.param2, self.param3)
		end

		table.insert(self.options, Option)
		return Option
	end

	function Menu:addSubMenu(Option, Sub) Option.SubMenu = Sub end
	function Menu:addGetUpOption(Name, Target, Handler) return self:addOption(Name, Target, Handler) end

	function Menu:Find(Name)
		for _, Option in ipairs(self.options) do
			if Option.name == Name then return Option end
		end
		return nil
	end

	return Menu
end

Harness.NewContextMenu = NewContextMenu

ISContextMenu = {}
function ISContextMenu:getNew() return NewContextMenu() end

Metabolics = setmetatable({}, { __index = function(T, K) rawset(T, K, K) return K end })
CharacterActionAnims = setmetatable({}, { __index = function(T, K) rawset(T, K, K) return K end })

--// Literature
-- SkillBook maps the skill a book teaches to the perk that skill trains. Vanilla builds
-- it in XPSystem_SkillBook.lua and every literature path indexes it without checking, so
-- a skill missing from here throws exactly where the game would.
SkillBook = setmetatable({}, {
	__index = function(Table, Key)
		local Entry = { perk = Key }
		rawset(Table, Key, Entry)
		return Entry
	end
})

ISInventoryPane = ISInventoryPane or {}

function ISInventoryPane.getActualUniqueItems(Items)
	local Seen = {}
	local Unique = {}

	for _, Item in ipairs(Items) do
		local Type = Item.getFullType and Item:getFullType()
		if not Type or not Seen[Type] then
			if Type then Seen[Type] = true end
			table.insert(Unique, Item)
		end
	end

	return Unique
end

-- A skill book. LvlSkillTrained is the level needed to learn from it, and vanilla refuses
-- to read one more than a single level above the character.
function Harness.NewSkillBook(Skill, LvlSkillTrained, Pages)
	local Book = Harness.NewInventoryItem("Book")
	Book.Skill = Skill or "Carpentry"
	Book.Lvl = LvlSkillTrained or 3
	Book.Pages = Pages or 220

	function Book:getSkillTrained() return self.Skill end
	function Book:getLvlSkillTrained() return self.Lvl end
	function Book:getNumberOfPages() return self.Pages end
	function Book:getFullType() return "Base.Book" .. self.Skill .. tostring(self.Lvl) end
	function Book:setJobType(Value) self.JobType = Value end
	function Book:setJobDelta(Value) self.JobDelta = Value end

	return Book
end

-- Mirrors the branches of build 42's ISInventoryPaneContextMenu.doLiteratureMenu that the
-- compendium reacts to: a book whose level is out of reach gets a disabled Read carrying
-- the TooComplicated tooltip, and anything else gets a working one. Vanilla's other cases,
-- too dark, pictures, recently read, empty notebooks and the recipe list, are not
-- reproduced, because nothing here touches them.
ISInventoryPaneContextMenu = ISInventoryPaneContextMenu or {}

function ISInventoryPaneContextMenu.addToolTip()
	return { description = "" }
end

function ISInventoryPaneContextMenu.onLiteratureItems() end

function ISInventoryPaneContextMenu.doLiteratureMenu(Context, Items, PlayerNum)
	local Player = getSpecificPlayer(PlayerNum)

	for _, Item in ipairs(ISInventoryPane.getActualUniqueItems(Items)) do
		if Item.getLvlSkillTrained and Item:getLvlSkillTrained() ~= -1
			and Item:getLvlSkillTrained() > Player:getPerkLevel(SkillBook[Item:getSkillTrained()].perk) + 1 then

			local Nope = Context:addOption(getText("ContextMenu_Read"))
			Nope.notAvailable = true

			local Tooltip = ISInventoryPaneContextMenu.addToolTip()
			Tooltip.description = getText("ContextMenu_TooComplicated")
			Nope.toolTip = Tooltip
			return
		end
	end

	Context:addOption(getText("ContextMenu_Read"), Items,
		ISInventoryPaneContextMenu.onLiteratureItems, PlayerNum)
end

--// Player Windows
-- Keyed "<playerNum>:inventory" and "<playerNum>:loot", which is how a spec decides
-- which of the two windows it is building.
function getPlayerInventory(PlayerNum)
	return Harness.Pages[(PlayerNum or 0) .. ":inventory"]
end

function getPlayerLoot(PlayerNum)
	return Harness.Pages[(PlayerNum or 0) .. ":loot"]
end

function getSpecificPlayer(PlayerNum)
	return Harness.Players[PlayerNum or 0]
end

--// World
-- Squares the world hands out when nothing was registered for that spot. The generator
-- range walks thousands of them, so the default is a plain indoor floor and a spec only
-- states the ones it is about.
Harness.DefaultSquare = { Outside = false, Solid = true }

function getCell()
	local Cell = {}

	function Cell:getGridSquare(X, Y, Z)
		return Harness.Squares[tostring(X) .. "," .. tostring(Y) .. "," .. tostring(Z)]
	end

	-- The real one creates the square if the chunk is loaded and it does not exist yet,
	-- which is how anything scanning an area reaches ground it has never touched
	function Cell:getOrCreateGridSquare(X, Y, Z)
		local Registered = Harness.Squares[tostring(X) .. "," .. tostring(Y) .. "," .. tostring(Z)]
		if Registered then return Registered end

		return Harness.NewGridSquare(X, Y, Z,
			Harness.DefaultSquare.Outside, Harness.DefaultSquare.Solid)
	end

	return Cell
end

-- Registers a square holding one item, which is how the server side ground save is
-- driven in a spec
function Harness.PlaceItemOnGround(X, Y, Z, Item)
	local Objects = {}
	local WorldObject = {}
	function WorldObject:getItem() return Item end
	table.insert(Objects, WorldObject)

	local Square = {}
	function Square:getX() return X end
	function Square:getY() return Y end
	function Square:getZ() return Z end
	function Square:getWorldObjects()
		local List = {}
		function List:size() return #Objects end
		function List:get(Index) return Objects[Index + 1] end
		return List
	end

	Harness.Squares[tostring(X) .. "," .. tostring(Y) .. "," .. tostring(Z)] = Square
	return Square
end
