local _, STR = ...

local ClusterPopup = {}

function STR.CreateClusterPopup()
    local frame = CreateFrame("Frame", "STRClusterFrame", UIParent)
    Mixin(frame, ClusterPopup)
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", frame.Close)
    frame:SetScript("OnHide", frame.OnHide)
    table.insert(UISpecialFrames, "STRClusterFrame")

    frame:CreateShadow()
    frame:CreateCloseButton()
    frame.buttons = CreateFramePool("Button", frame, "STRClusterAnnotationPinTemplate", function(pool, button)
        button:ClearAnnotation()
        Pool_HideAndClearAnchors(pool, button)
    end)
    return frame
end

function ClusterPopup:Toggle(owner)
    if self.owner == owner then
        self:Close()
        return
    end
    self:Close()

    local count = #owner.members
    local radius = math.max(44, count * 6)
    local size = 2 * (radius + 36)

    self:SetSize(size, size)
    self:SetScale(math.min(1, (UIParent:GetWidth() - 16) / size, (UIParent:GetHeight() - 16) / size))
    self:SetPoint("CENTER", owner, "CENTER")

    self.owner = owner

    for index, annotation in ipairs(owner.members) do
        local button = self.buttons:Acquire()
        button:SetAnnotation(annotation)

        local angle = math.pi / 2 + 2 * math.pi * (index - 1) / count
        button:ClearAllPoints()
        button:SetPoint("CENTER", self, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
        button:Show()
    end

    self:Show()
    self:Raise()
end

function ClusterPopup:Close()
    self:Hide()
end

function ClusterPopup:CloseForCluster(cluster)
    if self.owner == cluster then
        self:Close()
    end
end

function ClusterPopup:OnHide()
    self.owner = nil
    self.buttons:ReleaseAll()
    self:ClearAllPoints()
end

function ClusterPopup:CreateShadow()
    local shadow = self:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture("Interface\\AddOns\\SmellTheRoses\\Art\\ClusterShadow.tga")
    shadow:SetAllPoints(self)
    shadow:SetAlpha(0.5)
end

function ClusterPopup:CreateCloseButton()
    local button = CreateFrame("Button", nil, self, "STRPinTemplate")
    button:SetPoint("CENTER")
    button:SetScript("OnClick", function()
        self:Close()
    end)

    local icon = button.Display.Icon
    icon:SetSize(12, 12)
    icon:SetColorTexture(NORMAL_FONT_COLOR:GetRGBA())

    local mask = button.Display:CreateMaskTexture()
    mask:SetAtlas("common-icon-redx")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)

    button:Show()
end
