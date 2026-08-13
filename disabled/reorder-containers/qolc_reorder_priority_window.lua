--// Reorder Containers Priority Window
--// Reorder Containers, Workshop 2901962885 - Original design, MIT licensed
--// aspctt - 10.08.2026
--// Sets a container's sorting priority by hand, for anyone who would rather type a
--// number than drag. Lower sorts higher up the window.
--//
--// Also where loot window sorting is turned on, because that window's own lock button
--// has nothing to toggle until it is.
--//
--// Method names here are vanilla's, not ours. ISPanel calls createChildren and
--// initialise by those exact names, so only the fields this file adds carry a prefix.

require "ISUI/ISPanel"

--// Tuning
local WINDOW_HEIGHT = 120
local WINDOW_WIDTH = 200
local BUTTON_HEIGHT = 25
local ENTRY_WIDTH = 100
local PADDING = 10

QolcReorderPriorityWindow = ISPanel:derive("QolcReorderPriorityWindow")

--// Functions
function QolcReorderPriorityWindow:new(X, Y, Page, Inventory)
	local Window = ISPanel:new(X, Y, WINDOW_WIDTH, WINDOW_HEIGHT)
	setmetatable(Window, self)
	self.__index = self

	Window.backgroundColor.a = 0.9
	Window.QolcInventory = Inventory
	Window.QolcPage = Page
	Window.QolcIsLoot = not Page.onCharacter

	return Window
end

-- The player's own inventory has no containing item to take a name from, so it is
-- labelled with the character's name the way vanilla labels it.
function QolcReorderPriorityWindow:getTargetName()
	local Player = getSpecificPlayer(self.QolcPage.player)
	if not Player or not self.QolcInventory then return "" end

	if self.QolcInventory == Player:getInventory() then
		local Descriptor = Player:getDescriptor()
		if not Descriptor then return "" end
		return getText("IGUI_InventoryName", Descriptor:getForename(), Descriptor:getSurname())
	end

	local Item = self.QolcInventory:getContainingItem()
	if Item then return Item:getName() end

	return getTextOrNull("IGUI_ContainerTitle_" .. self.QolcInventory:getType()) or ""
end

function QolcReorderPriorityWindow:createChildren()
	local Player = getSpecificPlayer(self.QolcPage.player)
	local Y = PADDING

	-- Only the loot window can have sorting switched off, so the tick box is pointless
	-- on the inventory window
	if self.QolcIsLoot then
		local Options = QolcReorderData.GetOptions(Player)

		self.QolcLootTick = ISTickBox:new(15, Y, 20, 20, "")
		self.QolcLootTick:initialise()
		self.QolcLootTick:addOption(getText("UI_QoLC_Reorder_SortLoot"))
		self.QolcLootTick:setSelected(1, Options and Options.SortLoot or false)
		self:addChild(self.QolcLootTick)

		Y = Y + 25
	end

	self.QolcTitle = ISLabel:new(0, Y, 10, self:getTargetName(), 1, 1, 1, 1, UIFont.Small, true)
	self.QolcTitle:initialise()
	self.QolcTitle:instantiate()
	self.QolcTitle:setX((self:getWidth() - self.QolcTitle:getWidth()) / 2)
	self:addChild(self.QolcTitle)

	Y = Y + 25
	self.QolcSubtitle = ISLabel:new(0, Y, 10, getText("UI_QoLC_Reorder_Priority"), 1, 1, 1, 0.7, UIFont.Small, true)
	self.QolcSubtitle:initialise()
	self.QolcSubtitle:instantiate()
	self.QolcSubtitle:setX((self:getWidth() - self.QolcSubtitle:getWidth()) / 2)
	self:addChild(self.QolcSubtitle)

	Y = Y + 25
	local Current = QolcReorderGetPriority(Player, self.QolcInventory, 0)

	self.QolcEntry = ISTextEntryBox:new(tostring(math.floor(Current)), 0, Y, ENTRY_WIDTH, 20)
	self.QolcEntry:initialise()
	self.QolcEntry:instantiate()
	self.QolcEntry:setOnlyNumbers(true)
	self.QolcEntry:setTooltip(getText("UI_QoLC_Reorder_Priority_tooltip"))
	self.QolcEntry:setX((self:getWidth() - ENTRY_WIDTH) / 2)
	self:addChild(self.QolcEntry)

	Y = Y + 55
	if Y > self:getHeight() then self:setHeight(Y) end

	local Half = self:getWidth() / 2
	local ButtonY = self:getHeight() - BUTTON_HEIGHT

	self.QolcOk = ISButton:new(0, ButtonY, Half, BUTTON_HEIGHT, getText("UI_Ok"), self, QolcReorderPriorityWindow.onOK)
	self.QolcOk:initialise()
	self.QolcOk:instantiate()
	self:addChild(self.QolcOk)

	self.QolcCancel = ISButton:new(Half, ButtonY, Half, BUTTON_HEIGHT, getText("UI_Cancel"), self, QolcReorderPriorityWindow.onCancel)
	self.QolcCancel:initialise()
	self.QolcCancel:instantiate()
	self:addChild(self.QolcCancel)

	self:bringToTop()
end

function QolcReorderPriorityWindow:onOK()
	local Player = getSpecificPlayer(self.QolcPage.player)

	if self.QolcLootTick then
		local Options = QolcReorderData.GetOptions(Player)
		if Options then
			Options.SortLoot = self.QolcLootTick.selected[1] and true or false
			Player:transmitModData()
		end
	end

	-- An empty or unreadable box clears the priority rather than storing nothing, which
	-- puts the container back in the game's own order
	local Number = tonumber(self.QolcEntry:getText())
	if self.QolcInventory then
		QolcReorderSetPriority(Player, self.QolcInventory, Number)
	end

	self:removeFromUIManager()
	self.QolcPage:refreshBackpacks()
	QolcReorderRefreshLock(self.QolcPage)
end

function QolcReorderPriorityWindow:onCancel()
	self:removeFromUIManager()
end

-- Opens on whichever container is currently selected in that window
function QolcReorderOpenPriorityWindow(Page)
	local Selected = Page.selectedButton
	if not Selected then return end

	local X = (getCore():getScreenWidth() - WINDOW_WIDTH) / 2
	local Y = (getCore():getScreenHeight() - WINDOW_HEIGHT) / 2

	local Window = QolcReorderPriorityWindow:new(X, Y, Page, Selected.inventory)
	Window:initialise()
	Window:setAlwaysOnTop(true)
	Window:setCapture(true)
	Window:addToUIManager()
end
