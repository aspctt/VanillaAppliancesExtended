--// Reorder Containers Spec
--// aspctt - 10.08.2026

--// Helpers
-- Builds a window holding the player's own inventory plus one bag per name given.
local function NewPage(Player, OnCharacter, ...)
	local Page = Harness.NewInventoryPage(Player.Number, OnCharacter)
	Page.Containers = { Player.Inventory }

	for _, Name in ipairs({ ... }) do
		local Item = Harness.NewInventoryItem(Name)
		table.insert(Page.Containers, Harness.NewContainer(Name, Item, nil))
	end

	Harness.Pages[Player.Number .. (OnCharacter ~= false and ":inventory" or ":loot")] = Page
	Page:refreshBackpacks()
	return Page
end

local function FindButton(Page, TypeName)
	for _, Button in ipairs(Page.backpacks) do
		if Button.inventory:getType() == TypeName then return Button end
	end
	return nil
end

-- Drags a button to a Y position and lets go, the way a player would
local function DragTo(Page, TypeName, Y)
	local Button = FindButton(Page, TypeName)
	if not Button then error("no button for " .. TypeName) end

	Harness.SetMouse(0, Button:getY())
	Button:onMouseDown(0, 0)
	Button.pressed = true

	Harness.SetMouse(0, Y + (Button:getHeight() / 2))
	Button:onMouseMove(0, Y - Button:getY())
	Button:onMouseUp(0, 0)

	return Button
end

-- Comfortably above every button. The mod clamps a drag to -4 and the topmost button
-- already sits at -1, so a smaller number would tie with it and the tie break, not the
-- drag, would decide the order.
local TOP = -10

local function Concat(List)
	return table.concat(List, ",")
end

--// Wiring
Test("the mod hooks the vanilla refresh event", function()
	AssertTrue(Harness.HandlerCount("OnRefreshInventoryWindowContainers") > 0,
		"should listen for OnRefreshInventoryWindowContainers")
end)

Test("nothing is reordered before the player asks for it", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "inventory,Bag,Crate",
		"an untouched window keeps the game's own order")
end)

--// Ordering
Test("a dragged container keeps its new place across a refresh", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	-- Drag the crate above everything
	DragTo(Page, "Crate", TOP)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Crate,inventory,Bag",
		"the order should survive the refresh a drag triggers")

	Page:refreshBackpacks()
	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Crate,inventory,Bag",
		"and every refresh after it")
end)

Test("the array and the screen agree after reordering", function()
	-- This is the whole point. Vanilla reads the array, the player reads the screen.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	DragTo(Page, "Purse", TOP)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)),
		Concat(Harness.ButtonOrderByPosition(Page)),
		"array order and on screen order must not diverge")
end)

Test("scroll height follows the bottom-most button", function()
	-- Vanilla sets it from backpacks[#backpacks]:getBottom(). Reordering only the
	-- buttons and not the array is what leaves this wrong.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	DragTo(Page, "Crate", TOP)
	Page:refreshBackpacks()

	local Lowest = 0
	for _, Button in ipairs(Page.backpacks) do
		if Button:getBottom() > Lowest then Lowest = Button:getBottom() end
	end

	AssertEquals(Page.containerButtonPanel.ScrollHeight, Lowest,
		"scroll height should reach the lowest button")
end)

Test("buttons are laid out with no gaps", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	DragTo(Page, "Purse", TOP)

	for Index, Button in ipairs(Page.backpacks) do
		AssertEquals(Button:getY(), ((Index - 1) * Page.buttonSize) - 1,
			"button " .. Index .. " should sit at its index")
	end
end)

Test("containers with no saved order keep the game's order", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	-- Give only the purse a position, well after the rest
	QolcReorderSetPriority(Player, FindButton(Page, "Purse").inventory, 500, true)
	Page:refreshBackpacks()

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Purse,inventory,Bag,Crate",
		"a set priority sorts ahead of anything unset, the rest hold their order")
end)

