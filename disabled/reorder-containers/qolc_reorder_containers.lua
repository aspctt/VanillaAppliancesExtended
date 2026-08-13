--// Reorder Containers
--// Reorder Containers, Workshop 2901962885 - Original design, MIT licensed
--// aspctt - 10.08.2026
--// Drag the container buttons down the side of the inventory window to put them in
--// whatever order suits you. The order is remembered per container, so a backpack keeps
--// its place after being dropped and picked up again.
--//
--// Rewritten rather than ported, around one change: this reorders the backpacks array
--// itself and derives each button's position from its index, where the original moved
--// the buttons and left the array in the order the game built it.
--//
--// That matters because vanilla reads the array, not the screen. Scroll height comes
--// from backpacks[#backpacks]:getBottom(), the mouse wheel and the controller bumpers
--// walk it by index, and ISBaseIcon builds its context menu straight off it. Leaving it
--// alone is what forces mods doing this to patch scrolling, the bumpers and the context
--// menu one at a time. Reordering it makes all four correct at once.
--//
--// It also hooks the OnRefreshInventoryWindowContainers event that build 42 added
--// rather than wrapping refreshBackpacks, so nothing here joins an override chain that
--// another mod is also in.
--//
--// Client only, and nothing is sent to the server. The order is stored on the player,
--// who owns their own mod data, so transmitting it is all multiplayer needs. See
--// qolc_reorder_data.lua for why it is stored there rather than on the container.

--// Textures
-- Vanilla's own gears icon, so the options button needs no bundled art.
local TextureOptions = getTexture("media/ui/gears.png")
local TextureUnlocked = getTexture("media/textures/GUI/qolc_lock_open.png")
local TextureLocked = getTexture("media/textures/GUI/qolc_lock_closed.png")

--// Functions
-- Sorting is always on for your own inventory. The loot window is opt in, because
-- dragging there is easy to do by accident while looting.
function QolcReorderIsSortingEnabled(Page)
	if not Page then return false end
	if Page.onCharacter then return true end

	local Options = QolcReorderData.GetOptions(getSpecificPlayer(Page.player))
	return Options and Options.SortLoot or false
end

function QolcReorderIsLocked(Page)
	if not Page then return true end

	local Options = QolcReorderData.GetOptions(getSpecificPlayer(Page.player))
	if not Options then return true end

	if Page.onCharacter then return Options.LockInventory end
	return Options.LockLoot
end

function QolcReorderGetPriority(Player, Inventory, Fallback)
	local Priority = QolcReorderData.GetPriority(Player, Inventory)
	if Priority then return Priority end

	return QolcReorderData.PRIORITY_UNSET + (Fallback or 0)
end

function QolcReorderSetPriority(Player, Inventory, Priority)
	QolcReorderData.SetPriority(Player, Inventory, Priority)
end

-- Puts the buttons in their saved order. Rewrites the array itself, then lays the
-- buttons out from their new index, which is the whole point of this feature.
function QolcReorderApplyOrder(Page)
	local Player = getSpecificPlayer(Page.player)
	if not Player or not Page.backpacks then return end

	local Ordered = {}
	for Index, Button in ipairs(Page.backpacks) do
		Ordered[Index] = {
			Priority = QolcReorderGetPriority(Player, Button.inventory, Index),
			Button = Button,
			Index = Index
		}
	end

	-- table.sort is not stable, so creation order is the explicit tie break. Without it
	-- two containers with no saved position could swap places on every refresh.
	table.sort(Ordered, function(A, B)
		if A.Priority == B.Priority then return A.Index < B.Index end
		return A.Priority < B.Priority
	end)

	for Index, Entry in ipairs(Ordered) do
		Page.backpacks[Index] = Entry.Button
		-- Matches vanilla's own placement in addContainerButton
		Entry.Button:setY(((Index - 1) * Page.buttonSize) - 1)
	end
end

