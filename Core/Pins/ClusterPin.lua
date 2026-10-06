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
    table.sort(members, function(a, b)
        -- Map last.
        if not a.questID then
            return false
        end
        -- Quest first.
        if not b.questID then
            return true
        end
        -- Ordered quests.
        return a.questID < b.questID
    end)

    self.members = members
    self.Count:SetText(#members)
    self:SetPosition(x, y)
    self:UpdateQuestHighlight(POIButtonHighlightManager:GetQuestID())
end

function STRClusterPinMixin:OnReleased()
    STR.GetMapController():CloseCluster(self)
    self:OnMouseLeave()
    self.members = nil
    MapCanvasPinMixin.OnReleased(self)
end

function STRClusterPinMixin:UpdateQuestHighlight(questID)
    for _, annotation in ipairs(self.members) do
        if questID and annotation.questID == questID then
            self.HighlightTexture:Show()
            self.LinkGlow:Show()
            return
        end
    end
    if not self:IsMouseOver() then
        self.HighlightTexture:Hide()
    end
    self.LinkGlow:Hide()
end

function STRClusterPinMixin:OnClick(button)
    if button == "LeftButton" then
        self:OnMouseLeave()
        STR.GetMapController():ToggleCluster(self)
    end
end

function STRClusterPinMixin:OnMouseEnter()
    self.HighlightTexture:Show()
    self.LinkGlow:Show()
    STR.GetMapController():OpenTooltipForCluster(self)
end

function STRClusterPinMixin:OnMouseLeave()
    self.HighlightTexture:Hide()
    self.LinkGlow:Hide()
    STR.GetMapController():CloseTooltip(self)
end

function STRClusterPinMixin:ShouldMouseButtonBePassthrough(_)
    return false
end

-- Necessary because I override POIButtonTemplate's OnMouseEnter and OnMouseLeave.
function STRClusterPinMixin:DisableInheritedMotionScriptsWarning()
    return true
end
