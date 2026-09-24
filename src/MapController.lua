local _, STR = ...

---@class STRMapController: MapCanvasDataProviderMixin
---@field focusedQuestID number?
local STRMapController = CreateFromMixins(MapCanvasDataProviderMixin)

function STR.GetMapController()
    return STRMapController
end

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

local function GetMapAncestors(mapID)
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

local function ProjectMapPosition(sourceMapID, targetMapID, x, y)
    if not tContains(GetMapAncestors(sourceMapID), targetMapID) then
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

local function CanAnnotateMapPosition(mapID, x, y)
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

function STRMapController:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)

    self.focusedQuestID = QuestMapFrame.DetailsFrame.questID

    map:RegisterCallback("SetFocusedQuestID", self.OnFocusedQuestChanged, self)
    map:RegisterCallback("ClearFocusedQuestID", self.OnFocusedQuestCleared, self)
end

function STRMapController:OnRemoved(map)
    self.focusedQuestID = nil

    map:UnregisterCallback("SetFocusedQuestID", self)
    map:UnregisterCallback("ClearFocusedQuestID", self)

    MapCanvasDataProviderMixin.OnRemoved(self, map)
end

function STRMapController:OnClick(canvas, button, x, y)
    if not STR.Loaded or button ~= "LeftButton" or not IsAltKeyDown() then
        return false
    end

    local openedMapID = canvas:GetMapID()
    if not CanAnnotateMapPosition(openedMapID, x, y) then
        return true
    end

    if self.focusedQuestID then
        STR.AddQuestAnnotation(self.focusedQuestID, openedMapID, x, y)
    else
        STR.AddMapAnnotation(openedMapID, x, y)
    end

    self:RefreshAllData()

    return true
end

function STRMapController:OnFocusedQuestChanged(questID)
    self.focusedQuestID = questID
    self:RefreshAllData()
end

function STRMapController:OnFocusedQuestCleared()
    self.focusedQuestID = nil
    self:RefreshAllData()
end

function STRMapController:RefreshAllData()
    if not STR.Loaded then
        return
    end

    self:RemoveAllData()

    if self.focusedQuestID then
        local annotatedMaps = STR.Data.QuestAnnotations[self.focusedQuestID]
        if annotatedMaps then
            for _, annotations in pairs(annotatedMaps) do
                self:ShowAnnotationsOnCurrentMap(annotations)
            end
        end
    else
        -- NOTE: Currently we only show annotations that are directly in the actual opened map.
        local openedMapID = self:GetMap():GetMapID()
        for _, maps in pairs(STR.Data.QuestAnnotations) do
            self:ShowAnnotationsOnCurrentMap(maps[openedMapID])
        end
        self:ShowAnnotationsOnCurrentMap(STR.Data.MapAnnotations[openedMapID])
    end
end

function STRMapController:ShowAnnotationsOnCurrentMap(annotations)
    if not annotations then
        return
    end

    local map = self:GetMap()
    local targetMapID = map:GetMapID()

    for _, annotation in ipairs(annotations) do
        local x, y = annotation.x, annotation.y
        if annotation.mapID ~= targetMapID then
            x, y = ProjectMapPosition(annotation.mapID, targetMapID, x, y)
        end
        -- Current map can be completely unrelated to the annotation.
        -- We don't know it until we call ProjectMapPosition.
        if x ~= nil then
            map:AcquirePin("STRMapPinTemplate", annotation, x, y)
        end
    end
end

function STRMapController:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("STRMapPinTemplate")
end

function STRMapController:ShowQuestAnnotations(questID)
    local mapID = self:GetSmallestCommonMapForQuest(questID)

    local map = self:GetMap()
    map:SetMapID(mapID)
    map:ResetZoom()
end

function STRMapController:GetSmallestCommonMapForQuest(questID)
    local questMapIDs = STR.Data.QuestAnnotations[questID]
    local someQuestMapID = next(questMapIDs)
    local someAncestorMapIDs = GetMapAncestors(someQuestMapID)
    table.insert(someAncestorMapIDs, 1, someQuestMapID)

    local commonAncestorIndex = 1
    for mapID in pairs(questMapIDs) do
        local otherAncestorMapIDs = GetMapAncestors(mapID)
        while someAncestorMapIDs[commonAncestorIndex] do
            local candidateMapID = someAncestorMapIDs[commonAncestorIndex]
            if candidateMapID == mapID or tContains(otherAncestorMapIDs, candidateMapID) then
                break
            end
            commonAncestorIndex = commonAncestorIndex + 1
        end
    end

    return someAncestorMapIDs[commonAncestorIndex]
end
