local _, STR = ...

local Utils = {}
STR.Utils = Utils

local worldMapID = C_Map.GetFallbackWorldMapID()

local projectionOverrides = {
    [1459] = { parentMapID = 1424, x = 0.3884, y = 0.1418 }, -- Alterac Valley -> Hillsbrad (Entrance)
    [1460] = { parentMapID = 1413, x = 0.4649, y = 0.0856 }, -- Warsong Gulch -> Barrens (Entrance)
    [1461] = { parentMapID = 1417, x = 0.4626, y = 0.4400 }, -- Arathi Basin -> Arathi Highlands (Entrance)
    [2521] = { parentMapID = 1414, x = 0.3243, y = 0.7223 }, -- Zephras Isle -> West of Feralas
    [2524] = { parentMapID = 1413, x = 0.6340, y = 0.5860 }, -- Darkspear Islands -> Northwatch Hold
}

function Utils.CanAnnotateMapPosition(annotation)
    return Utils.GetPositionOnMap(annotation, worldMapID) ~= nil
end

function Utils.GetSmallestMapContaining(annotations)
    local candidateMapIDs = {}

    -- The annotation's map itself is an candidate.
    for _, annotation in ipairs(annotations) do
        table.insert(candidateMapIDs, annotation.mapID)
    end

    -- Every map in the parent chain is a candidate.
    for _, annotation in ipairs(annotations) do
        local mapID = C_Map.GetMapInfo(annotation.mapID).parentMapID
        while mapID ~= 0 do
            if C_Map.MapHasArt(mapID) then
                table.insert(candidateMapIDs, mapID)
            end
            mapID = C_Map.GetMapInfo(mapID).parentMapID
        end
    end

    -- The containing map is the first one that can display all annotations.
    for _, mapID in ipairs(candidateMapIDs) do
        local isContainingMap = not ContainsIf(annotations, function(annotation)
            return not Utils.GetPositionOnMap(annotation, mapID)
        end)
        if isContainingMap then
            return mapID
        end
    end
end

function Utils.GetPositionOnMap(annotation, mapID)
    -- Some maps have no world position, so we fallback to our custom projection overrides.
    local sourceMapID, x, y = annotation.mapID, annotation.x, annotation.y
    local override = projectionOverrides[sourceMapID]
    if sourceMapID ~= mapID and override then
        sourceMapID, x, y = override.parentMapID, override.x, override.y
    end

    -- Same map, nothing to do.
    if sourceMapID == mapID then
        return x, y
    end

    -- We project the annotation position into a continent and then back into the target map.
    -- This gives us neighboring map positions for free (e.g. Stormwind on Elwynn Forest).
    local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(sourceMapID, CreateVector2D(x, y))
    if continentID then
        local _, mapPosition = C_Map.GetMapPosFromWorldPos(continentID, worldPosition, mapID)
        if mapPosition then
            local mapX, mapY = mapPosition:GetXY()
            if mapX >= 0 and mapX <= 1 and mapY >= 0 and mapY <= 1 then
                return mapX, mapY
            end
        end
    end

    -- The world map itself spans several continents, so world positions can't be placed on it ironically.
    if mapID == worldMapID then
        local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(sourceMapID, worldMapID)
        x, y = minX + x * (maxX - minX), minY + y * (maxY - minY)
        if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            return x, y
        end
    end
end

function Utils.IsQuestReadyToTurnIn(questID)
    if not C_QuestLog.IsComplete(questID) then
        return false
    end

    local questAnnotations = STR.GetQuestAnnotations(questID)
    return ContainsIf(questAnnotations, function(annotation)
        return annotation.isTurnIn
    end)
end

function Utils.GetQuestAnnotationStyle(isTurnIn)
    return isTurnIn and POIButtonUtil.Style.QuestComplete or POIButtonUtil.Style.QuestInProgress
end

function Utils.EscapeText(text)
    if not text then
        return ""
    end
    return (text:gsub("[%c%%|{}]", function(character)
        return ("%%%02X"):format(character:byte())
    end)):gsub(":", "%%3A")
end

STR.MapAnnotationIcons = {
    default = { atlas = "worldquest-icon" },
    npc = { atlas = "squad_size_solo", size = 16, color = { 1, 0.82, 0 } },
    skull = { atlas = "GM-raidMarker1", size = 14 },
    chest = { atlas = "VignetteLoot", size = 14 },
    resource = { atlas = "Professions_Tracking_Ore", size = 14 },
    vendor = { atlas = "Banker", size = 14 },
    magnifying = { atlas = "loreobject-32x32", size = 14 },
    flag = { atlas = "friends-icon-recentAlly", size = 14 },
}

function Utils.ApplyMapAnnotationIcon(button, iconName)
    local icon = STR.MapAnnotationIcons[iconName] or STR.MapAnnotationIcons.default
    button.Display:SetAtlas(icon.size, icon.size, icon.atlas)
    if icon.color then
        button.Display.Icon:SetVertexColor(unpack(icon.color))
    else
        button.Display.Icon:SetVertexColor(1, 1, 1)
    end
end