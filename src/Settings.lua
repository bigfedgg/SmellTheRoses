local _, STR = ...

function STR.SetupSettings()
    local categoryName = "|TInterface\\AddOns\\SmellTheRoses\\Art\\SmellTheRoses.blp:16:16|t Smell the Roses"
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

    Settings.RegisterAddOnCategory(category)
end
