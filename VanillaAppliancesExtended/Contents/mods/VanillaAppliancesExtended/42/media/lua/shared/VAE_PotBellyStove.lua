--[[
    Turns the built potbelly stove into a real fireplace.

    Entities are built as IsoThumpable, which has no burning or cooking
    behaviour whatever IsoType the tile declares. That is why the stove could be
    built but never lit: the tile said IsoFireplace, the object in the world was
    a thumpable.

    The base game hits the same problem with its own built wood oven and solves
    it by swapping the object out as it is created. This mirrors that, rather
    than calling BuildRecipeCode.barrelOven.OnCreate directly, so a rename on
    the vanilla side cannot silently break the stove.
]]

VAE = VAE or {}

--- SpriteConfig OnCreate hook. Replaces the freshly built thumpable with an
--- IsoFireplace on the same square, using the same sprite.
function VAE_onStoveBuilt(params)
    local thumpable = params and params.thumpable
    if not thumpable then return end

    local square = thumpable:getSquare()
    if not square then return end

    local sprite = thumpable:getSprite()
    if not sprite then return end

    local fireplace = IsoFireplace.new(getCell(), square, getSprite(sprite:getName()))
    square:AddTileObject(fireplace)

    if thumpable:getSquare() ~= nil then
        thumpable:removeFromWorld()
        thumpable:removeFromSquare()
        thumpable:setSquare(nil)
    end

    return { replaceObject = true, object = fireplace }
end
