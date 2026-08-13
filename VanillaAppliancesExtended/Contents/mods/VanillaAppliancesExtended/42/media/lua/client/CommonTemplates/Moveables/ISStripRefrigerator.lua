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

function ISStripRefrigerator:perform()
    self.container:Remove(self.item);
	for i=1,self.quantity do
		self.container:AddItem("Base." .. self.newItemName)
		self.container:AddItem("Base.ElectronicsScrap");
	end	
	for i=1,self.quantity*2 do
		self.container:AddItem("Base.ScrapMetal");
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
	o.quantity = math.max(1,quantity);
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
