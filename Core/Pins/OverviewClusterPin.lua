local _, STR = ...

STROverviewClusterPinMixin = CreateFromMixins(MapCanvasPinMixin)

function STROverviewClusterPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetScalingLimits(1, 1, 1)

    self.Display:SetIconShown(false)
    self.Count = self.Display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Count:SetPoint("CENTER")
end

function STROverviewClusterPinMixin:OnAcquired(members, x, y)
    self.members = members
    self.Count:SetText(#members)
    self:SetPosition(x, y)
end

function STROverviewClusterPinMixin:OnReleased()
    self:OnMouseLeave()
    self.members = nil
    MapCanvasPinMixin.OnReleased(self)
end

function STROverviewClusterPinMixin:OnClick(_)
end

function STROverviewClusterPinMixin:OnMouseEnter()
    self.HighlightTexture:Show()
    STR.GetMapController():OpenTooltipForOverviewCluster(self)
end

function STROverviewClusterPinMixin:OnMouseLeave()
    self.HighlightTexture:Hide()
    STR.GetMapController():CloseTooltip(self)
end

function STROverviewClusterPinMixin:ShouldMouseButtonBePassthrough(_)
    return false
end

-- Necessary because I override POIButtonTemplate's OnMouseEnter and OnMouseLeave.
function STROverviewClusterPinMixin:DisableInheritedMotionScriptsWarning()
    return true
end
