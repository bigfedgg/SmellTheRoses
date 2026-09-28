local _, STR = ...

local PinTooltip = {}
local textWidth = 280

function STR.CreatePinTooltip()
    local tooltip = CreateFromMixins(PinTooltip)
    tooltip.frame = CreateFrame("GameTooltip", "STRAnnotationTooltip", UIParent, "GameTooltipTemplate")
    tooltip.separators = CreateTexturePool(tooltip.frame, "ARTWORK")
    return tooltip
end

function PinTooltip:OpenForAnnotation(pin)
    self:Begin(pin)
    self:AddEntry(pin.annotation, 0)
    self:AddText(" ", NORMAL_FONT_COLOR)
    self:AddText("<Right click to edit annotation>", GREEN_FONT_COLOR)
    self:AddText("<Alt click to remove annotation>", GREEN_FONT_COLOR)
    self:Finish()
end

function PinTooltip:OpenForDirectCluster(cluster)
    self:Begin(cluster)
    self:AddEntries(cluster.members)
    self:AddText(" ", NORMAL_FONT_COLOR)
    self:AddText("<Click to expand annotations>", GREEN_FONT_COLOR)
    self:Finish()
end

function PinTooltip:OpenForOverviewCluster(cluster)
    self:Begin(cluster)
    self:AddEntries(cluster.members)
    self:Finish()
end

function PinTooltip:CloseAll()
    self.frame:Hide()
end

function PinTooltip:Close(owner)
    if self.frame:GetOwner() == owner then
        self.frame:Hide()
    end
end

function PinTooltip:Begin(owner)
    self.frame:SetOwner(owner, "ANCHOR_RIGHT")
    self.frame:ClearLines()
    self.separators:ReleaseAll()
    self.rightPadding = 0
end

function PinTooltip:AddEntries(members)
    for index, annotation in ipairs(members) do
        if index > 1 then
            self:AddSeparator()
        end
        self:AddEntry(annotation, 2)
    end
end

function PinTooltip:AddEntry(annotation, noteLines)
    local title
    if annotation.questID then
        title = annotation.questTitle
    else
        title = C_Map.GetMapInfo(annotation.mapID).name
    end
    self:AddText(title, HIGHLIGHT_FONT_COLOR, GameTooltipHeaderText)

    if annotation.note then
        local line = self:AddText(annotation.note, NORMAL_FONT_COLOR, GameTooltipText, noteLines)
        if noteLines > 0 then
            self.rightPadding = math.max(self.rightPadding, line:GetUnboundedStringWidthForText("..."))
        end
    end
end

function PinTooltip:AddSeparator()
    local line = self:AddText(" ", NORMAL_FONT_COLOR)
    local separator = self.separators:Acquire()
    separator:SetColorTexture(1, 1, 1, 0.35)
    separator:SetHeight(PixelUtil.GetPixelToUIUnitFactor() / separator:GetEffectiveScale())
    separator:SetRoundLayoutToNearestPixel(true)
    separator:SetPoint("LEFT", self.frame, "LEFT", 4, 0)
    separator:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
    separator:SetPoint("TOP", line, "CENTER")
    separator:Show()
end

function PinTooltip:AddText(text, color, font, maxLines)
    GameTooltip_AddColoredLine(self.frame, text, color, true)
    local line = self.frame:GetLeftLine(self.frame:NumLines())
    line:SetFontObject(font or GameTooltipText)
    line:SetTextColor(color:GetRGB())
    line:SetWidth(textWidth)
    line:SetMaxLines(maxLines or 0)
    return line
end

function PinTooltip:Finish()
    self.frame:Show()
    self.frame:SetPadding(self.rightPadding, 0)
end
