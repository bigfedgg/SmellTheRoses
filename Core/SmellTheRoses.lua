local addonName, STR = ...

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    STR.LoadData()
    STR.SetupSettings()
    STR.SetupMap()
    STR.SetupMapNavigationWithOpenQuest()
    STR.SetupShowAnnotationsOnQuestOpen()
    STR.SetupDeleteAnnotationsOnQuestTurnIn()
    STR.SetupQuestIndicators()
    STR.SetupSpokenShim()
    STR.SetupAnnotationSharing()
end)