-- Called once a drag finishes, with the button that was dragged.
--
-- Dragged is required and is the whole point of the argument. Button positions only mean
-- anything for the instant after a drop, and a second call does happen while the window
-- is rebuilding: it read the half rebuilt layout and wrote the game's own order straight
-- back over the chosen one, which is what made a reorder undo itself a moment later.
-- Refusing to run without a dragged button is what stops that.
function QolcReorderCommitOrder(Page, Dragged)
	local Player = getSpecificPlayer(Page.player)
	if not Player or not Page.backpacks or not Dragged then return end

	-- Order comes from where the buttons are sitting, which is what a player just
	-- arranged by hand and so is the most forgiving reading of the drop. Judging it from
	-- the dragged button's position alone was tried and rejected too many near misses.
	local Ordered = {}
	for Index, Button in ipairs(Page.backpacks) do
		table.insert(Ordered, { Button = Button, Index = Index })
	end

	table.sort(Ordered, function(A, B)
		local Difference = A.Button:getY() - B.Button:getY()
		if Difference == 0 then return A.Index < B.Index end
		return Difference < 0
	end)

	-- Some world objects expose more than one container at the same spot, and those
	-- share one key. Only the first is numbered so the second cannot overwrite it.
	local Seen = {}
	local Step = 0

	for _, Entry in ipairs(Ordered) do
		local Key = QolcReorderData.GetKey(Player, Entry.Button.inventory)
		if Key and not Seen[Key] then
			Seen[Key] = true

			Step = Step + QolcReorderData.PRIORITY_STEP
			QolcReorderData.SetPriority(Player, Entry.Button.inventory, Step)
		end
	end
end

--// Drag Handling
-- How long after a drag ends a release still counts as part of it rather than as a
-- click. Both events land in the same frame, so this only has to survive one.
local DRAG_GRACE_MS = 150

-- True while a drag is running on this window, and briefly after it finishes.
local function DragJustEnded(Page)
	if not Page then return false end
	if Page.QolcDragging then return true end

	local Ended = Page.QolcDragEndedMs
	if not Ended then return false end

	return (getTimestampMs() - Ended) < DRAG_GRACE_MS
end

-- Vanilla reuses container buttons out of a pool, so a button can be handed back here
-- more than once. Each original handler is captured only the first time.
local function InjectDragging(Button, Page)
	Button.QolcPage = Page

	if not Button.QolcMouseDown then
		Button.QolcMouseDown = Button.onMouseDown
		Button.QolcMouseMove = Button.onMouseMove
		Button.QolcMouseMoveOutside = Button.onMouseMoveOutside
		Button.QolcMouseUp = Button.onMouseUp
		Button.QolcMouseUpOutside = Button.onMouseUpOutside
	end

	function Button:onMouseDown(X, Y)
		if self.QolcMouseDown then self:QolcMouseDown(X, Y) end

		-- A fresh press ends any drag the window still thinks is running. Without this
		-- a drag that never reached its own release would leave the window stuck, and
		-- every click after it would be swallowed.
		if self.QolcPage then self.QolcPage.QolcDragging = false end

		self.QolcStartMouseY = getMouseY()
		self.QolcStartY = self:getY()
		self.QolcCanDrag = not QolcReorderIsLocked(self.QolcPage)
			and QolcReorderIsSortingEnabled(self.QolcPage)
	end

	-- Skip is set when this is being called on from onMouseMoveOutside, which has
	-- already run the original handler
	function Button:onMouseMove(DX, DY, Skip)
		if not Skip and self.QolcMouseMove then self:QolcMouseMove(DX, DY) end
		if not self.pressed or not self.QolcCanDrag then return end

		local Page = self.QolcPage
		local Parent = self.parent
		if not Page or not Parent then return end

		-- Half a button of travel before this counts as a drag, otherwise an ordinary
		-- click with a twitchy hand would start reordering
		if math.abs(self.QolcStartMouseY - getMouseY()) > Page.buttonSize / 2 then
			self.QolcDragging = true
			-- Recorded on the window as well as the button, because the release that
			-- ends this drag is delivered to whichever button is under the cursor, not
			-- to this one
			Page.QolcDragging = true
		end
		if not self.QolcDragging then return end

		local NewY = getMouseY() - Parent:getAbsoluteY() - (self:getHeight() / 2)
		if NewY < -4 then NewY = -4 end

		self:setY(NewY)
		self:bringToTop()
	end

	function Button:onMouseMoveOutside(DX, DY)
		if self.QolcMouseMoveOutside then self:QolcMouseMoveOutside(DX, DY) end
		if self.pressed and self.QolcCanDrag then
			self:onMouseMove(DX, DY, true)
		end
	end

	-- A finished drag must not also register as a click, or letting go over another
	-- container would open that container. Dropping a bag onto its neighbour reorders
	-- the two and, without this, opens the neighbour at the same time.
	--
	-- Both buttons hear about the release. The one being dragged gets onMouseUpOutside
	-- and the one underneath gets onMouseUp, in no guaranteed order, so the window
	-- carries the flag rather than either button. The timestamp covers the case where
	-- the dragged button is dealt with first and has already cleared it.
	local function Finish(Self, X, Y, Original)
		local Page = Self.QolcPage

		if not Page or not Self.QolcDragging then
			if DragJustEnded(Page) then
				-- Swallowing the click means vanilla's handler never runs, and that is
				-- what would have cleared pressed. Left set, the next mouse movement
				-- over this button starts a drag nobody asked for.
				Self.pressed = false
				return
			end

			-- Not every button carries all five handlers, so check before calling on
			local Handler = Original and Self[Original]
			if Handler then Handler(Self, X, Y) end
			return
		end

		Page.QolcDragEndedMs = getTimestampMs()
		Page.QolcDragging = false

		Self.QolcDragging = false
		Self.pressed = false

		-- Too small a move to mean anything, so put it back rather than renumbering
		if math.abs(Self:getY() - Self.QolcStartY) <= Page.buttonSize / 2 then
			Self:setY(Self.QolcStartY)
			return
		end

		QolcReorderCommitOrder(Page, Self)
		Page:refreshBackpacks()
	end

	function Button:onMouseUp(X, Y) Finish(self, X, Y, "QolcMouseUp") end
	function Button:onMouseUpOutside(X, Y) Finish(self, X, Y, "QolcMouseUpOutside") end

	return Button
