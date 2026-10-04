local _, STR = ...

STRClusterPinMixin = CreateFromMixins(MapCanvasPinMixin)

function STRClusterPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetScalingLimits(1, 1, 1)

    self.Display:SetIconShown(false)
    self.Count = self.Display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Count:SetPoint("CENTER")
end

function STRClusterPinMixin:OnAcquired(members, x, y)
    self.members = members
    self.Count:SetText(#members)
    self:SetPosition(x, y)
end

function STRClusterPinMixin:OnReleased()
    STR.GetMapController():CloseCluster(self)
    self:OnMouseLeave()
    self.members = nil
    MapCanvasPinMixin.OnReleased(self)
end

function STRClusterPinMixin:OnClick(button)
    if button == "LeftButton" then
        self:OnMouseLeave()
        STR.GetMapController():ToggleCluster(self)
    end
end

function STRClusterPinMixin:OnMouseEnter()
    self.HighlightTexture:Show()
    STR.GetMapController():OpenTooltipForCluster(self)
end

function STRClusterPinMixin:OnMouseLeave()
    self.HighlightTexture:Hide()
    STR.GetMapController():CloseTooltip(self)
end

function STRClusterPinMixin:ShouldMouseButtonBePassthrough(_)
    return false
end

-- Necessary because I override POIButtonTemplate's OnMouseEnter and OnMouseLeave.
function STRClusterPinMixin:DisableInheritedMotionScriptsWarning()
    return true
end
