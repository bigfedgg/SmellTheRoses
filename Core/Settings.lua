local _, STR = ...

function STR.SetupSettings()
    local categoryName = "Smell the Roses"
    local category, layout = Settings.RegisterVerticalLayoutCategory(categoryName)

    -- Delete quest annotations on turn-in.
    local setting = Settings.RegisterAddOnSetting(
            category,
            "STR_DELETE_ANNOTATIONS_ON_TURN_IN",
            "deleteOnTurnIn",
            STR.Data.Options,
            Settings.VarType.Boolean,
            "Delete after quest turn-in",
            true
    )

    local initializer = CreateSettingsCheckboxWithButtonInitializer(
            setting,
            "Cleanup",
            function()
                StaticPopup_Show("GENERIC_CONFIRMATION", nil, nil, {
                    text = "Delete all existing annotations for quests this character has already turned in?",
                    acceptText = DELETE,
                    cancelText = CANCEL,
                    callback = function()
                        STR.CleanupAllTurnedInQuestAnnotations()
                        STR.GetMapController():RefreshAllData()
                    end
                })
            end,
            nil,
            false,
            "Delete quest annotations after you turn in the quest."
    )
    layout:AddInitializer(initializer)

    -- Disable with Blizzard objectives.
    local objectivesSetting = Settings.RegisterAddOnSetting(
            category,
            "STR_DISABLE_WITH_QUEST_OBJECTIVES",
            "disableWithQuestObjectives",
            STR.Data.Options,
            Settings.VarType.Boolean,
            "Disable with Blizzard objectives",
            true
    )
    Settings.CreateCheckbox(
            category,
            objectivesSetting,
            "Disable addon when Blizzard's Quest Objectives are enabled."
    )
    objectivesSetting:SetValueChangedCallback(STR.RefreshAnnotationVisibility)
    CVarCallbackRegistry:RegisterCallback("questPOI", STR.RefreshAnnotationVisibility, STR)

    Settings.RegisterAddOnCategory(category)
end

function STR.RefreshAnnotationVisibility()
    STR.GetMapController():RefreshAllData()
    STR.UpdateQuestIndicators()
end

function STR.IsAddonEnabled()
    return not (STR.Data.Options.disableWithQuestObjectives and GetCVarBool("questPOI"))
end