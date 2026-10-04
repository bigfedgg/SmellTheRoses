local _, STR = ...
local Local = {}
local Version = 2

function STR.LoadData()
    SmellTheRosesDB = SmellTheRosesDB or {}
    SmellTheRosesDB.QuestAnnotations = SmellTheRosesDB.QuestAnnotations or {}
    SmellTheRosesDB.MapAnnotations = SmellTheRosesDB.MapAnnotations or {}
    SmellTheRosesDB.Options = SmellTheRosesDB.Options or {
        deleteOnTurnIn = true,
        showOverview = true
    }

    STR.Data = SmellTheRosesDB

    Local.Migrate()
end

function STR.AddQuestAnnotation(questID, mapID, x, y)
    return STR.AddAnnotation({
        questID = questID,
        mapID = mapID,
        x = x,
        y = y,
        title = C_QuestLog.GetTitleForQuestID(questID)
    })
end

function STR.AddMapAnnotation(mapID, x, y)
    return STR.AddAnnotation({
        mapID = mapID,
        x = x,
        y = y,
        title = C_Map.GetMapInfo(mapID).name
    })
end

function STR.AddAnnotation(annotation)
    local a = annotation

    a.x, a.y = RoundToSignificantDigits(a.x, 4), RoundToSignificantDigits(a.y, 4)
    if not C_Map.GetMapInfo(a.mapID) or not STR.CanAnnotateMapPosition(a.mapID, a.x, a.y) then
        return "invalid"
    end

    local mapAnnotations
    if a.questID then
        STR.Data.QuestAnnotations[a.questID] = STR.Data.QuestAnnotations[a.questID] or {}
        STR.Data.QuestAnnotations[a.questID][a.mapID] = STR.Data.QuestAnnotations[a.questID][a.mapID] or {}
        mapAnnotations = STR.Data.QuestAnnotations[a.questID][a.mapID]
        a.icon = "quest"
    else
        STR.Data.MapAnnotations[a.mapID] = STR.Data.MapAnnotations[a.mapID] or {}
        mapAnnotations = STR.Data.MapAnnotations[a.mapID]
        a.icon = "map"
    end

    if Local.HasAnnotation(mapAnnotations, a.x, a.y, a.note) then
        return "duplicate"
    end

    table.insert(mapAnnotations, a)
end

function STR.RemoveQuestAnnotation(annotation)
    -- NOTE: The number of annotations per map is expected to be small.
    local questAnnotations = STR.Data.QuestAnnotations[annotation.questID]
    local mapAnnotations = questAnnotations[annotation.mapID]

    for index, candidate in ipairs(mapAnnotations) do
        if candidate == annotation then
            table.remove(mapAnnotations, index)

            if #mapAnnotations == 0 then
                questAnnotations[annotation.mapID] = nil
            end

            if next(questAnnotations) == nil then
                STR.RemoveAllQuestAnnotations(annotation.questID)
            end
            return
        end
    end
end

function STR.RemoveAllQuestAnnotations(questID)
    STR.Data.QuestAnnotations[questID] = nil
end

function STR.CleanupAllTurnedInQuestAnnotations()
    for questID in pairs(STR.Data.QuestAnnotations) do
        if C_QuestLog.IsQuestFlaggedCompleted(questID) and not C_QuestLog.IsOnQuest(questID) then
            STR.RemoveAllQuestAnnotations(questID)
        end
    end
end

function STR.RemoveMapAnnotation(annotation)
    -- NOTE: The number of annotations per map is expected to be small.
    local mapAnnotations = STR.Data.MapAnnotations[annotation.mapID]

    for candidateID, candidate in ipairs(mapAnnotations) do
        if candidate == annotation then
            table.remove(mapAnnotations, candidateID)

            if #mapAnnotations == 0 then
                STR.Data.MapAnnotations[annotation.mapID] = nil
            end
            return
        end
    end
end

function STR.SelectAnnotationsToDisplay(targetMapID, focusedQuestID)
    local annotations = {}

    -- If a quest is focused, return only quest annotations.
    if focusedQuestID then
        local questMaps = STR.Data.QuestAnnotations[focusedQuestID]
        for _, mapAnnotations in pairs(questMaps or {}) do
            for _, annotation in ipairs(mapAnnotations) do
                table.insert(annotations, annotation)
            end
        end

    -- If overview is disabled, return only the annotations directly on the target map.
    elseif not STR.Data.Options.showOverview then
        for _, questMaps in pairs(STR.Data.QuestAnnotations) do
            for _, annotation in ipairs(questMaps[targetMapID] or {}) do
                table.insert(annotations, annotation)
            end
        end
        for _, annotation in ipairs(STR.Data.MapAnnotations[targetMapID] or {}) do
            table.insert(annotations, annotation)
        end

    -- If overview is enabled, return all annotations (they will be filtered during projection).
    -- TODO: If we pass the target map children we could already filter them here.
    elseif STR.Data.Options.showOverview then
        for _, questMaps in pairs(STR.Data.QuestAnnotations) do
            for _, mapAnnotations in pairs(questMaps) do
                for _, annotation in ipairs(mapAnnotations) do
                    table.insert(annotations, annotation)
                end
            end
        end
        for _, mapAnnotations in pairs(STR.Data.MapAnnotations) do
            for _, annotation in ipairs(mapAnnotations) do
                table.insert(annotations, annotation)
            end
        end
    end

    return annotations
end

function Local.HasAnnotation(annotations, x, y, note)
    for _, annotation in ipairs(annotations) do
        if annotation.x == x and annotation.y == y and (annotation.note or "") == (note or "") then
            return true
        end
    end
    return false
end

function Local.Migrate()
    -- Version 2:
    -- >>>> Coordinates now use 4 digits for simpler serialisation
    -- >>>> Map titles are now stored to simplify title handling
    -- >>>> Existing annotations need to keep their 2000 character limit
    if not STR.Data.Version then
        for _, questMaps in pairs(STR.Data.QuestAnnotations) do
            for _, annotations in pairs(questMaps) do
                for _, annotation in ipairs(annotations) do
                    annotation.x = RoundToSignificantDigits(annotation.x, 4)
                    annotation.y = RoundToSignificantDigits(annotation.y, 4)
                    annotation.title = annotation.questTitle
                    annotation.questTitle = nil
                    annotation._allowedMaxCharacters = 2000
                end
            end
        end
        for _, annotations in pairs(STR.Data.MapAnnotations) do
            for _, annotation in ipairs(annotations) do
                annotation.x = RoundToSignificantDigits(annotation.x, 4)
                annotation.y = RoundToSignificantDigits(annotation.y, 4)
                annotation.title = C_Map.GetMapInfo(annotation.mapID).name
                annotation._allowedMaxCharacters = 2000
            end
        end
    end

    STR.Data.Version = Version
end
