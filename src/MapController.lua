local _, STR = ...

---@class STRMapController: MapCanvasDataProviderMixin
---@field focusedQuestID number?
local STRMapController = CreateFromMixins(MapCanvasDataProviderMixin)

function STR.GetMapController()
    return STRMapController
end

function STR.SetupMap()
    -- Hook the map controller to the WorldMapFrame.
    WorldMapFrame:AddDataProvider(STRMapController)
    WorldMapFrame:AddCanvasClickHandler(function(canvas, button, x, y)
        return STRMapController:OnClick(canvas, button, x, y)
    end)

    -- Setup map overview toggle.
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, rootDescription)
        local checkbox = rootDescription:CreateCheckbox(
                "Annotation Overview",
                function()
                    return STR.Data.Options.showOverview
                end,
                function()
                    STR.Data.Options.showOverview = not STR.Data.Options.showOverview
                    STRMapController:RefreshAllData()
                end)
        checkbox:SetTooltip(
                function(tooltip)
                    GameTooltip_SetTitle(tooltip, "Smell the Roses")
                    GameTooltip_AddNormalLine(tooltip, "Show annotations in parent maps.", true)
                end)
    end)
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
    if button ~= "LeftButton" or not IsAltKeyDown() then
        return false
    end

    local openedMapID = canvas:GetMapID()
    if not STR.CanAnnotateMapPosition(openedMapID, x, y) then
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

function STRMapController:ShowQuestAnnotations(questID)
    local mapID = self:GetSmallestCommonMapForQuest(questID)

    local map = self:GetMap()
    map:SetMapID(mapID)
    map:ResetZoom()
end

function STRMapController:GetSmallestCommonMapForQuest(questID)
    local questMapIDs = STR.Data.QuestAnnotations[questID]
    local someQuestMapID = next(questMapIDs)
    local someAncestorMapIDs = STR.GetMapAncestors(someQuestMapID)
    table.insert(someAncestorMapIDs, 1, someQuestMapID)

    local commonAncestorIndex = 1
    for mapID in pairs(questMapIDs) do
        local otherAncestorMapIDs = STR.GetMapAncestors(mapID)
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

function STRMapController:RefreshAllData()
    self:RemoveAllData()

    local map = self:GetMap()
    local projections = self:GetProjectedAnnotations()
    local clusters = {}

    if STR.Data.Options.showOverview and not self.focusedQuestID then
        projections, clusters = self:ClusterAnnotations(projections, map:GetMapID())
    end

    for _, projection in ipairs(projections) do
        map:AcquirePin("STRMapPinTemplate", {projection.annotation}, projection.x, projection.y)
    end
    for _, cluster in ipairs(clusters) do
        map:AcquirePin("STRMapPinTemplate", cluster.annotations, cluster.x, cluster.y)
    end
end

function STRMapController:GetProjectedAnnotations()
    local targetMapID = self:GetMap():GetMapID()
    local showOnParentMaps = self.focusedQuestID or STR.Data.Options.showOverview
    local sources = {}

    if self.focusedQuestID then
        local annotatedMaps = STR.Data.QuestAnnotations[self.focusedQuestID]
        if annotatedMaps then
            table.insert(sources, annotatedMaps)
        end
    else
        for _, maps in pairs(STR.Data.QuestAnnotations) do
            table.insert(sources, maps)
        end
        table.insert(sources, STR.Data.MapAnnotations)
    end

    local positions = {}
    for _, annotatedMaps in ipairs(sources) do
        for sourceMapID, annotations in pairs(annotatedMaps) do
            if sourceMapID == targetMapID or showOnParentMaps then
                for _, annotation in ipairs(annotations) do
                    local x, y = annotation.x, annotation.y
                    if sourceMapID ~= targetMapID then
                        x, y = STR.ProjectMapPosition(sourceMapID, targetMapID, x, y)
                    end
                    -- Current map can be completely unrelated to the annotation.
                    -- We don't know it until we call ProjectMapPosition.
                    if x ~= nil then
                        table.insert(positions, {annotation = annotation, x = x, y = y})
                    end
                end
            end
        end
    end

    return positions
end

function STRMapController:ClusterAnnotations(positions, targetMapID)
    -- Real positions are not clustered.
    local realPositions, projectedPositions, clusters = {}, {}, {}
    for _, position in ipairs(positions) do
        if position.annotation.mapID == targetMapID then
            table.insert(realPositions, position)
        else
            table.insert(projectedPositions, position)
        end
    end

    local clusterRadius = 0.025
    local visited = {}
    for index, position in ipairs(projectedPositions) do
        if not visited[index] then
            visited[index] = true
            local members = {position}
            local annotations = {}
            local sumX, sumY = 0, 0
            local memberIndex = 1

            while memberIndex <= #members do
                local member = members[memberIndex]
                table.insert(annotations, member.annotation)
                sumX, sumY = sumX + member.x, sumY + member.y
                for otherIndex, other in ipairs(projectedPositions) do
                    if not visited[otherIndex] then
                        local dx, dy = member.x - other.x, member.y - other.y
                        if dx * dx + dy * dy <= clusterRadius * clusterRadius then
                            visited[otherIndex] = true
                            table.insert(members, other)
                        end
                    end
                end
                memberIndex = memberIndex + 1
            end

            if #members == 1 then
                table.insert(realPositions, position)
            else
                table.insert(clusters, {
                    annotations = annotations,
                    x = sumX / #members,
                    y = sumY / #members
                })
            end
        end
    end

    return realPositions, clusters
end

function STRMapController:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("STRMapPinTemplate")
end
