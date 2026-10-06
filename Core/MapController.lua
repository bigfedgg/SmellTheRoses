local _, STR = ...

---@class STRMapController: MapCanvasDataProviderMixin
---@field focusedQuestID number?
local STRMapController = CreateFromMixins(MapCanvasDataProviderMixin)

function STR.GetMapController()
    return STRMapController
end

function STR.SetupMap()
    -- Create reusable components: pin tooltip, note editor, cluster popup
    STRMapController.pinTooltip = STR.CreatePinTooltip()
    STRMapController.noteEditor = STR.CreateNoteEditor()
    STRMapController.clusterPopup = STR.CreateClusterPopup()

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

function STRMapController:RefreshAllData()
    self:RemoveAllData()

    if not STR.IsAddonEnabled() then
        return
    end

    local map = self:GetMap()
    local mapID = map:GetMapID()

    local annotations = STR.SelectAnnotationsToDisplay(mapID, self.focusedQuestID)
    local positions = STR.ProjectAnnotations(annotations, mapID)
    local layout = STR.BuildPinLayout(positions, mapID, self.focusedQuestID)

    for _, position in ipairs(layout.annotationPins) do
        map:AcquirePin("STRMapAnnotationPinTemplate", position.annotation, position.x, position.y)
    end
    for _, cluster in ipairs(layout.directClusters) do
        map:AcquirePin("STRDirectClusterPinTemplate", cluster.members, cluster.x, cluster.y)
    end
    for _, cluster in ipairs(layout.overviewClusters) do
        map:AcquirePin("STROverviewClusterPinTemplate", cluster.members, cluster.x, cluster.y)
    end
end

function STRMapController:OpenAnnotation(annotation)
    self.clusterPopup:Close()
    OpenWorldMap()

    if annotation.questID and C_QuestLog.IsOnQuest(annotation.questID) then
        STR.OpenQuestFromPin(annotation.questID)
    else
        QuestMapFrame_CloseQuestDetails()
    end

    local map = self:GetMap()
    if map:GetMapID() ~= annotation.mapID then
        map:SetMapID(annotation.mapID)
    end
    map:ResetZoom()
end

function STRMapController:DeleteAnnotation(annotation)
    if annotation.questID then
        STR.RemoveQuestAnnotation(annotation)
    else
        STR.RemoveMapAnnotation(annotation)
    end

    self:RefreshAllData()
end

function STRMapController:OpenNoteEditor(pin)
    self.noteEditor:Open(pin)
end

function STRMapController:CloseNoteEditor(pin)
    self.noteEditor:CloseForPin(pin)
end

function STRMapController:OpenTooltipForAnnotation(pin)
    self.pinTooltip:OpenForAnnotation(pin)
end

function STRMapController:OpenTooltipForCluster(cluster)
    self.pinTooltip:OpenForCluster(cluster)
end

function STRMapController:CloseTooltip(pin)
    self.pinTooltip:Close(pin)
end

function STRMapController:ToggleCluster(cluster)
    self.clusterPopup:Toggle(cluster)
end

function STRMapController:CloseCluster(cluster)
    self.clusterPopup:CloseForCluster(cluster)
end

function STRMapController:OpenMapForQuest(questID)
    if not STR.IsAddonEnabled() then
        return
    end

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

function STRMapController:OnClick(canvas, button, x, y)
    if not STR.IsAddonEnabled() or button ~= "LeftButton" or not IsAltKeyDown() then
        return false
    end

    local openedMapID, error = canvas:GetMapID(), nil
    if self.focusedQuestID then
        error = STR.AddQuestAnnotation(self.focusedQuestID, openedMapID, x, y)
    else
        error = STR.AddMapAnnotation(openedMapID, x, y)
    end

    if error == "invalid" then
        ChatFrameUtil.DisplaySystemMessageInPrimary("The annotation is not valid.")
        return true
    elseif error == "duplicate" then
        ChatFrameUtil.DisplaySystemMessageInPrimary("The annotation already exists.")
        return true
    end

    self:RefreshAllData()
    return true
end

function STRMapController:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)

    self.focusedQuestID = QuestMapFrame.DetailsFrame.questID

    map:RegisterCallback("SetFocusedQuestID", self.OnFocusedQuestChanged, self)
    map:RegisterCallback("ClearFocusedQuestID", self.OnFocusedQuestCleared, self)
    EventRegistry:RegisterCallback("SetHighlightedQuestPOI", self.OnHighlightedQuestChanged, self)
    EventRegistry:RegisterCallback("ClearHighlightedQuestPOI", self.OnHighlightedQuestChanged, self)
end

function STRMapController:OnRemoved(map)
    self.focusedQuestID = nil

    map:UnregisterCallback("SetFocusedQuestID", self)
    map:UnregisterCallback("ClearFocusedQuestID", self)
    EventRegistry:UnregisterCallback("SetHighlightedQuestPOI", self)
    EventRegistry:UnregisterCallback("ClearHighlightedQuestPOI", self)

    MapCanvasDataProviderMixin.OnRemoved(self, map)
end

function STRMapController:OnHide()
    self.clusterPopup:Close()
    self.pinTooltip:CloseAll()
    self.noteEditor:Close()
end

-- NOTE: Not closing the cluster when the canvas changes causes some weird behaviour.
-- Mostly the expanded cluster going outside of the map and clipping other elements.
function STRMapController:OnCanvasPanChanged()
    self.clusterPopup:Close()
end

function STRMapController:OnCanvasScaleChanged()
    self.clusterPopup:Close()
end

function STRMapController:OnCanvasSizeChanged()
    self.clusterPopup:Close()
end

function STRMapController:OnFocusedQuestChanged(questID)
    self.focusedQuestID = questID
    self:RefreshAllData()
end

function STRMapController:OnFocusedQuestCleared()
    self.focusedQuestID = nil
    self:RefreshAllData()
end

function STRMapController:OnHighlightedQuestChanged()
    local highlightedQuestID = POIButtonHighlightManager:GetQuestID()
    local map = self:GetMap()

    for _, template in ipairs({
        "STRMapAnnotationPinTemplate",
        "STRDirectClusterPinTemplate",
        "STROverviewClusterPinTemplate"
    }) do
        for pin in map:EnumeratePinsByTemplate(template) do
            pin:UpdateQuestHighlight(highlightedQuestID)
        end
    end

    for button in self.clusterPopup.buttons:EnumerateActive() do
        button:UpdateQuestHighlight(highlightedQuestID)
    end

    for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
        if button.STRAnnotationIndicator then
            button.STRAnnotationIndicator.HighlightTexture:SetShown(button.questID == highlightedQuestID)
        end
    end
end

function STRMapController:RemoveAllData()
    local map = self:GetMap()
    map:RemoveAllPinsByTemplate("STRMapAnnotationPinTemplate")
    map:RemoveAllPinsByTemplate("STRDirectClusterPinTemplate")
    map:RemoveAllPinsByTemplate("STROverviewClusterPinTemplate")
end
