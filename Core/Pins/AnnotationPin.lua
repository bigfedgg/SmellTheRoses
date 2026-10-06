local _, STR = ...

local annotationIcons = {
    map = "worldquest-icon",
    quest = "Quest-In-Progress-Icon-yellow"
}

-- Not all pins are drawn on the map. Pins around clusters might be drawn outside.
-- This mixin centralises the functionality common to all annotation pins.
STRAnnotationButtonMixin = {}

function STRAnnotationButtonMixin:SetAnnotation(annotation)
    self.annotation = annotation
    self.Display:SetIconShown(true)
    self.Display:SetAtlas(nil, nil, annotationIcons[annotation.icon])
    self.GlobalFill:SetShown(annotation.isGlobal or false)
    self:UpdateQuestHighlight(POIButtonHighlightManager:GetQuestID())
end

function STRAnnotationButtonMixin:ClearAnnotation()
    STR.GetMapController():CloseNoteEditor(self)
    STR.GetMapController():CloseTooltip(self)
    self.annotation = nil
end

function STRAnnotationButtonMixin:GetQuestID()
    return self.annotation.questID
end

function STRAnnotationButtonMixin:UpdateQuestHighlight(questID)
    self:EvaluateManagedHighlight()
    self.LinkGlow:SetShown(questID ~= nil and self:GetQuestID() == questID)
end

function STRAnnotationButtonMixin:OnClick(button)
    -- Alt+Click to remove a pin.
    if button == "LeftButton" and IsAltKeyDown() then
        STR.GetMapController():DeleteAnnotation(self.annotation)
        return
    end

    -- Shift+Click to share a pin.
    if button == "LeftButton" and IsShiftKeyDown() then
        STR.ShareAnnotation(self.annotation)
        return
    end

    -- Click a pin to go to its map.
    -- If it's a quest pin also open its quest details.
    if button == "LeftButton" then
        STR.GetMapController():OpenAnnotation(self.annotation)
        return
    end

    -- Right click to edit a pin.
    if button == "RightButton" then
        self:OnMouseLeave()
        STR.GetMapController():OpenNoteEditor(self)
        return
    end
end

function STRAnnotationButtonMixin:OnMouseEnter()
    self.HighlightTexture:Show()
    self.LinkGlow:Show()
    STR.GetMapController():OpenTooltipForAnnotation(self)

    local questID = self:GetQuestID()
    if questID then
        POIButtonHighlightManager:SetHighlight(questID)
        EventRegistry:TriggerEvent("MapCanvas.QuestPin.OnEnter", self, questID)
    end
end

function STRAnnotationButtonMixin:OnMouseLeave()
    local questID = POIButtonHighlightManager:GetQuestID()
    if questID then
        POIButtonHighlightManager:ClearHighlight()
        EventRegistry:TriggerEvent("MapCanvas.QuestPin.OnLeave", questID)
    end

    self.HighlightTexture:Hide()
    self.LinkGlow:Hide()
    STR.GetMapController():CloseTooltip(self)
end

-- This mixin is specifically for annotation pins drawn on the map (i.e. STRMapAnnotationPinTemplate)
-- The other kind (STRClusterAnnotationPinTemplate) uses STRAnnotationButtonMixin directly.
STRMapAnnotationPinMixin = CreateFromMixins(MapCanvasPinMixin, STRAnnotationButtonMixin)

function STRMapAnnotationPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetScalingLimits(1, 1, 1)
    self:SetNumLoops(2)
    self.Expand:SetScale(0.65)
end

function STRMapAnnotationPinMixin:Clear()
    self.Expand:SetAlpha(0)
end

function STRMapAnnotationPinMixin:OnAcquired(annotation, x, y)
    self:SetAnnotation(annotation)
    self:SetPosition(x, y)
end

function STRMapAnnotationPinMixin:OnReleased()
    self:Stop()
    self:ClearAnnotation()
    MapCanvasPinMixin.OnReleased(self)
end

function STRMapAnnotationPinMixin:ShouldMouseButtonBePassthrough(_)
    return false
end

-- Necessary because I override POIButtonTemplate's OnMouseEnter and OnMouseLeave.
function STRMapAnnotationPinMixin:DisableInheritedMotionScriptsWarning()
    return true
end
