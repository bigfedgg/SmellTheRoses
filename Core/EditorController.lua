local _, STR = ...

local openMenu
local editorWidth = 232
local iconSpacing = 28
local iconStrip = { "default", "npc", "skull", "chest", "resource", "vendor", "magnifying", "flag" }

-- NOTE: The editor is constructed as a menu, inspired by the native map menus.
-- I like how those menus look and I didn't want to reinvent them, so here we are...
function STR.OpenNoteEditor(pin)
    local editor
    local rootDescription = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultMenuMixin())
    rootDescription:SetMinimumWidth(editorWidth)
    rootDescription:SetMaximumWidth(editorWidth)
    rootDescription:CreateTitle(STR.L["NOTE_TITLE"])
    rootDescription:CreateTemplate("STRNoteEditorTemplate"):AddInitializer(function(frame, _, menu)
        editor = frame
        frame:Initialize(pin.annotation, menu)
    end)

    rootDescription:CreateSpacer(8)
    local checkboxLabel = pin.annotation.questID and "NOTE_TURN_IN_LOCATION" or "NOTE_GLOBAL_ANNOTATION"
    rootDescription:CreateCheckbox(STR.L[checkboxLabel], function()
        if pin.annotation.questID then
            return pin.annotation.isTurnIn
        end
        return pin.annotation.isGlobal
    end, function()
        editor:ToggleAnnotationType()
    end)

    if not pin.annotation.questID then
        rootDescription:CreateSpacer(8)
        rootDescription:CreateSpacer(28):AddInitializer(function(frame)
            for index, button in ipairs(editor.iconButtons) do
                button:SetPoint("CENTER", frame, "CENTER", (index - (#editor.iconButtons + 1) / 2) * iconSpacing, 0)
            end
        end)
    end

    local anchor = AnchorUtil.CreateAnchor("TOP", pin, "BOTTOM", 0, -8)
    openMenu = Menu.GetManager():OpenMenu(pin, rootDescription, anchor)
    openMenu:SetClosedCallback(function()
        openMenu = nil
    end)
    editor:FocusAtEnd()
end

function STR.CloseNoteEditor()
    if openMenu then
        openMenu:Close()
    end
end

-- Used by: STRNoteEditorTemplate.
STRNoteEditorMixin = {}

function STRNoteEditorMixin:OnLoad()
    local scrollingEditBox = self.ScrollingEditBox
    scrollingEditBox:RegisterCallback("OnTextChanged", self.OnTextChanged, self)
    scrollingEditBox:RegisterCallback("OnEscapePressed", self.OnEscapePressed, self)
    scrollingEditBox:RegisterCallback("OnCursorChanged", self.OnCursorChanged, self)

    local scrollBox = scrollingEditBox:GetScrollBox()
    ScrollUtil.RegisterScrollBoxWithScrollBar(scrollBox, self.ScrollBar)
    local anchorsWithBar = {
        CreateAnchor("TOPLEFT", scrollingEditBox, "TOPLEFT"),
        CreateAnchor("BOTTOMRIGHT", scrollingEditBox, "BOTTOMRIGHT", -18, 0),
    }
    local anchorsWithoutBar = {
        anchorsWithBar[1],
        CreateAnchor("BOTTOMRIGHT", scrollingEditBox, "BOTTOMRIGHT"),
    }
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, self.ScrollBar, anchorsWithBar, anchorsWithoutBar)

    self.iconButtons = {}
    for index, name in ipairs(iconStrip) do
        local button = CreateFrame("Button", nil, self, "POIButtonTemplate, STRAnnotationGlobalFillTemplate")
        button.icon = name
        button:SetStyle(POIButtonUtil.Style.Waypoint)
        button:UpdateButtonStyle()
        STR.Utils.ApplyMapAnnotationIcon(button, name)
        button.Glow:Hide()
        button:SetScript("OnClick", function()
            self:SelectIcon(name)
        end)
        button:SetScript("OnLeave", function()
            POIButtonMixin.OnLeave(button)
            button.HighlightTexture:SetShown(button.icon == self.annotation.icon)
        end)
        self.iconButtons[index] = button
    end
end

function STRNoteEditorMixin:Initialize(annotation, menu)
    self.annotation = annotation
    self.menu = menu

    for _, button in ipairs(self.iconButtons) do
        button:SetShown(not annotation.questID)
        button.GlobalFill:SetShown(annotation.isGlobal)
        button.HighlightTexture:SetShown(button.icon == annotation.icon)
    end

    -- Length is byte-based instead of character based because the limit
    -- comes from allowed hidden bytes when sharing a note. This is all
    -- because I don't want to implement a full addon message sending system
    -- or have to depend on Ace3. So this is good enough and should allow
    -- for large enough notes without having to complicate sharing.
    local editBox = self.ScrollingEditBox:GetEditBox()
    if annotation._allowedMaxCharacters then
        self.maxNoteBytes = nil
        editBox:SetMaxBytes(0)
        editBox:SetMaxLetters(annotation._allowedMaxCharacters)
    else
        self.maxNoteBytes = STR.MaxAnnotationContentSize - 1 - #STR.Utils.EscapeText(annotation.title)
        editBox:SetMaxLetters(0)
        editBox:SetMaxBytes(self.maxNoteBytes)
    end

    self.ScrollingEditBox:SetText(annotation.note or "")
end

function STRNoteEditorMixin:OnTextChanged(editBox, userChanged)
    if not userChanged then
        return
    end

    -- This seems fine to do on text change from testing.
    local text = editBox:GetText()
    if self.maxNoteBytes and #STR.Utils.EscapeText(text) > self.maxNoteBytes then
        local previousText = self.annotation.note or ""
        local cursorPosition = editBox:GetCursorPosition() - #text + #previousText
        self.ScrollingEditBox:SetText(previousText)
        self.ScrollingEditBox:SetCursorPosition(cursorPosition)
        return
    end

    self.annotation.note = text ~= "" and text or nil
end

function STRNoteEditorMixin:OnEscapePressed()
    self.menu:Close()
end

function STRNoteEditorMixin:OnCursorChanged()
    local allowCursorClipping = false
    self.ScrollingEditBox:ScrollCursorIntoView(allowCursorClipping)
end

function STRNoteEditorMixin:ToggleAnnotationType()
    local annotation = self.annotation
    if annotation.questID then
        annotation.isTurnIn = not annotation.isTurnIn or nil
    else
        STR.SetGlobalMapAnnotation(annotation, not annotation.isGlobal)
    end

    self.menu:Close()
    STR.MapController:RefreshAllData()
    STR.UpdateQuestIndicators()
end

function STRNoteEditorMixin:SelectIcon(name)
    self.annotation.icon = name
    for _, button in ipairs(self.iconButtons) do
        button.HighlightTexture:SetShown(button.icon == name)
    end
    STR.Utils.ApplyMapAnnotationIcon(self.menu:GetOwnerRegion(), name)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

function STRNoteEditorMixin:FocusAtEnd()
    self.ScrollingEditBox:SetFocus()
    self.ScrollingEditBox:SetCursorPosition(#self.ScrollingEditBox:GetText())
end

function STRNoteEditorMixin:OnHide()
    self.ScrollingEditBox:ClearFocus()
end
