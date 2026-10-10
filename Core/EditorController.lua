local _, STR = ...

local openMenu

-- NOTE: The editor is constructed as a menu, inspired by the native map menus.
-- I like how those menus look and I didn't want to reinvent them, so here we are...
function STR.OpenNoteEditor(pin)
    local editor
    local rootDescription = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultMenuMixin())
    rootDescription:SetMinimumWidth(220)
    rootDescription:CreateTitle(STR.L["NOTE_TITLE"])
    rootDescription:CreateTemplate("STRNoteEditorTemplate"):AddInitializer(function(frame, _, menu)
        editor = frame
        frame:Initialize(pin.annotation, menu)
    end)

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
end

function STRNoteEditorMixin:Initialize(annotation, menu)
    self.annotation = annotation
    self.menu = menu

    -- Button to toggle the annotation type.
    -- For maps: isGlobal; for quests: isTurnIn.
    local toggleButton = self.ToggleButton
    if annotation.questID then
        toggleButton:SetStyle(STR.Utils.GetQuestAnnotationStyle(not annotation.isTurnIn))
        toggleButton:UpdateButtonStyle()
    else
        toggleButton:SetStyle(POIButtonUtil.Style.Waypoint)
        toggleButton:UpdateButtonStyle()
        toggleButton.Display:SetAtlas(nil, nil, "worldquest-icon")
    end
    toggleButton.GlobalFill:SetShown(not annotation.questID and not annotation.isGlobal)

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

function STRNoteEditorMixin:FocusAtEnd()
    self.ScrollingEditBox:SetFocus()
    self.ScrollingEditBox:SetCursorPosition(#self.ScrollingEditBox:GetText())
end

function STRNoteEditorMixin:OnHide()
    self.ScrollingEditBox:ClearFocus()
end

-- Used by: ToggleButton in STRNoteEditorTemplate.
STRNoteEditorToggleButtonMixin = {}

function STRNoteEditorToggleButtonMixin:OnClick()
    self:GetParent():ToggleAnnotationType()
end

function STRNoteEditorToggleButtonMixin:OnSuperTrackingChanged()
end
