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
end

function STRAnnotationButtonMixin:ClearAnnotation()
    STR.GetMapController():CloseNoteEditor(self)
    self.annotation = nil
    self:OnMouseLeave()
end

function STRAnnotationButtonMixin:OnClick(button)
    -- Alt+Click to remove a pin.
    if button == "LeftButton" and IsAltKeyDown() then
        STR.GetMapController():DeleteAnnotation(self.annotation)
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
    STR.GetMapController():OpenTooltipForAnnotation(self)
end

function STRAnnotationButtonMixin:OnMouseLeave()
    self.HighlightTexture:Hide()
    STR.GetMapController():CloseTooltip(self)
end

-- This mixin is specifically for annotation pins drawn on the map (i.e. STRMapAnnotationPinTemplate)
-- The other kind (STRClusterAnnotationPinTemplate) uses STRAnnotationButtonMixin directly.
STRMapAnnotationPinMixin = CreateFromMixins(MapCanvasPinMixin, STRAnnotationButtonMixin)

function STRMapAnnotationPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST")
    self:SetScalingLimits(1, 1, 1)
end

function STRMapAnnotationPinMixin:OnAcquired(annotation, x, y)
    self:SetAnnotation(annotation)
    self:SetPosition(x, y)
end

function STRMapAnnotationPinMixin:OnReleased()
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
