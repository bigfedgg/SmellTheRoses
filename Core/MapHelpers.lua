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
        [947] = {0.08, 0.66}, -- Zephras Isle -> West of Feralas
    },
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

function STR.BuildPinLayout(positions, targetMapID, focusedQuestID)
    local layout = {
        annotationPins = {},
        directClusters = {},
        overviewClusters = {},
    }
    local unfocusedQuestPositions = {}
    local projectedPositions = {}

    for _, position in ipairs(positions) do
        local annotation = position.annotation
        if annotation.mapID ~= targetMapID then
            table.insert(projectedPositions, position)
        elseif not annotation.questID or annotation.questID == focusedQuestID then
            table.insert(layout.annotationPins, position)
        else
            table.insert(unfocusedQuestPositions, position)
        end
    end

    -- Separate overview clusters (non-interactive) from base map clusters (interactive).
    -- Eventually for readability I would like to have generic "cluster predicates".
    local directClusters = STR.ClusterPositions(unfocusedQuestPositions)
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
