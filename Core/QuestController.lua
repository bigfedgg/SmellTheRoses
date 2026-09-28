local _, STR = ...

function STR.SetupQuestAnnotationDisplay()
    local function openMapForQuest(questID)
        if STR.Data.QuestAnnotations[questID] then
            STR.GetMapController():OpenMapForQuest(questID)
        end
    end

    hooksecurefunc("QuestMapLogTitleButton_OnClick", function(button, mouseButton)
        if mouseButton ~= "LeftButton" or IsShiftKeyDown() then
            return
        end
        if QuestMapFrame.DetailsFrame.questID ~= button.questID then
            return
        end
        openMapForQuest(button.questID)
    end)
    hooksecurefunc("QuestMapFrame_OpenToQuestDetails", function(questID)
        openMapForQuest(questID)
    end)
end

function STR.SetupQuestAnnotationIndicators()
    hooksecurefunc("QuestLogQuests_Update", STR.UpdateQuestIndicatorsInJournal)
    hooksecurefunc(QuestObjectiveTracker, "Update", STR.UpdateQuestIndicatorsInTracker)
    hooksecurefunc(QuestObjectiveTracker, "OnFreeBlock", function(_, block)
        if block.STRAnnotationIndicator then
            block.STRAnnotationIndicator:Hide()
        end
    end)
    hooksecurefunc(STR, "AddQuestAnnotation", STR.UpdateQuestIndicators)
    hooksecurefunc(STR, "RemoveAllQuestAnnotations", STR.UpdateQuestIndicators)

    STR.UpdateQuestIndicators()
end

function STR.UpdateQuestIndicators()
    STR.UpdateQuestIndicatorsInJournal()
    STR.UpdateQuestIndicatorsInTracker()
end

function STR.UpdateQuestIndicatorsInJournal()
    for button in QuestScrollFrame.titleFramePool:EnumerateActive() do
        local hasAnnotations = STR.Data.QuestAnnotations[button.questID] ~= nil
        local blizzardPin = QuestScrollFrame.Contents:FindButtonByQuestID(button.questID)
        local showIndicator = hasAnnotations and not blizzardPin

        if showIndicator and not button.STRAnnotationIndicator then
            button.STRAnnotationIndicator = STR.CreateQuestIndicator(button)
            button.STRAnnotationIndicator:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -4)
        end
        if button.STRAnnotationIndicator then
            button.STRAnnotationIndicator:SetShown(showIndicator)
        end
    end
end

function STR.UpdateQuestIndicatorsInTracker()
    QuestObjectiveTracker:EnumerateActiveBlocks(function(block)
        if block.template ~= QuestObjectiveTracker.blockTemplate then
            return
        end

        local hasAnnotations = STR.Data.QuestAnnotations[block.id] ~= nil
        local showIndicator = hasAnnotations and not block.poiButton

        if showIndicator and not block.STRAnnotationIndicator then
            block.STRAnnotationIndicator = STR.CreateQuestIndicator(block)
            block.STRAnnotationIndicator:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -7, 5)
        end
        if block.STRAnnotationIndicator then
            block.STRAnnotationIndicator:SetShown(showIndicator)
        end
    end)
end

function STR.CreateQuestIndicator(parent)
    local indicator = CreateFrame("Frame", nil, parent)
    indicator:SetSize(20, 20)

    local background = indicator:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("UI-QuestPoi-QuestNumber", true)
    background:SetPoint("CENTER")

    local icon = indicator:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas("Quest-In-Progress-Icon-yellow", true)
    icon:SetPoint("CENTER")

    return indicator
end

function STR.SetupMapNavigationWithOpenQuest()
    -- NOTE: Map navigation calls WorldMapFrame.SetMapID, which by default closes
    -- any open quest details if it targets a different map (details.questMapID).
    -- Furthermore QuestMapFrame_ShowQuestDetails calls WorldMapFrame.SetMapID to
    -- set its details.questMapID as the displayed map, overriding any navigation
    -- while the quest is open. The solution to allow free map navigation is then
    -- to prevent both functions from resetting the map during a navigation call.
    -- If this sounded awkward, it's because I really wanted to get it aligned :|

    local lockedMap = false
    local originalSetMapID = WorldMapFrame.SetMapID
    local originalShowQuestDetails = QuestMapFrame_ShowQuestDetails

    local function lockMapAndCall(originalFunction, ...)
        local wasMapLocked = lockedMap
        lockedMap = true
        local ok, message = pcall(originalFunction, ...)
        lockedMap = wasMapLocked
        if not ok then
            error(message, 0)
        end
    end

    -- Prevent navigation if the map is locked.
    WorldMapFrame.SetMapID = function(map, mapID)
        if lockedMap then
            return
        end

        local details = QuestMapFrame.DetailsFrame
        if details.questID then
            details.questMapID = mapID
        end

        return originalSetMapID(map, mapID)
    end

    -- Lock the map before showing quest details to prevent resetting it.
    -- NOTE: SetMapID is called first when navigating, so here we're locking that map.
    QuestMapFrame_ShowQuestDetails = function(questID)
        local details = QuestMapFrame.DetailsFrame
        local returnMapID = details.returnMapID

        local refreshingOpenedQuest = details.questID == questID
        local preserveMapNavigation = lockedMap or refreshingOpenedQuest

        if preserveMapNavigation then
            lockMapAndCall(originalShowQuestDetails, questID)
        else
            originalShowQuestDetails(questID)
        end

        details.questMapID = WorldMapFrame:GetMapID()
        if refreshingOpenedQuest then
            details.returnMapID = returnMapID
        end
    end

    STR.OpenQuestFromPin = function(questID)
        lockMapAndCall(QuestMapFrame_OpenToQuestDetails, questID)
    end
end

function STR.SetupDeleteAnnotationsOnQuestTurnIn()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:SetScript("OnEvent", function(_, _, questID)
        if STR.Data.Options.deleteOnTurnIn then
            STR.RemoveAllQuestAnnotations(questID)
            STR.GetMapController():RefreshAllData()
        end
    end)
end