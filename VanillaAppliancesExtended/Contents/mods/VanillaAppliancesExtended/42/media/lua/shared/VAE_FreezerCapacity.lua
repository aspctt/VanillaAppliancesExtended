--[[
    Applies the FreezerCapacity sandbox option to chest freezers.

    Capacity lives in VanillaAppliancesExtended.tiles as ContainerCapacity, which
    is fixed at load time, so a sandbox option can only take effect by setting it
    on the container after the object exists. Doing it on LoadGridsquare means
    freezers built before the option changed pick up the new value too.

    The engine caps world containers at 100 regardless of what is set here.
]]

VAE = VAE or {}

VAE.MAX_CONTAINER_CAPACITY = 100        -- java inventory packet limit
VAE.DEFAULT_FREEZER_CAPACITY = 100

local SPRITE_PREFIX = "appliances_extended_01_"

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

--- Set the sandbox capacity on one object, if it is one of our freezers.
function VAE.applyFreezerCapacity(object)
    if not object then return end

    -- Cheapest gate first: most world objects have no container at all.
    local container = object:getContainer()
    if not container or container:getType() ~= "freezer" then return end

    local sprite = object:getSprite()
    local name = sprite and sprite:getName()
    if not name or not string.find(name, SPRITE_PREFIX, 1, true) then return end

    local capacity = VAE.getFreezerCapacity()
    if container:getCapacity() ~= capacity then
        container:setCapacity(capacity)
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
