local _, STR = ...
local Local = {}

-- NOTE: When the player opens a quest with the addon enabled, and navigates
-- to a different map, we construct a "fake" quest panel and keep it open.
-- The initial plan  was to use the default quest details and override some of
-- its function to avoid map navigation but that was tainting the UI.
local stickyQuestID
local stickyReturnMapID
local stickyDetailsButtons = {}
local closingQuestID
local closingReturnMapID

function STR.SetupDeleteAnnotationsOnQuestTurnIn()
    EventRegistry:RegisterFrameEventAndCallback("QUEST_TURNED_IN", function(_, questID)
        if STR.Data.Options.deleteOnTurnIn then
            STR.RemoveQuestAnnotations(questID)
        end
    end, STR)
end

function STR.SetupMapNavigationWithOpenQuest()
    local details = QuestMapFrame.DetailsFrame

    hooksecurefunc(WorldMapFrame.ScrollContainer, "SetMapID", function()
        closingQuestID, closingReturnMapID = details.questID, details.returnMapID
    end)
    hooksecurefunc(QuestMapFrame, "Refresh", function()
        if closingQuestID and not details.questID and STR.IsAddonEnabled() then
            stickyQuestID, stickyReturnMapID = closingQuestID, closingReturnMapID

            QuestScrollFrame:Hide()
            details:Show()
            details.DestinationMapButton:Hide()
            details.WaypointMapButton:Hide()

            Local.UpdateStickyDetailsButtons()
            STR.MapController:RefreshAllData()
        end
        closingQuestID, closingReturnMapID = nil, nil
    end)
    hooksecurefunc("QuestMapFrame_ShowQuestDetails", Local.ReleaseQuestDetails)
    hooksecurefunc("QuestMapFrame_CloseQuestDetails", Local.ReleaseQuestDetails)

    EventRegistry:RegisterFrameEventAndCallback("QUEST_REMOVED", function(_, questID)
        if questID == stickyQuestID then
            STR.CloseStickyQuestDetails()
        end
    end, Local)

    Local.CreateStickyDetailsButton(details.BackFrame.BackButton, function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        local returnMapID = stickyReturnMapID
        STR.CloseStickyQuestDetails()
        STR.MapController:OpenMap(returnMapID)
    end)
    Local.CreateStickyDetailsButton(details.AbandonButton, function()
        QuestMapQuestOptions_AbandonQuest(stickyQuestID)
    end)
    Local.CreateStickyDetailsButton(details.ShareButton, function()
        QuestMapQuestOptions_ShareQuest(stickyQuestID)
    end)
    Local.CreateStickyDetailsButton(details.TrackButton, function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        QuestMapQuestOptions_TrackQuest(stickyQuestID)
    end)
    hooksecurefunc("QuestMapFrame_UpdateQuestDetailsButtons", Local.UpdateStickyDetailsButtons)
    Local.UpdateStickyDetailsButtons()
end

function STR.GetFocusedQuestID()
    return QuestMapFrame_GetFocusedQuestID() or stickyQuestID
end

function STR.CloseStickyQuestDetails()
    if stickyQuestID then
        QuestMapFrame.DetailsFrame:Hide()
        QuestScrollFrame:Show()
        Local.ReleaseQuestDetails()
    end
end

function Local.ReleaseQuestDetails()
    if not stickyQuestID then
        return
    end

    stickyQuestID, stickyReturnMapID = nil, nil
    Local.UpdateStickyDetailsButtons()
    STR.MapController:RefreshAllData()
end

function Local.CreateStickyDetailsButton(blizzardButton, onClick)
    local button = CreateFrame("Button", nil, blizzardButton:GetParent(), "UIPanelButtonTemplate")
    button:SetAllPoints(blizzardButton)
    button:SetFrameLevel(blizzardButton:GetFrameLevel() + 1)
    button:SetScript("OnClick", onClick)
    button.blizzardButton = blizzardButton
    table.insert(stickyDetailsButtons, button)
end

function Local.UpdateStickyDetailsButtons()
    for _, button in ipairs(stickyDetailsButtons) do
        button:SetText(button.blizzardButton:GetText())
        button:SetEnabled(button.blizzardButton:IsEnabled())
        button:SetShown(stickyQuestID ~= nil)
    end
end

function STR.SetupShowAnnotationsOnQuestOpen()
    -- Setup clicking on the journal to show all quest annotations.
    hooksecurefunc("QuestMapLogTitleButton_OnClick", function(button, mouseButton)
        if mouseButton ~= "LeftButton" or IsShiftKeyDown() then
            return
        end
        if QuestMapFrame.DetailsFrame.questID ~= button.questID then
            return
        end
        STR.MapController:ShowQuestAnnotations(button.questID)
    end)

    -- Setup clicking on the quest tracker to show all quest annotations.
    hooksecurefunc("QuestMapFrame_OpenToQuestDetails", function(questID)
        STR.MapController:ShowQuestAnnotations(questID)
    end)
end

function STR.SetupQuestIndicators()
    hooksecurefunc("QuestLogQuests_Update", Local.UpdateJournalIndicators)
    hooksecurefunc(QuestObjectiveTracker, "Update", Local.UpdateTrackerIndicators)
    EventRegistry:RegisterCallback("SetHighlightedQuestPOI", Local.UpdateJournalIndicators, Local)
    EventRegistry:RegisterCallback("ClearHighlightedQuestPOI", Local.UpdateJournalIndicators, Local)

    STR.UpdateQuestIndicators()
end

function STR.UpdateQuestIndicators()
    Local.UpdateJournalIndicators()
    Local.UpdateTrackerIndicators()
end

function Local.UpdateJournalIndicators()
    local isAddonEnabled = STR.IsAddonEnabled()
    for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
        if not button.STRIndicator then
            button.STRIndicator = CreateFrame("Button", nil, button:GetParent(), "STRQuestIndicatorTemplate")
            button.STRIndicator:SetFrameLevel(button:GetFrameLevel() + 1)
            button.STRIndicator:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -4)
            button:HookScript("OnHide", function(row)
                row.STRIndicator:Hide()
            end)
        end

        local questID = button.questID
        local hasAnnotations = #STR.GetQuestAnnotations(questID) > 0
        local blizzardPin = QuestScrollFrame.Contents:FindButtonByQuestID(questID)
        local showIndicator = isAddonEnabled and hasAnnotations and not blizzardPin

        button.STRIndicator:Update(questID)
        button.STRIndicator.HighlightTexture:SetShown(questID == STR.MapController:GetHighlightedQuestID())
        button.HighlightTexture:SetShown(questID == QuestScrollFrame.calloutQuestID or questID == STR.MapController:GetHoveredQuestID())
        button.STRIndicator:SetAlpha(showIndicator and 1 or 0)
        button.STRIndicator:Show()
    end
end

function Local.UpdateTrackerIndicators()
    local isAddonEnabled = STR.IsAddonEnabled()
    QuestObjectiveTracker:EnumerateActiveBlocks(function(block)
        if block.template ~= QuestObjectiveTracker.blockTemplate then
            return
        end

        if not block.STRIndicator then
            block.STRIndicator = CreateFrame("Button", nil, block, "STRQuestIndicatorTemplate")
            block.STRIndicator:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -7, 5)
        end

        local questID = block.id
        local hasAnnotations = #STR.GetQuestAnnotations(questID) > 0
        local showIndicator = isAddonEnabled and hasAnnotations and not block.poiButton

        block.STRIndicator:Update(questID)
        block.STRIndicator:SetShown(showIndicator)
    end)
end
