local _, STR = ...

function STR.AddQuestAnnotation(questID, mapID, x, y)
    STR.Data.QuestAnnotations[questID] = STR.Data.QuestAnnotations[questID] or {}
    STR.Data.QuestAnnotations[questID][mapID] = STR.Data.QuestAnnotations[questID][mapID] or {}

    table.insert(STR.Data.QuestAnnotations[questID][mapID], {
        questID = questID,
        mapID = mapID,
        x = x,
        y = y,
        icon = "quest",
        note = nil
    })
end

function STR.RemoveQuestAnnotation(annotation)
    -- NOTE: The number of annotations per map is expected to be small.
    for candidateID, candidate in ipairs(STR.Data.QuestAnnotations[annotation.questID][annotation.mapID]) do
        if candidate == annotation then
            table.remove(STR.Data.QuestAnnotations[annotation.questID][annotation.mapID], candidateID)
            return
        end
    end
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
    for candidateID, candidate in ipairs(STR.Data.MapAnnotations[annotation.mapID]) do
        if candidate == annotation then
            table.remove(STR.Data.MapAnnotations[annotation.mapID], candidateID)
            return
        end
    end
end