Test("repeated refreshes do not shuffle an untouched window", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	local First = Concat(Harness.ButtonOrderByArray(Page))
	for _ = 1, 10 do Page:refreshBackpacks() end

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), First, "order should be stable")
end)

Test("containers sharing a priority hold a fixed order", function()
	-- Nothing stops someone typing the same number twice in the priority window, and
	-- table.sort is not stable, so equal priorities need a deterministic tie break or
	-- the two swap places at random between refreshes.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate", "Purse")

	for _, Name in ipairs({ "Bag", "Crate", "Purse" }) do
		QolcReorderSetPriority(Player, FindButton(Page, Name).inventory, 7, true)
	end

	Page:refreshBackpacks()

	-- Creation order decides it, so the result is the one the player already sees rather
	-- than an arbitrary permutation of the three
	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "Bag,Crate,Purse,inventory",
		"equal priorities should fall back to the order the game built them in")

	local First = Concat(Harness.ButtonOrderByArray(Page))
	for _ = 1, 20 do Page:refreshBackpacks() end

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), First,
		"and must not drift on later refreshes")
end)

Test("a small nudge is not treated as a reorder", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	local Before = Concat(Harness.ButtonOrderByArray(Page))
	local Button = FindButton(Page, "Crate")

	Harness.SetMouse(0, Button:getY())
	Button:onMouseDown(0, 0)
	Button.pressed = true
	Harness.SetMouse(0, Button:getY() + 2)
	Button:onMouseMove(0, 2)
	Button:onMouseUp(0, 0)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), Before,
		"a couple of pixels should still count as a click")
end)

-- Reported in game: swap the second and third containers and the icons trade places but
-- each button opens the other's inventory.
Test("a button opens the container whose icon it shows", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	DragSlot = nil
	DragTo(Page, "KeyRing", TOP)

	for Index, Button in ipairs(Page.backpacks) do
		AssertEquals(Button.Image, "icon:" .. Button.inventory:getType(),
			"button " .. Index .. " shows one container's icon and carries another")
	end
end)

Test("clicking a moved button opens that container", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	DragTo(Page, "KeyRing", TOP)
	Page:refreshBackpacks()

	for _, Button in ipairs(Page.backpacks) do
		Page:onBackpackClick(Button)
		AssertEquals(Page.SelectedInventory, Button.inventory,
			"clicking a button must open the container it is showing")
	end
end)

Test("recycled buttons carry the right container after a reorder", function()
	-- Vanilla pools and reuses button objects, so the one showing the keyring now may
	-- have been the backpack's a refresh ago.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	DragTo(Page, "KeyRing", TOP)

	for _ = 1, 3 do
		Page:refreshBackpacks()
		for Index, Button in ipairs(Page.backpacks) do
			AssertEquals(Button.Image, "icon:" .. Button.inventory:getType(),
				"icon and inventory drifted apart on button " .. Index)
		end
	end

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), "KeyRing,inventory,Backpack",
		"and the chosen order should still hold")
end)

-- Reported in game: the order swaps correctly but the container underneath opens.
Test("dropping onto another container does not open it", function()
	-- On release the dragged button gets onMouseUpOutside while the button it landed on
	-- gets onMouseUp. Unguarded, that second event is an ordinary click and selects
	-- whatever was underneath, which reads exactly like the two having swapped contents.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	local Dragged = FindButton(Page, "KeyRing")
	local Target = FindButton(Page, "Backpack")
	Page.SelectedInventory = nil

	Harness.SetMouse(0, Dragged:getY())
	Dragged:onMouseDown(0, 0)
	Dragged.pressed = true

	Harness.SetMouse(0, TOP + (Dragged:getHeight() / 2))
	Dragged:onMouseMove(0, -40)

	-- The button under the cursor receives the release, the dragged one gets outside
	Target.pressed = true
	Target:onMouseUp(0, 0)
	Dragged:onMouseUpOutside(0, 0)

	AssertNil(Page.SelectedInventory, "finishing a drag must not select anything")
end)

