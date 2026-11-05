local _, STR = ...

function STR.SetupSpokenShim()
    EventUtil.ContinueOnAddOnLoaded("Spoken_Quests", function()
        local questOverlay = VoiceOver.QuestOverlayUI

        hooksecurefunc(questOverlay, "UpdateQuestTitle", function(_, row, playButton)
            local indicator = row.STRIndicator
            if indicator and indicator:IsShown() then
                playButton:ClearAllPoints()
                playButton:SetPoint("RIGHT", row.Checkbox, "LEFT", -2, 0)
                if not GetCVarBool("questPOI") then
                    row.Text:SetPoint("RIGHT", row.Checkbox, "LEFT", -27, 0)
                    local bottom = row.Text:GetBottom()
                    for objective in QuestScrollFrame.objectiveFramePool:EnumerateActive() do
                        if objective.questID == row.questID then
                            bottom = math.min(bottom, objective:GetBottom())
                        end
                    end
                    local padding = GetCVarBool("showQuestObjectivesInLog") and 6 or 10
                    row:SetHeight(row:GetTop() - bottom + padding)
                    QuestScrollFrame.Contents:MarkDirty()
                end
            end
        end)

        -- Spoken can lay out its buttons before StR updates the indicators. Refresh after
        -- indicator changes so adding/removing annotations and toggling visibility also move them.
        hooksecurefunc(STR, "UpdateQuestIndicators", function()
            questOverlay:Update()
        end)
    end)
end
