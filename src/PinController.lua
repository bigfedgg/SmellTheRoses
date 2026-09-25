local _, STR = ...

local annotationIcons = {
    map = "worldquest-icon",
    quest = "Quest-In-Progress-Icon-yellow"
}

local annotationTooltip
local separatorPool
local tooltipTextWidth = 280

function STR.SetupPins()
    annotationTooltip = CreateFrame("GameTooltip", "STRAnnotationTooltip", UIParent, "GameTooltipTemplate")
    separatorPool = CreateTexturePool(annotationTooltip, "ARTWORK")
end

local function GetAnnotationTitle(annotation)
    if annotation.questID then
        return annotation.questTitle
    end
    return C_Map.GetMapInfo(annotation.mapID).name
end

local function AddTooltipLine(text, color, maxLines, fontObject)
    GameTooltip_AddColoredLine(annotationTooltip, text, color, true)
    local line = annotationTooltip:GetLeftLine(annotationTooltip:NumLines())
    line:SetFontObject(fontObject or GameTooltipText)
    line:SetTextColor(color:GetRGB())
    line:SetWidth(tooltipTextWidth)
    line:SetMaxLines(maxLines)
    return line
end

STRMapPinController = CreateFromMixins(MapCanvasPinMixin)

function STRMapPinController:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetScalingLimits(1, 1, 1)
    self.Count = self.Display:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Count:SetPoint("CENTER")
end

function STRMapPinController:OnAcquired(annotations, x, y)
    self.annotations = annotations

    if #annotations > 1 then
        self.Count:SetShown(true)
        self.Count:SetText(#annotations)
        self.Display:SetIconShown(false)
    else
        self.Count:SetShown(false)
        self.Display:SetIconShown(true)
        self.Display:SetAtlas(nil, nil, annotationIcons[annotations[1].icon])
    end

    self:SetPosition(x, y)
end

function STRMapPinController:OnReleased()
    STR.CloseEditorFrameForPin(self)
    MapCanvasPinMixin.OnReleased(self)
    self.annotations = nil
    self:OnMouseLeave()
end

function STRMapPinController:OnClick(button)
    if #self.annotations > 1 then
        return
    end

    local annotation = self.annotations[1]

    -- Alt+Click to remove a pin.
    if button == "LeftButton" and IsAltKeyDown() then
        if annotation.questID then
            STR.RemoveQuestAnnotation(annotation)
        else
            STR.RemoveMapAnnotation(annotation)
        end

        self:GetMap():RemovePin(self)
        return
    end

    -- Click a pin to go to its map.
    -- If it's a quest pin also open its quest details.
    if button == "LeftButton" then
        local map = self:GetMap()
        if annotation.questID and C_QuestLog.IsOnQuest(annotation.questID) then
            STR.OpenQuestFromPin(annotation.questID)
        end
        if map:GetMapID() ~= annotation.mapID then
            map:SetMapID(annotation.mapID)
            map:ResetZoom()
        end
        return
    end

    -- Right click to edit a pin.
    if button == "RightButton" then
        self:OnMouseLeave()
        STR.OpenEditorFrameForPin(self)
        return
    end
end

function STRMapPinController:OnMouseEnter()
    self.HighlightTexture:Show()
    annotationTooltip:SetOwner(self, "ANCHOR_RIGHT")
    annotationTooltip:ClearLines()
    separatorPool:ReleaseAll()

    local clustered = #self.annotations > 1
    local ellipsisPadding = 0
    for index, annotation in ipairs(self.annotations) do
        if index > 1 then
            local line = AddTooltipLine(" ", NORMAL_FONT_COLOR, 0)
            local separator = separatorPool:Acquire()
            separator:SetColorTexture(1, 1, 1, 0.35)
            separator:SetHeight(PixelUtil.GetPixelToUIUnitFactor() / separator:GetEffectiveScale())
            separator:SetRoundLayoutToNearestPixel(true)
            separator:SetPoint("LEFT", annotationTooltip, "LEFT", 4, 0)
            separator:SetPoint("RIGHT", annotationTooltip, "RIGHT", -4, 0)
            separator:SetPoint("TOP", line, "CENTER")
            separator:Show()
        end
        AddTooltipLine(GetAnnotationTitle(annotation), HIGHLIGHT_FONT_COLOR, 0, GameTooltipHeaderText)
        if annotation.note then
            local line = AddTooltipLine(annotation.note, NORMAL_FONT_COLOR, clustered and 2 or 0)
            if clustered then
                ellipsisPadding = math.max(ellipsisPadding, line:GetUnboundedStringWidthForText("..."))
            end
        end
    end

    if not clustered then
        AddTooltipLine(" ", NORMAL_FONT_COLOR, 0)
        AddTooltipLine("<Right click to edit annotation>", GREEN_FONT_COLOR, 0)
        AddTooltipLine("<Alt click to remove annotation>", GREEN_FONT_COLOR, 0)
    end

    annotationTooltip:Show()
    annotationTooltip:SetPadding(ellipsisPadding, 0)
end

function STRMapPinController:OnMouseLeave()
    self.HighlightTexture:Hide()
    if annotationTooltip:GetOwner() == self then
        annotationTooltip:Hide()
    end
end

-- Necessary because I override POIButtonTemplate's OnMouseEnter and OnMouseLeave.
function STRMapPinController:DisableInheritedMotionScriptsWarning()
    return true
end

-- By default, right clicks are passthrough.
function STRMapPinController:ShouldMouseButtonBePassthrough(button)
    if #self.annotations > 1 or button == "RightButton" then
        return false
    end
    return MapCanvasPinMixin.ShouldMouseButtonBePassthrough(self, button)
end