Test("the same release order the other way round is also ignored", function()
	-- Which of the two fires first is not guaranteed, so neither order may select.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	local Dragged = FindButton(Page, "KeyRing")
	local Target = FindButton(Page, "Backpack")
	Page.SelectedInventory = nil

	Harness.SetMouse(0, Dragged:getY())
	Dragged:onMouseDown(0, 0)
	Dragged.pressed = true

	Harness.SetMouse(0, TOP + (Dragged:getHeight() / 2))
	Dragged:onMouseMove(0, -40)

	Dragged:onMouseUpOutside(0, 0)
	Target.pressed = true
	Target:onMouseUp(0, 0)

	AssertNil(Page.SelectedInventory, "finishing a drag must not select anything")
end)

Test("a swallowed click still releases the button", function()
	-- Suppressing the drop target's click skips vanilla's handler, which is what clears
	-- pressed. Left set, the next mouse movement over that button starts a drag nobody
	-- asked for and commits a new order on release.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	local Dragged = FindButton(Page, "KeyRing")
	local Target = FindButton(Page, "Backpack")

	Harness.SetMouse(0, Dragged:getY())
	Dragged:onMouseDown(0, 0)
	Dragged.pressed = true

	Harness.SetMouse(0, TOP + (Dragged:getHeight() / 2))
	Dragged:onMouseMove(0, -40)

	Target.pressed = true
	Target:onMouseUp(0, 0)
	Dragged:onMouseUpOutside(0, 0)

	AssertFalse(Target.pressed, "the button the drag landed on must not stay pressed")
end)

Test("a drag that never finishes does not wedge the window", function()
	-- If the window is left thinking a drag is running, every click after it is
	-- swallowed. A fresh press has to clear that.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	Page.QolcDragging = true

	local Button = FindButton(Page, "Backpack")
	Page.SelectedInventory = nil

	Harness.SetMouse(0, Button:getY())
	Button:onMouseDown(0, 0)
	Button.pressed = true
	Button:onMouseUp(0, 0)

	AssertEquals(Page.SelectedInventory, Button.inventory, "a plain click should still open it")
end)

Test("an ordinary click still selects its container", function()
	-- The guard must not swallow real clicks, only the release that ends a drag.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	local Button = FindButton(Page, "Backpack")
	Page.SelectedInventory = nil

	Harness.SetMouse(0, Button:getY())
	Button:onMouseDown(0, 0)
	Button.pressed = true
	Button:onMouseUp(0, 0)

	AssertEquals(Page.SelectedInventory, Button.inventory, "a plain click should still open it")
end)

-- Reported in game: the swap applied, then undid itself a moment later. The commit was
-- deriving the whole order from where every button happened to be sitting, so a second
-- call during a refresh read the half rebuilt layout and wrote the game's own order back.
Test("a commit during a rebuild cannot undo the chosen order", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	DragTo(Page, "KeyRing", TOP)
	local Chosen = Concat(Harness.ButtonOrderByArray(Page))
	AssertEquals(Chosen, "KeyRing,inventory,Backpack", "the drag should have taken effect")

	-- Exactly what a stray commit sees: buttons back in the game's own layout, before
	-- the chosen order has been reapplied
	for Index, Button in ipairs(Page.backpacks) do
		Button:setY(((Index - 1) * Page.buttonSize) - 1)
	end
	QolcReorderCommitOrder(Page, nil)

	Page:refreshBackpacks()
	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), Chosen,
		"a commit with no dragged button must change nothing")
end)

Test("dropping a button back where it started changes nothing", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	local Before = Concat(Harness.ButtonOrderByArray(Page))
	local Dragged = FindButton(Page, "Crate")

	QolcReorderCommitOrder(Page, Dragged)
	Page:refreshBackpacks()

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), Before, "no move, no change")
end)

