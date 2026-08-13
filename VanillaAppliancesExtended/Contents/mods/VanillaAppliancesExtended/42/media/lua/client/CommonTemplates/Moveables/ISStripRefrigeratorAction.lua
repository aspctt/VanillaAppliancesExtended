local iceboxAppliance = {}

local minifridgeAppliance = {}

minifridgeAppliance["appliances_refrigeration_01_24"] = { "RefrigerationComponents" }
minifridgeAppliance["appliances_refrigeration_01_25"] = { "RefrigerationComponents" }
minifridgeAppliance["appliances_refrigeration_01_26"] = { "RefrigerationComponents" }
minifridgeAppliance["appliances_refrigeration_01_27"] = { "RefrigerationComponents" }

iceboxAppliance["appliances_refrigeration_01_0"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_1"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_2"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_3"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_4"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_5"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_6"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_7"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_8"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_9"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_10"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_11"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_12"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_13"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_14"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_15"] = {"RefrigerationComponents"}

iceboxAppliance["appliances_refrigeration_01_22"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_23"] = {"RefrigerationComponents"}

iceboxAppliance["appliances_refrigeration_01_28"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_29"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_30"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_31"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_32"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_33"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_34"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_35"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_36"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_37"] = {"RefrigerationComponents"}

iceboxAppliance["appliances_refrigeration_01_40"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_41"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_42"] = {"RefrigerationComponents"}
iceboxAppliance["appliances_refrigeration_01_43"] = {"RefrigerationComponents"}

-- mini fridge
iceboxAppliance["appliances_refrigeration_01_24"] = { "RefrigerationComponents" }
iceboxAppliance["appliances_refrigeration_01_25"] = { "RefrigerationComponents" }
iceboxAppliance["appliances_refrigeration_01_26"] = { "RefrigerationComponents" }
iceboxAppliance["appliances_refrigeration_01_27"] = { "RefrigerationComponents" }

ISInventoryMenuElements = ISInventoryMenuElements or {};

function ISInventoryMenuElements.VAEContextMovable()
    local self 					= ISMenuElement.new();
    self.invMenu			    = ISContextManager.getInstance().getInventoryMenu();

    function self.init()
    end

    function self.createMenu( _item )
        if instanceof(_item, "Moveable") then
            if _item:getContainer() ~= self.invMenu.inventory then
                return;
            end
			
			local playerInv = self.invMenu.player:getInventory()
            if self.invMenu.player:getPrimaryHandItem() ~= _item and self.invMenu.player:getSecondaryHandItem() ~= _item then
				if iceboxAppliance[_item:getWorldSprite()] then
                    for _, newItemName in ipairs(iceboxAppliance[_item:getWorldSprite()]) do
                        local option = self.invMenu.context:addOption("Disassemble ".._item:getName(), self.invMenu, self.createItem, _item, newItemName);

						local toolTip = ISToolTip:new();
						toolTip:initialise();
						toolTip:setVisible(false);
						
						-- add it to our current option
						option.toolTip = toolTip;
						toolTip:setName("Disassemble ".._item:getName());
						toolTip.description = "Recovers components for making refrigeration devices but destroys the object.";
						
						if not playerInv:contains("Screwdriver") then
							toolTip.description = toolTip.description .. " <LINE><RGB:1,0,0>Requires a Screwdriver";
							option.notAvailable = true;
						end
						
						if self.invMenu.player:getXp():getXP(Perks.Electricity) < 3 then
							toolTip.description = toolTip.description .. " <LINE><RGB:1,0,0>Requires Electrical 3";
							option.notAvailable = true;
						end
                    end
                end              
            end
        end
    end

    function self.createItem( _p, _item, newItemName )
		if minifridgeAppliance[_item:getWorldSprite()] then
			ISTimedActionQueue.add(ISStripRefrigerator:new(_p.player, _item, newItemName, 1, 1000))
		else
			local rand = ZombRand(0, 2) + 1
			ISTimedActionQueue.add(ISStripRefrigerator:new(_p.player, _item, newItemName, rand, 1000))
		end
    end
    return self;
end

