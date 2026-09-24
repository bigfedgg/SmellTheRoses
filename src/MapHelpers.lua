local _, STR = ...

-- These maps are disallowed in annotations.
-- NOTE: They can eventually have projection overrides.
local disallowedMaps = {
    [1459] = true, -- Alterac Valley
    [1460] = true, -- Warsong Gulch
    [1461] = true, -- Arathi Basin
    [2524] = true, -- Darkspear Islands
}

-- These maps have areas that cannot be annotated.
-- Key = Map with disallowed areas.
-- Val = Ancestor where the map is out of bounds.
-- TODO: Always check bounds and remove this table.
local mapsWithBoundsChecks = {
    [1414] = 947, -- Kalimdor -> Azeroth
    [1415] = 947, -- Eastern Kingdoms -> Azeroth
}

local projectionOverrides = {
    [2521] = {
        [947] = {0.5, 0.5}, -- Zephras Isle -> Azeroth center
    },
}

function STR.GetMapAncestors(mapID)
    local ancestors = {}
    mapID = C_Map.GetMapInfo(mapID).parentMapID

    while mapID ~= 0 do
        if C_Map.MapHasArt(mapID) then
            table.insert(ancestors, mapID)
        end
        mapID = C_Map.GetMapInfo(mapID).parentMapID
    end

    return ancestors
end

function STR.ProjectMapPosition(sourceMapID, targetMapID, x, y)
    if not tContains(STR.GetMapAncestors(sourceMapID), targetMapID) then
        return
    end

    local sourceOverrides = projectionOverrides[sourceMapID]
    if sourceOverrides and sourceOverrides[targetMapID] then
        local position = sourceOverrides[targetMapID]
        return position[1], position[2]
    end

    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(sourceMapID, targetMapID)
    return minX + x * (maxX - minX), minY + y * (maxY - minY)
end

function STR.CanAnnotateMapPosition(mapID, x, y)
    -- NOTE: Some maps cannot be annotated because they don't work well with
    -- multi-map annotations (I can't project them into an ancestor). Mainly
    -- BGs and some out of bound areas in Eastern Kingdoms and Kalimdor.

    if disallowedMaps[mapID] then
        return false
    end

    local boundsCheckMapID = mapsWithBoundsChecks[mapID]
    if boundsCheckMapID then
        -- NOTE: This could reuse ProjectMapPosition and move the [0,1] check there.
        -- I'm leaving it for now and will revisit it once I generalise bounds checks.
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(mapID, boundsCheckMapID)
        x = minX + x * (maxX - minX)
        y = minY + y * (maxY - minY)
        return x >= 0 and x <= 1 and y >= 0 and y <= 1
    end

    return true
end
