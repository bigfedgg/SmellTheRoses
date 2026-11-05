local _, STR = ...
local Local = {}

local version = 4

function STR.LoadData()
    SmellTheRosesDB = SmellTheRosesDB or { Version = version }
    SmellTheRosesDB.Annotations = SmellTheRosesDB.Annotations or {}
    SmellTheRosesDB.Options = SmellTheRosesDB.Options or {
        deleteOnTurnIn = true,
        showOverview = true
    }
    STR.Data = SmellTheRosesDB

    SmellTheRosesGlobalDB = SmellTheRosesGlobalDB or { Version = version }
    SmellTheRosesGlobalDB.Annotations = SmellTheRosesGlobalDB.Annotations or {}
    STR.GlobalData = SmellTheRosesGlobalDB

    Local.Migrate()
end

function STR.AddAnnotation(annotation)
    annotation.x = RoundToSignificantDigits(annotation.x, 4)
    annotation.y = RoundToSignificantDigits(annotation.y, 4)
    annotation.icon = annotation.icon or "default"

    if Local.HasAnnotation(annotation) then
        return "ERROR_DUPLICATE_ANNOTATION"
    end

    table.insert(STR.Data.Annotations, annotation)
end

function STR.SetGlobalMapAnnotation(annotation, isGlobal)
    STR.RemoveAnnotation(annotation)
    annotation.isGlobal = isGlobal or nil
    table.insert(isGlobal and STR.GlobalData.Annotations or STR.Data.Annotations, annotation)
end

function STR.RemoveAnnotation(annotation)
    tDeleteItem(STR.Data.Annotations, annotation)
    tDeleteItem(STR.GlobalData.Annotations, annotation)
end

function STR.RemoveQuestAnnotations(questID)
    for _, annotation in ipairs(STR.GetQuestAnnotations(questID)) do
        STR.RemoveAnnotation(annotation)
    end
end

function STR.GetAllAnnotations()
    local annotations = CopyTable(STR.Data.Annotations, true)
    tAppendAll(annotations, STR.GlobalData.Annotations)
    return annotations
end

function STR.GetQuestAnnotations(questID)
    return tFilter(STR.Data.Annotations, function(annotation)
        return annotation.questID == questID
    end, true)
end

function Local.HasAnnotation(annotation)
    return ContainsIf(STR.GetAllAnnotations(), function(candidate)
        return candidate.questID == annotation.questID and candidate.mapID == annotation.mapID
                and candidate.x == annotation.x and candidate.y == annotation.y
                and (candidate.note or "") == (annotation.note or "")
    end)
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
        STR.Data.Version = 2
    end

    -- Version 3:
    -- >>>> Annotations are one single list because it makes operations simpler.
    -- >>>> There is no more icon for now, we'll see if we need it later.
    if STR.Data.Version < 3 then
        for _, questMaps in pairs(STR.Data.QuestAnnotations) do
            for _, annotations in pairs(questMaps) do
                for _, annotation in ipairs(annotations) do
                    annotation.icon = nil
                    table.insert(STR.Data.Annotations, annotation)
                end
            end
        end
        for _, annotations in pairs(STR.Data.MapAnnotations) do
            for _, annotation in ipairs(annotations) do
                annotation.icon = nil
                table.insert(STR.Data.Annotations, annotation)
            end
        end
        STR.Data.QuestAnnotations = nil
        STR.Data.MapAnnotations = nil
    end
    if not STR.GlobalData.Version then
        for _, annotations in pairs(STR.GlobalData.MapAnnotations) do
            for _, annotation in ipairs(annotations) do
                annotation.icon = nil
                table.insert(STR.GlobalData.Annotations, annotation)
            end
        end
        STR.GlobalData.MapAnnotations = nil
        STR.GlobalData.Version = 3
    end

    -- Version 4:
    -- >>>> Annotations now store their selected icon.
    if STR.Data.Version < 4 then
        for _, annotation in ipairs(STR.Data.Annotations) do
            annotation.icon = annotation.icon or "default"
        end
    end
    if STR.GlobalData.Version < 4 then
        for _, annotation in ipairs(STR.GlobalData.Annotations) do
            annotation.icon = annotation.icon or "default"
        end
    end

    STR.Data.Version = version
    STR.GlobalData.Version = version
end
