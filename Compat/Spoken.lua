local _, STR = ...

function STR.SetupSpokenShim()
    EventUtil.ContinueOnAddOnLoaded("Spoken_Quests", function()
        local questOverlay = VoiceOver.QuestOverlayUI

        hooksecurefunc(questOverlay, "UpdateQuestTitle", function(_, row, playButton)
            local indicator = row.STRIndicator
            if indicator and indicator:IsShown() then
                playButton:ClearAllPoints()
                playButton:SetPoint("RIGHT", row.Checkbox, "LEFT", -2, 0)
            end
        end)

        -- Spoken can lay out its buttons before StR updates the indicators. Refresh after
        -- indicator changes so adding/removing annotations and toggling visibility also move them.
        hooksecurefunc(STR, "UpdateQuestIndicators", function()
            questOverlay:Update()
        end)
    end)
end
