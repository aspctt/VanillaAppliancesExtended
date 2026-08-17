--[[
    Applies the FreezerCapacity sandbox option to chest freezers.

    Capacity lives in VanillaAppliancesExtended.tiles as ContainerCapacity, which
    is fixed at load time, so a sandbox option can only take effect by setting it
    on the container after the object exists.

    Three entry points, because each covers a case the others miss:
      OnCreate       fires per tile as the entity is built, so a freezer is
                     correct immediately rather than only after a reload
      OnObjectAdded  objects appearing by other means
      LoadGridsquare freezers already standing in a save, so changing the
                     sandbox value reaches them

    The engine caps world containers at 100 regardless of what is set here.
]]

VAE = VAE or {}

VAE.MAX_CONTAINER_CAPACITY = 100        -- java inventory packet limit
VAE.DEFAULT_FREEZER_CAPACITY = 100

-- Only the chest freezer. The potbelly stove shares the tilesheet and must keep
-- its own small surface capacity, so match exact sprites rather than a prefix.
local FREEZER_SPRITES = {
    ["appliances_extended_01_4"] = true,
    ["appliances_extended_01_5"] = true,
    ["appliances_extended_01_6"] = true,
    ["appliances_extended_01_7"] = true,
    ["appliances_extended_01_12"] = true,
    ["appliances_extended_01_13"] = true,
    ["appliances_extended_01_14"] = true,
    ["appliances_extended_01_15"] = true,
}

function VAE.getFreezerCapacity()
    local sv = SandboxVars and SandboxVars.VanillaAppliancesExtended
    local capacity = sv and tonumber(sv.FreezerCapacity) or VAE.DEFAULT_FREEZER_CAPACITY
    capacity = math.floor(capacity)
    if capacity < 1 then capacity = 1 end
    if capacity > VAE.MAX_CONTAINER_CAPACITY then
        capacity = VAE.MAX_CONTAINER_CAPACITY
    end
    return capacity
end

--- Set the sandbox capacity on one object, if it is part of a chest freezer.
function VAE.applyFreezerCapacity(object)
    if not object then return end

    -- Cheapest gate first: most world objects have no container at all.
    local container = object:getContainer()
    if not container then return end

    local sprite = object:getSprite()
    local name = sprite and sprite:getName()
    if not name or not FREEZER_SPRITES[name] then return end

    local capacity = VAE.getFreezerCapacity()
    if container:getCapacity() ~= capacity then
        container:setCapacity(capacity)
    end
end

--- SpriteConfig OnCreate hook. Runs on the process that creates the object,
--- once per tile, after the container exists and before it is sent to clients.
function VAE_onFreezerBuilt(params)
    local thumpable = params and params.thumpable
    if thumpable then
        VAE.applyFreezerCapacity(thumpable)
    end
end

Events.OnObjectAdded.Add(VAE.applyFreezerCapacity)

Events.LoadGridsquare.Add(function(square)
    if not square then return end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        VAE.applyFreezerCapacity(objects:get(i))
    end
end)
