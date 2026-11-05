local _, STR = ...

-- Used by: STRQuestAnnotationPinTemplate and STRMapAnnotationPinTemplate.
STRAnnotationPinMixin = {}

function STRAnnotationPinMixin:OnLoad()
    self:SetDefaultMapPinScale()
end

function STRAnnotationPinMixin:OnAcquired(annotation, x, y)
    self.annotation = annotation
    self:SetPosition(x, y)
end

function STRAnnotationPinMixin:OnReleased()
    STR.PinTooltip:Close(self)
    self.annotation = nil
    MapCanvasPinMixin.OnReleased(self)
end

function STRAnnotationPinMixin:OnMouseClickAction(button)
    -- Alt+Click to remove a pin.
    if button == "LeftButton" and IsAltKeyDown() then
        STR.MapController:DeleteAnnotation(self.annotation)
        return
    end

    -- Shift+Click to share a pin.
    if button == "LeftButton" and IsShiftKeyDown() then
        STR.ShareAnnotation(self.annotation)
        return
    end

    -- Click a pin to go to its map.
    -- If it's a quest pin also super-track its quest.
    if button == "LeftButton" then
        if self:IsSelected() then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            C_SuperTrack.ClearAllSuperTracked()
        else
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            STR.MapController:OpenAnnotation(self.annotation)
        end
        return
    end

    -- Right click to edit a pin.
    if button == "RightButton" then
        STR.PinTooltip:Close(self)
        STR.OpenNoteEditor(self)
        return
    end
end

function STRAnnotationPinMixin:ShouldMouseButtonBePassthrough(_)
    return false
end

function STRAnnotationPinMixin:CheckMouseButtonPassthrough()
end

-- Used by: STRQuestAnnotationPinTemplate.
STRQuestAnnotationPinMixin = {}

function STRQuestAnnotationPinMixin:OnAcquired(annotation, x, y, frameLevelIndex)
    STRAnnotationPinMixin.OnAcquired(self, annotation, x, y)

    local questID = annotation.questID
    local isSuperTracked = questID == C_SuperTrack.GetSuperTrackedQuestID()
    if isSuperTracked then
        self:UseFrameLevelType("PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST")
    else
        self:UseFrameLevelType("PIN_FRAME_LEVEL_ACTIVE_QUEST", frameLevelIndex)
    end

    self:SetQuestID(questID)
    self:SetSelected(isSuperTracked)
    self:SetStyle(STR.Utils.GetQuestAnnotationStyle(annotation.isTurnIn))
    self:UpdateButtonStyle()
    self:UpdateHighlight()
end

function STRQuestAnnotationPinMixin:UpdateHighlight()
    local isHighlighted = self:GetQuestID() == STR.MapController:GetHighlightedQuestID()
    self.HighlightTexture:SetShown(isHighlighted)
    self.LinkGlow:SetShown(isHighlighted)
end

function STRQuestAnnotationPinMixin:OnMouseEnter()
    STR.PinTooltip:Open(self)
    STR.MapController:SetHoveredQuest(self:GetQuestID())
end

function STRQuestAnnotationPinMixin:OnMouseLeave()
    STR.PinTooltip:Close(self)
    STR.MapController:SetHoveredQuest(nil)
end

-- Used by: STRMapAnnotationPinTemplate.
STRMapAnnotationPinMixin = {}

function STRMapAnnotationPinMixin:OnLoad()
    STRAnnotationPinMixin.OnLoad(self)
    self:SetStyle(POIButtonUtil.Style.Waypoint)
    self:UpdateButtonStyle()
    STR.Utils.ApplyMapAnnotationIcon(self, "default")
end

function STRMapAnnotationPinMixin:OnAcquired(annotation, x, y)
    STRAnnotationPinMixin.OnAcquired(self, annotation, x, y)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_WAYPOINT_LOCATION")
    STR.Utils.ApplyMapAnnotationIcon(self, annotation.icon)
    self.GlobalFill:SetShown(annotation.isGlobal)
end

function STRMapAnnotationPinMixin:OnMouseDownAction()
    POIButtonMixin.OnMouseDown(self)
end

function STRMapAnnotationPinMixin:OnMouseUpAction()
    POIButtonMixin.OnMouseUp(self)
end

function STRMapAnnotationPinMixin:OnMouseEnter()
    POIButtonMixin.OnEnter(self)
    STR.PinTooltip:Open(self)
end

function STRMapAnnotationPinMixin:OnMouseLeave()
    POIButtonMixin.OnLeave(self)
    STR.PinTooltip:Close(self)
end

function STRMapAnnotationPinMixin:DisableInheritedMotionScriptsWarning()
    -- Necessary because I override POIButtonTemplate's OnEnter and OnLeave through OnMouseEnter and OnMouseLeave.
    return true
end

-- Used by: STRQuestIndicatorTemplate.
STRQuestIndicatorMixin = {}

function STRQuestIndicatorMixin:OnLoad()
    SmartNavigation_MarkFrameIgnored(self)
end

function STRQuestIndicatorMixin:Update(questID)
    self:SetQuestID(questID)
    self:SetSelected(questID == C_SuperTrack.GetSuperTrackedQuestID())
    self:SetStyle(STR.Utils.GetQuestAnnotationStyle(STR.Utils.IsQuestReadyToTurnIn(questID)))
    self:UpdateButtonStyle()
end

-- Used by: STRAnnotationPingTemplate.
STRAnnotationPingMixin = {}

function STRAnnotationPingMixin:CheckMouseButtonPassthrough()
end
