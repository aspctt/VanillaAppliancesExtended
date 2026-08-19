require "TimedActions/ISBaseTimedAction"

ISStripRefrigerator = ISBaseTimedAction:derive("StripRefrigerator");

function ISStripRefrigerator:isValid()
    return true;
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

--- Hand an item to the player and tell the server about it.
function ISStripRefrigerator:give(inventory, itemType)
    local item = inventory:AddItem(itemType);
    if item then
        sendAddItemToContainer(inventory, item);
    end
end

function ISStripRefrigerator:perform()
    -- The server owns inventories in multiplayer, so every change has to be
    -- sent as well as applied locally. Without the send calls the appliance
    -- looks disassembled on the client and returns on the next sync, which is
    -- what this originally did.
    local inventory = self.character:getInventory();

    -- Remove from whichever container actually holds it, which is not always the
    -- player's main inventory. Outputs still go to the player, as before.
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

    ISBaseTimedAction.perform(self);
end

function ISStripRefrigerator:new(character, item, newItemName, quantity, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
    o.item = item;
    o.newItemName = newItemName;
    o.quantity = math.max(1, quantity);
    o.container = character:getInventory();
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.maxTime = time;
    if character:isTimedActionInstant() then
        o.maxTime = 1;
    end
    o.forceProgressBar = true;
    return o;
end
