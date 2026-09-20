local addonName, STR = ...

-- Hook the note editor container to the WorldMapFrame.
-- NOTE: The editor is constructed as a dropdown menu, inspired by the native map menus.
-- I like how those menus look and I didn't want to reinvent them, so here we are...
local STRNoteEditorContainer = WorldMapFrame:AddOverlayFrame("STRNoteEditorDropdownTemplate", "DROPDOWNBUTTON")

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

-- Hook the map controller to the WorldMapFrame.
-- NOTE: In the current design the controller can be active before the state is loaded.
-- This is why I use a readiness flag on the state. In the future I want to try wiring
-- the controller only after the state is loaded from the DB.
local STRMapController = STR.GetMapController()
WorldMapFrame:AddDataProvider(STRMapController)
WorldMapFrame:AddCanvasClickHandler(function(canvas, button, x, y)
    return STRMapController:OnClick(canvas, button, x, y)
end)

-- Load data from the character's SavedVariables.
local STRDataLoader = CreateFrame("Frame")
STRDataLoader:RegisterEvent("ADDON_LOADED")
STRDataLoader:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    print(SmellTheRosesDB)
    SmellTheRosesDB = SmellTheRosesDB or {}
    SmellTheRosesDB.QuestAnnotations = SmellTheRosesDB.QuestAnnotations or {}
    SmellTheRosesDB.MapAnnotations = SmellTheRosesDB.MapAnnotations or {}

    STR.Data = SmellTheRosesDB
    STR.Loaded = true

    self:UnregisterEvent("ADDON_LOADED")
end)
