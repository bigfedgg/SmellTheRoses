local _, STR = ...
local Local = {}

-- These maps have areas that cannot be annotated.
-- Key = Map with disallowed areas.
-- Val = Ancestor where the map is out of bounds.
-- TODO: Always check bounds and remove this table.
local mapsWithBoundsChecks = {
    [1414] = 947, -- Kalimdor -> Azeroth
    [1415] = 947, -- Eastern Kingdoms -> Azeroth
}

local projectionOverrides = {
    [1453] = {parentMapID = 1429, x = 0.3375, y = 0.5246}, -- Stormwind -> Elwynn Forest
    [1454] = {parentMapID = 1411, x = 0.4555, y = 0.1210}, -- Orgrimmar -> Durotar
    [1455] = {parentMapID = 1426, x = 0.5353, y = 0.3484}, -- Ironforge -> Dun Morogh
    [1456] = {parentMapID = 1412, x = 0.3981, y = 0.3589}, -- Thunder Bluff -> Mulgore
    [1457] = {parentMapID = 1438, x = 0.3064, y = 0.5538}, -- Darnassus -> Teldrassil
    [1458] = {parentMapID = 1420, x = 0.6191, y = 0.6599}, -- Undercity -> Tirisfal Glades
    [1459] = {parentMapID = 1424, x = 0.3884, y = 0.1418}, -- Alterac Valley -> Hillsbrad (Entrance)
    [1460] = {parentMapID = 1413, x = 0.4649, y = 0.0856}, -- Warsong Gulch -> Barrens (Entrance)
    [1461] = {parentMapID = 1417, x = 0.4626, y = 0.4400}, -- Arathi Basin -> Arathi Highlands (Entrance)
    [2521] = {parentMapID = 1414, x = 0.3243, y = 0.7223}, -- Zephras Isle -> West of Feralas
    [2524] = {parentMapID = 1413, x = 0.6340, y = 0.5860}, -- Darkspear Islands -> Northwatch Hold
}

function STR.ProjectAnnotations(annotations, targetMapID)
    local positions = {}
    for _, annotation in ipairs(annotations) do
        local x, y = annotation.x, annotation.y
        if annotation.mapID ~= targetMapID then
            x, y = STR.ProjectMapPosition(annotation.mapID, targetMapID,  x, y)
        end

        -- Current map can be completely unrelated to the annotation.
        -- We don't know it until we call ProjectMapPosition.
        if x ~= nil then
            table.insert(positions, { annotation = annotation, x = x, y = y })
        end
    end
    return positions
end

function STR.ProjectMapPosition(sourceMapID, targetMapID, x, y)
    if sourceMapID == targetMapID then
        return x, y
    end

    if not tContains(STR.GetMapAncestors(sourceMapID), targetMapID) then
        return
    end

    local override = projectionOverrides[sourceMapID]
    if override then
        return STR.ProjectMapPosition(override.parentMapID, targetMapID, override.x, override.y)
    end

    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(sourceMapID, targetMapID)
    return minX + x * (maxX - minX), minY + y * (maxY - minY)
end

function STR.GetMapAncestors(mapID)
    local ancestors = {}
    mapID = Local.GetParentMapID(mapID)

    while mapID ~= 0 do
        if C_Map.MapHasArt(mapID) then
            table.insert(ancestors, mapID)
        end
        mapID = Local.GetParentMapID(mapID)
    end

    return ancestors
end

function STR.CanAnnotateMapPosition(mapID, x, y)
    -- NOTE: Some areas cannot be annotated because they don't work well with
    -- multi-map annotations (I can't project them into an ancestor).
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

function STR.BuildPinLayout(positions, targetMapID, focusedQuestID)
    local layout = {
        annotationPins = {},
        directClusters = {},
        overviewClusters = {},
    }
    local directPositions = {}
    local projectedPositions = {}

    for _, position in ipairs(positions) do
        local annotation = position.annotation
        if annotation.mapID ~= targetMapID then
            table.insert(projectedPositions, position)
        elseif focusedQuestID and annotation.questID == focusedQuestID then
            table.insert(layout.annotationPins, position)
        else
            table.insert(directPositions, position)
        end
    end

    -- Keep annotations on the current map separate from projected annotations.
    -- Eventually for readability I would like to have generic "cluster predicates".
    local directClusters = STR.ClusterPositions(directPositions)
    local overviewClusters = STR.ClusterPositions(projectedPositions)

    for _, cluster in ipairs(directClusters) do
        if #cluster.members == 1 then
            table.insert(layout.annotationPins, {
                annotation = cluster.members[1], x = cluster.x, y = cluster.y,
            })
        else
            table.insert(layout.directClusters, cluster)
        end
    end
    for _, cluster in ipairs(overviewClusters) do
        if #cluster.members == 1 then
            table.insert(layout.annotationPins, {
                annotation = cluster.members[1], x = cluster.x, y = cluster.y,
            })
        else
            table.insert(layout.overviewClusters, cluster)
        end
    end

    return layout
end

function STR.ClusterPositions(positions)
    local clusters = {}
    local visited = {}
    local clusterRadius = 0.025
    local radiusSquared = clusterRadius * clusterRadius

    for seedIndex, seed in ipairs(positions) do
        if not visited[seedIndex] then
            visited[seedIndex] = true
            local pending = {seed}
            local members = {}
            local nextIndex = 1
            local sumX, sumY = 0, 0

            while nextIndex <= #pending do
                local position = pending[nextIndex]
                nextIndex = nextIndex + 1
                table.insert(members, position.annotation)
                sumX, sumY = sumX + position.x, sumY + position.y

                for candidateIndex, candidate in ipairs(positions) do
                    if not visited[candidateIndex] then
                        local dx = position.x - candidate.x
                        local dy = position.y - candidate.y
                        if dx * dx + dy * dy <= radiusSquared then
                            visited[candidateIndex] = true
                            table.insert(pending, candidate)
                        end
                    end
                end
            end

            table.insert(clusters, {
                members = members,
                x = sumX / #members,
                y = sumY / #members,
            })
        end
    end
    return clusters
end

function Local.GetParentMapID(mapID)
    local override = projectionOverrides[mapID]
    return override and override.parentMapID or C_Map.GetMapInfo(mapID).parentMapID
end