--// Locking
Test("a locked window refuses to reorder", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag", "Crate")

	QolcReorderToggleLock(Page)
	AssertTrue(QolcReorderIsLocked(Page), "the window should now be locked")

	local Before = Concat(Harness.ButtonOrderByArray(Page))
	DragTo(Page, "Crate", TOP)

	AssertEquals(Concat(Harness.ButtonOrderByArray(Page)), Before, "dragging should do nothing")
end)

Test("the lock toggles back off", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag")

	QolcReorderToggleLock(Page)
	QolcReorderToggleLock(Page)

	AssertFalse(QolcReorderIsLocked(Page), "a second click should unlock it")
end)

Test("the inventory and loot windows lock separately", function()
	local Player = Harness.NewPlayer(0, true)
	local Inventory = NewPage(Player, true, "Bag")
	local Loot = NewPage(Player, false, "Crate")

	QolcReorderData.GetOptions(Player).SortLoot = true
	QolcReorderToggleLock(Inventory)

	AssertTrue(QolcReorderIsLocked(Inventory), "the inventory window should be locked")
	AssertFalse(QolcReorderIsLocked(Loot), "the loot window should be untouched")
end)

--// Loot Window
Test("loot sorting is off until it is turned on", function()
	local Player = Harness.NewPlayer(0, true)
	local Loot = NewPage(Player, false, "Crate", "Locker")

	AssertFalse(QolcReorderIsSortingEnabled(Loot), "loot sorting should start off")

	local Before = Concat(Harness.ButtonOrderByArray(Loot))
	DragTo(Loot, "Locker", TOP)
	AssertEquals(Concat(Harness.ButtonOrderByArray(Loot)), Before,
		"dragging in the loot window should do nothing while it is off")
end)

Test("the inventory window always allows sorting", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Bag")

	AssertTrue(QolcReorderIsSortingEnabled(Page), "your own inventory is never opt in")
end)

Test("turning loot sorting on lets it reorder", function()
	local Player = Harness.NewPlayer(0, true)
	local Loot = NewPage(Player, false, "Crate", "Locker")

	QolcReorderData.GetOptions(Player).SortLoot = true
	AssertTrue(QolcReorderIsSortingEnabled(Loot), "loot sorting should now be on")

	DragTo(Loot, "Locker", TOP)
	AssertEquals(Harness.ButtonOrderByArray(Loot)[1], "Locker", "the locker should have moved to the top")
end)

--// Storage
-- Reported in game: after a swap the order held for a few refreshes and then reverted
-- on its own. The order was being kept in a nested table on the container's own item,
-- and those writes do not survive. It lives on the player now.
Test("the order is stored on the player, not on the container's item", function()
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	DragTo(Page, "KeyRing", TOP)

	local KeyRing = FindButton(Page, "KeyRing").inventory
	AssertNotNil(Player:getModData().QolcReorder, "the player should carry the order")
	AssertNil(KeyRing:getContainingItem():getModData().QolcReorder,
		"nothing should be written into the item's mod data")
end)

Test("what is stored is a plain number", function()
	-- Not a table. A nested table on an item is what was being lost, and keeping the
	-- values flat means nothing here depends on that behaviour again.
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")

	DragTo(Page, "KeyRing", TOP)

	local Count = 0
	for Key, Value in pairs(Player:getModData().QolcReorder) do
		Count = Count + 1
		AssertEquals(type(Value), "number", "entry " .. tostring(Key) .. " should be a number")
	end

	AssertTrue(Count >= 2, "every container in the window should have an entry")
end)

Test("a bag is keyed by its item id, which the save keeps", function()
	local Player = Harness.NewPlayer(0, true)
	local Item = Harness.NewInventoryItem("Backpack")
	local Bag = Harness.NewContainer("Backpack", Item, nil)

	AssertEquals(QolcReorderData.GetKey(Player, Bag), "item:" .. tostring(Item:getID()),
		"the item id is what survives a reload")
end)

