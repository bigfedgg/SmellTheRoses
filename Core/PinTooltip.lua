local _, STR = ...

local textWidth = 280

local PinTooltip = {
    frame = CreateFrame("GameTooltip", "STRAnnotationTooltip", UIParent, "GameTooltipTemplate")
}
STR.PinTooltip = PinTooltip

function PinTooltip:Open(pin)
    local annotation = pin.annotation

    local anchor = InputUtil.IsMKBUIEnabled() and "ANCHOR_CURSOR_RIGHT" or "ANCHOR_RIGHT"
    self.frame:SetOwner(pin, anchor, 5, 2)

    if annotation.questID and C_QuestLog.IsOnQuest(annotation.questID) then
        local title = SetQuestTitleLevelAndDifficultyColor(annotation.questID, annotation.title)
        self:AddText(title, NORMAL_FONT_COLOR, GameTooltipHeaderText)
        if not annotation.isTurnIn then
            for _, objective in ipairs(C_QuestLog.GetQuestObjectives(annotation.questID)) do
                if not objective.finished then
                    self:AddText(QUEST_DASH .. objective.text, HIGHLIGHT_FONT_COLOR)
                end
            end
        end
    else
        self:AddText(annotation.title, NORMAL_FONT_COLOR, GameTooltipHeaderText)
    end

    if annotation.note then
        self:AddText(" ", HIGHLIGHT_FONT_COLOR)
        self:AddText(STR.L["NOTE_TITLE"], NORMAL_FONT_COLOR)
        self:AddText(annotation.note, HIGHLIGHT_FONT_COLOR)
    end

    self:AddText(" ", HIGHLIGHT_FONT_COLOR)
    self:AddText(STR.L["PIN_TOOLTIP_EDIT_HINT"], GREEN_FONT_COLOR)
    self:AddText(STR.L["PIN_TOOLTIP_REMOVE_HINT"], GREEN_FONT_COLOR)
    self.frame:Show()
end

function PinTooltip:Close(owner)
    if not owner or self.frame:GetOwner() == owner then
        self.frame:Hide()
    end
end

function PinTooltip:AddText(text, color, font)
    GameTooltip_AddColoredLine(self.frame, text, color, true)
    local line = self.frame:GetLeftLine(self.frame:NumLines())
    line:SetFontObject(font or GameTooltipText)
    line:SetTextColor(color:GetRGB())
    line:SetWidth(textWidth)
end
