local _, STR = ...
local Local = {}

local questPinTemplate = "STRQuestAnnotationPinTemplate"
local mapPinTemplate = "STRMapAnnotationPinTemplate"
local pingTemplate = "STRAnnotationPingTemplate"

local hoveredQuestID

---@class STRMapController: MapCanvasDataProviderMixin
local STRMapController = CreateFromMixins(MapCanvasDataProviderMixin)

STRMapController.poiQuantizer = CreateFromMixins(WorldMapPOIQuantizerMixin)
STRMapController.poiQuantizer.size = 75
STRMapController.poiQuantizer:OnLoad(75, 75)

STR.MapController = STRMapController

function STR.SetupMap()
    -- Hook the map controller to the WorldMapFrame.
    WorldMapFrame:AddDataProvider(STRMapController)
    WorldMapFrame:AddCanvasClickHandler(function(_, button, x, y)
        return STRMapController:OnCanvasClick(button, x, y)
    end)

    -- Setup map overview toggle.
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, rootDescription)
        local checkbox = rootDescription:CreateCheckbox(
                STR.L["MAP_FILTER_OVERVIEW_LABEL"],
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
                    GameTooltip_AddNormalLine(tooltip, STR.L["MAP_FILTER_OVERVIEW_TOOLTIP"], true)
                end)
    end)
end

function STRMapController:RefreshAllData()
    STR.CloseNoteEditor()

    self:RemoveAllData()

    local map = self:GetMap()
    local mapID = map:GetMapID()
    if not mapID or not STR.IsAddonEnabled() then
        return
    end

    local pins = {}
    local focusedQuestID = STR.GetFocusedQuestID()
    for _, annotation in ipairs(STR.GetAllAnnotations()) do
        local x, y = Local.GetAnnotationPositionOnMap(annotation, mapID, focusedQuestID)
        if x then
            local template = annotation.questID and questPinTemplate or mapPinTemplate
            table.insert(pins, map:AcquirePin(template, annotation, x, y))
        end
    end

    self.poiQuantizer:ClearAndQuantize(pins)
    for _, pin in ipairs(pins) do
        pin:SetPosition(pin.quantizedX or pin.normalizedX, pin.quantizedY or pin.normalizedY)
    end

    self:UpdatePings()
end

function STRMapController:RemoveAllData()
    local map = self:GetMap()
    map:RemoveAllPinsByTemplate(questPinTemplate)
    map:RemoveAllPinsByTemplate(mapPinTemplate)
end

function STRMapController:OpenAnnotation(annotation)
    local questID = annotation.questID
    local isFocused = questID and questID == STR.GetFocusedQuestID()
    if questID and not isFocused and C_QuestLog.IsOnQuest(questID) then
        if not QuestUtils_IsQuestWatched(questID) then
            C_QuestLog.AddQuestWatch(questID)
        end
        C_SuperTrack.SetSuperTrackedQuestID(questID)
    end

    C_Map.OpenWorldMap(annotation.mapID)

    if not isFocused then
        STR.CloseStickyQuestDetails()
    end
end

function STRMapController:DeleteAnnotation(annotation)
    STR.RemoveAnnotation(annotation)
    self:RefreshAllData()
    STR.UpdateQuestIndicators()
end

function STRMapController:ShowQuestAnnotations(questID)
    local annotations = STR.GetQuestAnnotations(questID)
    if not STR.IsAddonEnabled() or #annotations == 0 then
        return
    end

    C_Map.OpenWorldMap(STR.Utils.GetSmallestMapContaining(annotations))
    self:PingAnnotations(annotations)
end

function STRMapController:PingAnnotations(annotations)
    local map = self:GetMap()
    map:RemoveAllPinsByTemplate(pingTemplate)
    for _, annotation in ipairs(annotations) do
        local pin = self:GetAnnotationPin(annotation)
        if pin then
            local ping = map:AcquirePin(pingTemplate)
            ping:UseFrameLevelType("PIN_FRAME_LEVEL_QUEST_PING")
            ping:SetNumLoops(2)
            ping:SetID("annotation", annotation)
            ping:PlayAt(pin:GetPosition())
        end
    end
end

function STRMapController:UpdatePings()
    for ping in self:GetMap():EnumeratePinsByTemplate(pingTemplate) do
        if ping:IsActive() then
            local _, annotation = ping:GetID()
            local pin = self:GetAnnotationPin(annotation)
            if pin then
                ping:PlayAt(pin:GetPosition())
            else
                ping:Stop()
            end
        end
    end
end

function STRMapController:GetAnnotationPin(annotation)
    for _, template in ipairs({ questPinTemplate, mapPinTemplate }) do
        for pin in self:GetMap():EnumeratePinsByTemplate(template) do
            if pin.annotation == annotation then
                return pin
            end
        end
    end
end