Test("the player's own inventory is keyed separately from any bag", function()
	local Player = Harness.NewPlayer(0, true)
	local Item = Harness.NewInventoryItem("Backpack")
	local Bag = Harness.NewContainer("Backpack", Item, nil)

	AssertTrue(QolcReorderData.GetKey(Player, Player.Inventory) ~= QolcReorderData.GetKey(Player, Bag),
		"the two must not collide")
end)

Test("two containers of the same type get different keys", function()
	-- Two bags of one type would collide if the key were the container type.
	local Player = Harness.NewPlayer(0, true)
	local One = Harness.NewContainer("Bag", Harness.NewInventoryItem("Bag"), nil)
	local Two = Harness.NewContainer("Bag", Harness.NewInventoryItem("Bag"), nil)

	AssertTrue(QolcReorderData.GetKey(Player, One) ~= QolcReorderData.GetKey(Player, Two),
		"same type, different bags, different keys")
end)

Test("a world container is keyed by where it stands", function()
	local Player = Harness.NewPlayer(0, true)
	local Object = Harness.NewIsoObject()
	Object.Square = { X = 10, Y = 20, Z = 0 }
	function Object:getSquare()
		local S = self.Square
		return { getX = function() return S.X end, getY = function() return S.Y end, getZ = function() return S.Z end }
	end

	local Crate = Harness.NewContainer("Crate", nil, Object)
	AssertEquals(QolcReorderData.GetKey(Player, Crate), "obj:10,20,0:Crate", "keyed by position")
end)

Test("clearing a priority removes the entry", function()
	local Player = Harness.NewPlayer(0, true)

	QolcReorderSetPriority(Player, Player.Inventory, 5)
	AssertEquals(QolcReorderData.GetPriority(Player, Player.Inventory), 5, "should be set")

	QolcReorderSetPriority(Player, Player.Inventory, nil)
	AssertNil(QolcReorderData.GetPriority(Player, Player.Inventory), "should be cleared, not left stale")
end)

Test("each player keeps their own order", function()
	local One = Harness.NewPlayer(0, true)
	local Two = Harness.NewPlayer(1, true)

	local Item = Harness.NewInventoryItem("Crate")
	local Crate = Harness.NewContainer("Crate", Item, nil)

	QolcReorderSetPriority(One, Crate, 10)
	QolcReorderSetPriority(Two, Crate, 90)

	AssertEquals(QolcReorderData.GetPriority(One, Crate), 10, "player one's choice")
	AssertEquals(QolcReorderData.GetPriority(Two, Crate), 90, "player two's choice")
end)

--// Multiplayer
Test("a client transmits its own order and sends no commands", function()
	Harness.IsClient = true
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")
	local Before = Player.Transmits

	DragTo(Page, "KeyRing", TOP)

	AssertTrue(Player.Transmits > Before, "a player owns their own mod data")
	AssertEquals(#Harness.ClientCommands, 0, "so the server needs no command at all")
end)

Test("singleplayer transmits nothing", function()
	Harness.IsClient = false
	local Player = Harness.NewPlayer(0, true)
	local Page = NewPage(Player, true, "Backpack", "KeyRing")
	local Before = Player.Transmits

	DragTo(Page, "KeyRing", TOP)

	AssertEquals(Player.Transmits, Before, "there is no server to tell")
	AssertEquals(#Harness.ClientCommands, 0, "and nothing to send")
end)

--// Translations
Test("every label the reorder UI asks for resolves", function()
	local Keys = {
		"UI_QoLC_Reorder_Locked",
		"UI_QoLC_Reorder_Unlocked",
		"UI_QoLC_Reorder_SortLoot",
		"UI_QoLC_Reorder_Priority",
		"UI_QoLC_Reorder_Priority_tooltip"
	}

	for _, Key in ipairs(Keys) do
		AssertNotNil(Translations[Key], "missing translation for " .. Key)
	end
end)
