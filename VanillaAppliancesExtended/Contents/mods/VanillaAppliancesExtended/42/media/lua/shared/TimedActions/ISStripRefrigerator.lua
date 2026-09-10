require "TimedActions/ISBaseTimedAction"

-- The type has to match the global name. In multiplayer the server rebuilds
-- the action by calling "<type>.new", and "StripRefrigerator.new" does not
-- exist, so the server never ran it.
ISStripRefrigerator = ISBaseTimedAction:derive("ISStripRefrigerator");

function ISStripRefrigerator:isValid()
    -- The server removes the appliance as the action finishes, so the client
    -- cannot keep checking for it. Same approach as ISClothingExtraAction.
    if not self.item then return false end
    return isClient() or self.character:getInventory():contains(self.item);
end

function ISStripRefrigerator:update()
    self.item:setJobDelta(self:getJobDelta());
    self.character:setMetabolicTarget(Metabolics.UsingTools);
end

function ISStripRefrigerator:start()
    self.item:setJobDelta(0.0);
    self:setActionAnim(CharacterActionAnims.Craft);
end

function ISStripRefrigerator:stop()
    self.item:setJobDelta(0.0);
    ISBaseTimedAction.stop(self);
end

function ISStripRefrigerator:perform()
    -- Only ends the action on this side. The work happens in complete().
    ISBaseTimedAction.perform(self);
end

--- Hand an item to the player. sendAddItemToContainer does nothing on a
--- client, only on the server, which is where complete() runs in multiplayer.
function ISStripRefrigerator:give(inventory, itemType)
    local item = inventory:AddItem(itemType);
    if item then
        sendAddItemToContainer(inventory, item);
    end
end

-- Runs on the server in multiplayer and locally in single player. The server
-- owns inventories, so doing this in perform() only changed the client's copy:
-- the parts could not be used or dropped and the appliance never went away.
function ISStripRefrigerator:complete()
    local inventory = self.character:getInventory();
    local holder = self.item:getContainer() or inventory;

    self.character:removeFromHands(self.item);
    holder:Remove(self.item);
    sendRemoveItemFromContainer(holder, self.item);

    for _ = 1, self.quantity do
        self:give(inventory, "Base." .. self.newItemName);
        self:give(inventory, "Base.ElectronicsScrap");
    end
    for _ = 1, self.quantity * 2 do
        self:give(inventory, "Base.ScrapMetal");
    end

    return true;
end

function ISStripRefrigerator:getDuration()
    if self.character:isTimedActionInstant() then
        return 1;
    end
    return 1000;
end

-- Each argument must be stored under its own parameter name. The client packs
-- them for the server by reading those names back off the action.
function ISStripRefrigerator:new(character, item, newItemName, quantity)
    local o = ISBaseTimedAction.new(self, character);
    o.item = item;
    o.newItemName = newItemName;
    o.quantity = math.max(1, quantity);
    o.maxTime = o:getDuration();
    o.forceProgressBar = true;
    return o;
end
