local _, STR = ...

STRDirectClusterPinMixin = CreateFromMixins(MapCanvasPinMixin)

function STRDirectClusterPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetScalingLimits(1, 1, 1)

    self.Display:SetIconShown(false)
    self.Count = self.Display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Count:SetPoint("CENTER")
end

function STRDirectClusterPinMixin:OnAcquired(members, x, y)
    self.members = members
    self.Count:SetText(#members)
    self:SetPosition(x, y)
end

function STRDirectClusterPinMixin:OnReleased()
    STR.GetMapController():CloseCluster(self)
    self:OnMouseLeave()
    self.members = nil
    MapCanvasPinMixin.OnReleased(self)
end

function STRDirectClusterPinMixin:OnClick(button)
    if button == "LeftButton" then
        self:OnMouseLeave()
        STR.GetMapController():ToggleCluster(self)
    end
end

function STRDirectClusterPinMixin:OnMouseEnter()
    self.HighlightTexture:Show()
    STR.GetMapController():OpenTooltipForDirectCluster(self)
end

function STRDirectClusterPinMixin:OnMouseLeave()
    self.HighlightTexture:Hide()
    STR.GetMapController():CloseTooltip(self)
end

function STRDirectClusterPinMixin:ShouldMouseButtonBePassthrough(_)
    return false
end

-- Necessary because I override POIButtonTemplate's OnMouseEnter and OnMouseLeave.
function STRDirectClusterPinMixin:DisableInheritedMotionScriptsWarning()
    return true
end
