local _, STR = ...

function STR.LoadData()
    SmellTheRosesDB = SmellTheRosesDB or {}
    SmellTheRosesDB.QuestAnnotations = SmellTheRosesDB.QuestAnnotations or {}
    SmellTheRosesDB.MapAnnotations = SmellTheRosesDB.MapAnnotations or {}
    SmellTheRosesDB.Options = SmellTheRosesDB.Options or {
        deleteOnTurnIn = true,
        showOverview = true
    }

    STR.Data = SmellTheRosesDB
end

function STR.AddQuestAnnotation(questID, mapID, x, y)
    STR.Data.QuestAnnotations[questID] = STR.Data.QuestAnnotations[questID] or {}
    STR.Data.QuestAnnotations[questID][mapID] = STR.Data.QuestAnnotations[questID][mapID] or {}

    table.insert(STR.Data.QuestAnnotations[questID][mapID], {
        questID = questID,
        questTitle = C_QuestLog.GetTitleForQuestID(questID),
        mapID = mapID,
        x = x,
        y = y,
        icon = "quest",
        note = nil
    })
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

function STR.AddMapAnnotation(mapID, x, y)
    STR.Data.MapAnnotations[mapID] = STR.Data.MapAnnotations[mapID] or {}

    table.insert(STR.Data.MapAnnotations[mapID], {
        mapID = mapID,
        x = x,
        y = y,
        icon = "map",
        note = nil
    })
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

function STR.CleanupAllTurnedInQuestAnnotations()
    for questID in pairs(STR.Data.QuestAnnotations) do
        if C_QuestLog.IsQuestFlaggedCompleted(questID) and not C_QuestLog.IsOnQuest(questID) then
            STR.RemoveAllQuestAnnotations(questID)
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