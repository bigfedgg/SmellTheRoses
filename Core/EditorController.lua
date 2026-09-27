local _, STR = ...
local STRNoteEditorContainer

function STR.SetupNoteEditor()
    -- Add the note editor container to the WorldMapFrame.
    -- NOTE: The editor is constructed as a dropdown menu, inspired by the native map menus.
    -- I like how those menus look and I didn't want to reinvent them, so here we are...
    STRNoteEditorContainer = WorldMapFrame:AddOverlayFrame("STRNoteEditorDropdownTemplate", "DROPDOWNBUTTON")
end

function STR.OpenEditorFrameForPin(pin)
    GameTooltip:Hide()
    STRNoteEditorContainer:CloseEditor()
    STRNoteEditorContainer:OpenEditor(pin)
end

function STR.CloseEditorFrameForPin(pin)
    if STRNoteEditorContainer.pin == pin then
        STRNoteEditorContainer:CloseEditor()
    end
end

-- Controller for STRNoteEditorDropdownTemplate.
STRNoteEditorContainerController = {}

function STRNoteEditorContainerController:OnLoad()
    WowStyle1DropdownMixin.OnLoad(self)

    self:SetupMenu(function (container, rootDescription)
        rootDescription:SetMinimumWidth(container.menuWidth)
        rootDescription:CreateTitle("Note:")

        local editorFrame = rootDescription:CreateTemplate("STRNoteEditorFrameTemplate")
        editorFrame:AddInitializer(function(editor, _, menu)
            container.editor = editor
            editor:Initialize(container.pin.annotations[1], menu)
            return editor:GetSize()
        end)
    end)
end

function STRNoteEditorContainerController:OpenEditor(pin)
    self.pin = pin

    self:ClearAllPoints()
    self:SetPoint("CENTER", pin, "CENTER")
    self:SetMenuAnchor(AnchorUtil.CreateAnchor("TOP", pin, "BOTTOM", 0, -8))

    self:Show()
    self:OpenMenu()
end

function STRNoteEditorContainerController:CloseEditor()
    if self:IsMenuOpen() then
        self:CloseMenu("DummyReason")
    end
    self:Hide()
end

function STRNoteEditorContainerController:OnMenuOpened(menu)
    DropdownButtonMixin.OnMenuOpened(self, menu)
    self.editor:FocusAtEnd()
end

function STRNoteEditorContainerController:OnMenuClosed(menu)
    DropdownButtonMixin.OnMenuClosed(self, menu)
    self:Hide()
end

function STRNoteEditorContainerController:OnHide()
    self.editor = nil
    self.pin = nil

    if self:IsMenuOpen() then
        self:CloseMenu()
    end
end

function STRNoteEditorContainerController:Refresh()
    if not self.pin then
        self:CloseEditor()
    end
end

-- Controller for STRNoteEditorFrameTemplate.
STRNoteEditorFrameController = {}

function STRNoteEditorFrameController:Initialize(annotation, menu)
    self.annotation = annotation
    self.menu = menu

    -- InputScrollFrameTemplate has some art we need to hide.
    local scrollFrame = self.ScrollFrame
    scrollFrame.TopLeftTex:Hide()
    scrollFrame.TopRightTex:Hide()
    scrollFrame.TopTex:Hide()
    scrollFrame.BottomLeftTex:Hide()
    scrollFrame.BottomRightTex:Hide()
    scrollFrame.BottomTex:Hide()
    scrollFrame.LeftTex:Hide()
    scrollFrame.RightTex:Hide()
    scrollFrame.MiddleTex:Hide()

    -- Size using lines and font height.
    local editBox = scrollFrame.EditBox
    editBox:SetFontObject(GameFontHighlight)
    local _, fontHeight = editBox:GetFont()
    self:SetHeight(fontHeight * self.lines)
    editBox:SetHeight(self:GetHeight())
    editBox:SetWidth(self:GetWidth())

    -- Too lazy to create my own template, so I'm just hooking manually.
    editBox:SetScript("OnTextChanged", function(_, userInput)
        InputScrollFrame_OnTextChanged(editBox, userInput)

        if userInput and self.annotation then
            local text = editBox:GetText()
            self.annotation.note = text ~= "" and text or nil
        end
    end)
    editBox:SetScript("OnEscapePressed", function(_)
        InputScrollFrame_OnEscapePressed(editBox)

        if self.menu then
            self.menu:Close()
        end
    end)

    -- Scroll to beginning and show the note.
    scrollFrame:SetVerticalScroll(0)
    editBox:SetText(annotation.note or "")
end

function STRNoteEditorFrameController:FocusAtEnd()
    local editBox = self.ScrollFrame.EditBox
    editBox:HighlightText(0, 0)
    editBox:SetFocus()
    editBox:SetCursorPosition(#editBox:GetText())
end

function STRNoteEditorFrameController:OnHide()
    self.ScrollFrame.EditBox:ClearFocus()
    self.annotation = nil
    self.menu = nil
end