end

--// Overrides
-- Only two, and neither is a chain another mod is likely to be in. The ordering itself
-- goes through the vanilla event below.
local VanillaAddContainerButton = ISInventoryPage.addContainerButton
function ISInventoryPage:addContainerButton(Container, Texture, Name, Tooltip)
	local Button = VanillaAddContainerButton(self, Container, Texture, Name, Tooltip)
	return InjectDragging(Button, self)
end

local VanillaCreateChildren = ISInventoryPage.createChildren
function ISInventoryPage:createChildren()
	VanillaCreateChildren(self)

	local Size = self.buttonSize / 2
	local X = self:getWidth() - Size
	local Y = self:getHeight() - Size - self:titleBarHeight()

	local Page = self

	local OptionsButton = ISButton:new(X, Y, Size, Size + 4, "", self)
	OptionsButton.anchorBottom = true
	OptionsButton.anchorRight = true
	OptionsButton.anchorLeft = false
	OptionsButton.anchorTop = false
	OptionsButton.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
	OptionsButton:setImage(TextureOptions)
	-- Vanilla's gears icon is 32 by 29, and the button is half a container button, which
	-- is 16 pixels on the smallest setting. Without this the image spills out of it.
	OptionsButton:forceImageSize(Size - 2, Size - 2)
	OptionsButton:initialise()
	OptionsButton:instantiate()
	OptionsButton:setOnClick(function() QolcReorderOpenPriorityWindow(Page) end)
	self:addChild(OptionsButton)
	self.QolcOptionsButton = OptionsButton

	X = X - Size
	local LockButton = ISButton:new(X, Y, Size, Size + 4, "", self)
	LockButton.anchorBottom = true
	LockButton.anchorRight = true
	LockButton.anchorLeft = false
	LockButton.anchorTop = false
	LockButton.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
	LockButton:forceImageSize(Size - 2, Size - 2)
	LockButton:initialise()
	LockButton:instantiate()
	LockButton:setOnClick(function() QolcReorderToggleLock(Page) end)
	self:addChild(LockButton)
	self.QolcLockButton = LockButton

	QolcReorderRefreshLock(self)
end

--// Lock Button
function QolcReorderRefreshLock(Page)
	local Button = Page and Page.QolcLockButton
	if not Button then return end

	local Locked = QolcReorderIsLocked(Page) or not QolcReorderIsSortingEnabled(Page)
	Button:setImage(Locked and TextureLocked or TextureUnlocked)
	Button:setTooltip(getText(Locked and "UI_QoLC_Reorder_Locked" or "UI_QoLC_Reorder_Unlocked"))
end

function QolcReorderToggleLock(Page)
	local Player = getSpecificPlayer(Page.player)
	local Options = QolcReorderData.GetOptions(Player)
	if not Options then return end

	-- Sorting is off for this window entirely, so the lock has nothing to say. Send the
	-- player to the options window that can turn it on instead.
	if not QolcReorderIsSortingEnabled(Page) then
		QolcReorderOpenPriorityWindow(Page)
		return
	end

	if Page.onCharacter then
		Options.LockInventory = not Options.LockInventory
	else
		Options.LockLoot = not Options.LockLoot
	end

	Player:transmitModData()
	QolcReorderRefreshLock(Page)
end

--// Connections
-- buttonsAdded is the last phase before vanilla reads the array for selection and
-- scroll height, so reordering here lands before anything depends on it.
local function OnRefreshInventoryWindowContainers(Page, Phase)
	if Phase ~= "buttonsAdded" then return end
	if not QolcReorderIsSortingEnabled(Page) then return end

	QolcReorderApplyOrder(Page)
end

Events.OnRefreshInventoryWindowContainers.Add(OnRefreshInventoryWindowContainers)
