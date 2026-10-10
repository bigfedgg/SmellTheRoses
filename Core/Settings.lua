local _, STR = ...
local Local = {}

function STR.SetupSettings()
    local categoryName = "Smell the Roses"
    local panel = CreateFrame("Frame", nil, nil, "STRSettingsPanelTemplate")
    panel.Title:SetText(categoryName)

    local category = Settings.RegisterCanvasLayoutCategory(panel, categoryName)
    Settings.RegisterAddOnCategory(category)
end

function STR.IsAddonEnabled()
    return not (STR.Data.Options.disableWithQuestObjectives and GetCVarBool("questPOI"))
end

-- Used by: STRSettingsPanelTemplate.
STRSettingsPanelMixin = {}

function STRSettingsPanelMixin:OnLoad()
    -- Delete quest annotations on turn-in.
    self.DeleteOnTurnIn:Init(
            STR.L["SETTINGS_DELETE_ON_TURN_IN_LABEL"],
            STR.L["SETTINGS_DELETE_ON_TURN_IN_TOOLTIP"],
            "deleteOnTurnIn"
    )
    self.CleanupButton:SetText(STR.L["SETTINGS_CLEANUP_BUTTON"])
    self.CleanupButton:SetScript("OnClick", function()
        StaticPopup_Show("GENERIC_CONFIRMATION", nil, nil, {
            text = STR.L["SETTINGS_CLEANUP_CONFIRMATION"],
            acceptText = DELETE,
            cancelText = CANCEL,
            callback = Local.CleanupTurnedInQuestAnnotations
        })
    end)

    -- Disable with Blizzard objectives.
    self.DisableWithObjectives:Init(
            STR.L["SETTINGS_DISABLE_WITH_OBJECTIVES_LABEL"],
            STR.L["SETTINGS_DISABLE_WITH_OBJECTIVES_TOOLTIP"],
            "disableWithQuestObjectives",
            function()
                STR.MapController:RefreshAllData()
                STR.UpdateQuestIndicators()
            end
    )
end

-- Used by: STRSettingsCheckboxTemplate.
STRSettingsCheckboxMixin = {}

function STRSettingsCheckboxMixin:OnLoad()
    self.Tooltip:SetScript("OnMouseUp", function()
        self.Checkbox:Click()
    end)
end

function STRSettingsCheckboxMixin:Init(label, tooltip, optionKey, onValueChanged)
    local function initTooltip()
        Settings.InitTooltip(label, tooltip)
    end

    self.Text:SetText(label)
    self.Tooltip:SetTooltipFunc(initTooltip)
    self.Checkbox:Init(STR.Data.Options[optionKey], initTooltip)
    self.Checkbox:RegisterCallback(SettingsCheckboxMixin.Event.OnValueChanged, function(_, value)
        PlaySound(value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        STR.Data.Options[optionKey] = value
        if onValueChanged then
            onValueChanged()
        end
    end, self)
end

function Local.CleanupTurnedInQuestAnnotations()
    for _, annotation in ipairs(STR.GetAllAnnotations()) do
        local questID = annotation.questID
        local isTurnedIn = questID
                and C_QuestLog.IsQuestFlaggedCompleted(questID)
                and not C_QuestLog.IsOnQuest(questID)
        if isTurnedIn then
            STR.RemoveQuestAnnotations(questID)
        end
    end
    STR.MapController:RefreshAllData()
end
