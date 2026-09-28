local addonName, STR = ...

local STRInitializer = CreateFrame("Frame")
STRInitializer:RegisterEvent("ADDON_LOADED")
STRInitializer:SetScript("OnEvent", function(self, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    STR.LoadData()
    STR.SetupSettings()
    STR.SetupMap()
    STR.SetupMapNavigationWithOpenQuest()
    STR.SetupQuestAnnotationsDisplay()
    STR.SetupDeleteAnnotationsOnQuestTurnIn()

    self:UnregisterEvent("ADDON_LOADED")
end)