function STRMapController:OnCanvasClick(button, x, y)
    if not STR.IsAddonEnabled() or button ~= "LeftButton" or not IsAltKeyDown() then
        return false
    end

    local mapID = self:GetMap():GetMapID()
    local mapInfo = C_Map.GetMapInfo(mapID)
    local questID = STR.GetFocusedQuestID()
    local title = questID and C_QuestLog.GetTitleForQuestID(questID) or mapInfo.name
    local annotation = { questID = questID, mapID = mapID, x = x, y = y, title = title }

    local errorKey
    if questID and not MapUtil.ShouldMapTypeShowQuests(mapInfo.mapType) then
        -- Quest annotations are restricted to maps that can actually show quest objectives.
        errorKey = "ERROR_INVALID_QUEST_MAP"
    elseif not STR.Utils.CanAnnotateMapPosition(annotation) then
        -- Some map positions can't be annotated. See CanAnnotateMapPosition.
        errorKey = "ERROR_INVALID_ANNOTATION"
    else
        errorKey = STR.AddAnnotation(annotation)
    end
    if errorKey then
        ChatFrameUtil.DisplaySystemMessageInPrimary(STR.L[errorKey])
        return true
    end

    self:RefreshAllData()
    STR.UpdateQuestIndicators()
    return true
end

function STRMapController:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)

    map:RegisterCallback("SetFocusedQuestID", self.RefreshAllData, self)
    map:RegisterCallback("ClearFocusedQuestID", self.RefreshAllData, self)
    EventRegistry:RegisterCallback("SetHighlightedQuestPOI", self.OnHighlightedQuestChanged, self)
    EventRegistry:RegisterCallback("ClearHighlightedQuestPOI", self.OnHighlightedQuestChanged, self)
    EventRegistry:RegisterCallback("Supertracking.OnChanged", self.RefreshAllData, self)
end

function STRMapController:OnRemoved(map)
    map:UnregisterCallback("SetFocusedQuestID", self)
    map:UnregisterCallback("ClearFocusedQuestID", self)
    EventRegistry:UnregisterCallback("SetHighlightedQuestPOI", self)
    EventRegistry:UnregisterCallback("ClearHighlightedQuestPOI", self)
    EventRegistry:UnregisterCallback("Supertracking.OnChanged", self)

    MapCanvasDataProviderMixin.OnRemoved(self, map)
end

function STRMapController:OnShow()
    self:RegisterEvent("QUEST_LOG_UPDATE")
    self:RegisterEvent("CVAR_UPDATE")
end

function STRMapController:OnHide()
    self:UnregisterEvent("QUEST_LOG_UPDATE")
    self:UnregisterEvent("CVAR_UPDATE")
    STR.PinTooltip:Close()
end

function STRMapController:OnEvent(event, cvar)
    if event == "QUEST_LOG_UPDATE" or (event == "CVAR_UPDATE" and cvar == "questPOI") then
        self:RefreshAllData()
    end
end

function STRMapController:OnCanvasSizeChanged()
    local map = self:GetMap()
    local ratio = map:DenormalizeHorizontalSize(1.0) / map:DenormalizeVerticalSize(1.0)
    self.poiQuantizer:Resize(math.ceil(self.poiQuantizer.size * ratio), self.poiQuantizer.size)
end

function STRMapController:SetHoveredQuest(questID)
    hoveredQuestID = questID
    self:OnHighlightedQuestChanged()
    STR.UpdateQuestIndicators()
end

function STRMapController:GetHoveredQuestID()
    return hoveredQuestID
end

function STRMapController:GetHighlightedQuestID()
    return hoveredQuestID or POIButtonHighlightManager:GetQuestID()
end

function STRMapController:OnHighlightedQuestChanged()
    for pin in self:GetMap():EnumeratePinsByTemplate(questPinTemplate) do
        pin:UpdateHighlight()
    end
end

function Local.GetAnnotationPositionOnMap(annotation, mapID, focusedQuestID)
    local questID = annotation.questID

    -- If a quest is focused, only its own annotations are shown.
    -- Focused quests have no limitations on which maps they show.
    if focusedQuestID then
        if questID ~= focusedQuestID then
            return
        end
        return STR.Utils.GetPositionOnMap(annotation, mapID)
    end

    -- The map has to be able to show the annotation.
    if not Local.CanShowAnnotationOnMap(annotation, mapID) then
        return
    end

    if questID and C_QuestLog.IsOnQuest(questID) then
        local questIsReadyToTurnIn = STR.Utils.IsQuestReadyToTurnIn(questID)

        -- If a quest is not completed, turn-in annotations are hidden.
        if annotation.isTurnIn and not questIsReadyToTurnIn then
            return
        end

        -- If a quest is completed, only turn-in annotations are shown.
        if not annotation.isTurnIn and questIsReadyToTurnIn then
            return
        end
    end

    return STR.Utils.GetPositionOnMap(annotation, mapID)
end

function Local.CanShowAnnotationOnMap(annotation, mapID)
    local mapType = C_Map.GetMapInfo(mapID).mapType
    local annotationMapType = C_Map.GetMapInfo(annotation.mapID).mapType

    -- If the map is at least a zone, then it can show any annotation in a higher map type.
    -- e.g. a zone map can show a zone or dungeon annotation.
    if mapType >= Enum.UIMapType.Zone and annotationMapType >= mapType then
        return true
    end

    -- Any map can show its own annotations.
    if annotation.mapID == mapID then
        return true
    end

    -- Continent maps can show super-tracked quest annotations.
    if annotation.questID and annotation.questID == C_SuperTrack.GetSuperTrackedQuestID() and mapType == Enum.UIMapType.Continent then
        return true
    end

    -- Map annotations are always shown if overview is enabled.
    return not annotation.questID and STR.Data.Options.showOverview
end
