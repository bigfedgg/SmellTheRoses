local _, STR = ...

local STRQuestController = {}

function STR.GetQuestController()
    return STRQuestController
end

function STRQuestController:SetupMapNavigation()
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
            local wasMapLocked = lockedMap
            lockedMap = true
            local ok, message = pcall(originalShowQuestDetails, questID)
            lockedMap = wasMapLocked
            if not ok then
                error(message, 0)
            end
        else
            originalShowQuestDetails(questID)
        end

        details.questMapID = WorldMapFrame:GetMapID()
        if refreshingOpenedQuest then
            details.returnMapID = returnMapID
        end
    end

    STRQuestController.OpenQuestFromPin = function(questID)
        local wasMapLocked = lockedMap
        lockedMap = true
        local ok, message = pcall(QuestMapFrame_OpenToQuestDetails, questID)
        lockedMap = wasMapLocked
        if not ok then
            error(message, 0)
        end
    end
end
