local _, STR = ...

local annotationIcons = {
    quest = "worldquest-icon",
    map = "Quest-In-Progress-Icon-yellow"
}

STRMapPinController = CreateFromMixins(MapCanvasPinMixin)

function STRMapPinController:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetScalingLimits(1, 1, 1)
end

function STRMapPinController:OnAcquired(annotation, x, y)
    self.annotation = annotation

    self:SetPosition(x, y)
    self.Display:SetAtlas(nil, nil, annotationIcons[annotation.icon])
    self.Display:SetIconShown(true)
end

function STRMapPinController:OnReleased()
    STR.CloseEditorFrameForPin(self)
    MapCanvasPinMixin.OnReleased(self)

    self.annotation = nil

    self.HighlightTexture:Hide()
    if GameTooltip:GetOwner() == self then
        GameTooltip:Hide()
    end
end

function STRMapPinController:OnClick(button)
    -- Alt+Click to remove a pin.
    if button == "LeftButton" and IsAltKeyDown() then
        if self.annotation.questID then
            STR.RemoveQuestAnnotation(self.annotation)
        else
            STR.RemoveMapAnnotation(self.annotation)
        end

        self:GetMap():RemovePin(self)
        return
    end

    -- Click a pin to go to its map.
    -- If it's a quest pin also open its quest details.
    if button == "LeftButton" then
        local annotation, map = self.annotation, self:GetMap()
        if annotation.questID then
            STR.GetQuestController().OpenQuestFromPin(annotation.questID)
        end
        if map:GetMapID() ~= annotation.mapID then
            map:SetMapID(annotation.mapID)
            map:ResetZoom()
        end
        return
    end

    -- Right click to edit a pin.
    if button == "RightButton" then
        STR.OpenEditorFrameForPin(self)
        return
    end
end

function STRMapPinController:OnMouseEnter()
    self.HighlightTexture:Show()

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local title = C_Map.GetMapInfo(self.annotation.mapID).name
    if self.annotation.questID then
        title = C_QuestLog.GetTitleForQuestID(self.annotation.questID)
    end
    GameTooltip_SetTitle(GameTooltip, title, HIGHLIGHT_FONT_COLOR)

    local note = self.annotation.note
    if note then
        GameTooltip_AddNormalLine(GameTooltip, note, true)
    end

    GameTooltip_AddBlankLineToTooltip(GameTooltip)
    GameTooltip_AddColoredLine(GameTooltip, "<Right click to edit annotation>", GREEN_FONT_COLOR, true)
    GameTooltip_AddColoredLine(GameTooltip, "<Alt click to remove annotation>", GREEN_FONT_COLOR, true)

    GameTooltip:Show()
end

function STRMapPinController:OnMouseLeave()
    self.HighlightTexture:Hide()
    if GameTooltip:GetOwner() == self then
        GameTooltip:Hide()
    end
end

-- Necessary because I override POIButtonTemplate's OnMouseEnter and OnMouseLeave.
function STRMapPinController:DisableInheritedMotionScriptsWarning()
    return true
end

-- By default, right clicks are passthrough.
function STRMapPinController:ShouldMouseButtonBePassthrough(button)
    if button == "RightButton" then
        return false
    end
    return MapCanvasPinMixin.ShouldMouseButtonBePassthrough(self, button)
end
