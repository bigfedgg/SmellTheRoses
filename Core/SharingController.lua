local addonName, STR = ...
local Local = {}

-- Native talent build followed by CSTR-questID:mapID:x:y:title:note:isTurnIn.
local transportLinkPattern = "|Htalentbuild:[^|]-CSTR%-([^|]+)|h.-|h"
local inputLinkPattern = "|cffffff00|Haddon:" .. addonName .. ":([^|]+)|h.-|h|r"

STR.MaxAnnotationContentSize = 800

function STR.SetupAnnotationSharing()
    -- Format the link when displayed in any chat.
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_CHANNEL", Local.FormatLinkForChat)
    for event in pairs(ChatTypeGroupInverted) do
        if event:match("^CHAT_MSG_") then
            ChatFrameUtil.AddMessageEventFilter(event, Local.FormatLinkForChat)
        end
    end

    -- Format the link for transport.
    -- NOTE: This encodes the annotation into hidden bytes inside a hyperlink. This way I avoid having to handle custom
    -- message sending. There is a non-zero chance Blizzard is going to break this before launch. The tradeoff is hidden
    -- bytes only allow ~1KB of data total, so I have to limit the size of notes.
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", Local.FormatLinkForTransport, STR)

    -- Handle hovering and clicking the link.
    EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", Local.OnLinkEntered, STR)
    EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", Local.OnLinkLeft, STR)
    EventRegistry:RegisterCallback("SetItemRef", Local.OnLinkClicked, STR)
end

function STR.ShareAnnotation(annotation)
    -- Only 1 link per message to avoid going over the hidden bytes limit.
    local editBox = ChatFrameUtil.GetActiveWindow()
    if editBox and editBox:GetText():find("|H", 1, true) then
        return
    end

    -- Catch content over the budget the size.
    -- Even though the edit box already enforces the budget, old annotations could already be over.
    local link, contentSize = Local.CreateDisplayLink(annotation)
    if contentSize >= STR.MaxAnnotationContentSize then
        ChatFrameUtil.DisplaySystemMessageInPrimary(STR.L["SHARING_TOO_LARGE"])
        return
    end

    ChatFrameUtil.InsertLink(link)
end

function Local.FormatLinkForChat(_, _, message, sender, ...)
    local text, count = message:gsub(transportLinkPattern, function(payload)
        local annotation = Local.DecodeAnnotation(payload)
        return annotation and Local.CreateDisplayLink(annotation)
    end)
    if count > 0 then
        return false, text, sender, ...
    end
end

function Local.FormatLinkForTransport(_, editBox)
    local text, count = editBox:GetText():gsub(inputLinkPattern, Local.CreateTransportLink)
    if count > 0 then
        editBox:SetText(text)
    end
end

function Local.CreateTransportLink(payload)
    -- We use the talentbuild message type to wrap the payload in hidden bytes.
    -- All fields are checked, including the color, so we fill them with something plausible.
    -- The export string is not checked, so we use it to wrap the annotation payload.
    local className, classFile, classID = UnitClass("player")
    local specID, specName = GetSpecializationInfoForClassID(classID, C_SpecializationInfo.GetSpecialization() or 1)
    local level = UnitLevel("player")
    local label = ("[%s]"):format(TALENT_BUILD_CHAT_LINK_TEXT:format(specName, className))

    local export = "CSTR-" .. payload
    local link = LinkUtil.FormatLink(LinkTypes.TalentBuild, label, specID, level, export)
    return RAID_CLASS_COLORS[classFile]:WrapTextInColorCode(link)
end

function Local.CreateDisplayLink(annotation)
    local payload, contentSize = Local.EncodeAnnotation(annotation)
    local label = STR.L["SHARING_LINK_LABEL"]:format((annotation.title:gsub("|", "||")))
    local link = LinkUtil.FormatLink(LinkTypes.AddOn, label, addonName, payload)
    return "|cffffff00" .. link .. "|r", contentSize
end

function Local.OnLinkEntered(_, chatFrame, link)
    local payload = link:match("^addon:" .. addonName .. ":(.+)$")
    local annotation = payload and Local.DecodeAnnotation(payload)
    if not annotation then
        return
    end

    GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR")
    GameTooltip_SetTitle(GameTooltip, annotation.title, NORMAL_FONT_COLOR)
    GameTooltip_AddHighlightLine(GameTooltip, ("(%.2f, %.2f)"):format(annotation.x * 100, annotation.y * 100))
    if annotation.note then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddNormalLine(GameTooltip, STR.L["NOTE_TITLE"])
        GameTooltip_AddHighlightLine(GameTooltip, annotation.note, true)
    end
    GameTooltip_AddBlankLineToTooltip(GameTooltip)
    GameTooltip_AddInstructionLine(GameTooltip, STR.L["SHARING_LINK_ADD_HINT"])
    GameTooltip:Show()
end

function Local.OnLinkLeft(_, chatFrame)
    if GameTooltip:GetOwner() == chatFrame then
        GameTooltip:Hide()
    end
end

function Local.OnLinkClicked(_, link, _, button)
    local payload = link:match("^addon:" .. addonName .. ":(.+)$")
    if not payload or button ~= "LeftButton" then
        return
    end
    local annotation = Local.DecodeAnnotation(payload)
    if not annotation then
        ChatFrameUtil.DisplaySystemMessageInPrimary(STR.L["ERROR_INVALID_ANNOTATION"])
        return
    end

    if IsModifiedClick("CHATLINK") then
        STR.ShareAnnotation(annotation)
    else
        Local.ReceiveAnnotation(annotation)
    end
end

function Local.ReceiveAnnotation(annotation)
    local errorKey
    if not STR.Utils.CanAnnotateMapPosition(annotation) then
        errorKey = "ERROR_INVALID_ANNOTATION"
    else
        errorKey = STR.AddAnnotation(annotation)
    end
    if errorKey then
        ChatFrameUtil.DisplaySystemMessageInPrimary(STR.L[errorKey])
        return
    end

    if STR.IsAddonEnabled() then
        STR.MapController:OpenAnnotation(annotation)
        STR.MapController:RefreshAllData()
        STR.MapController:PingAnnotations({ annotation })
        STR.UpdateQuestIndicators()
    end
    ChatFrameUtil.DisplaySystemMessageInPrimary(STR.L["SHARING_ADDED"])
end

function Local.EncodeAnnotation(annotation)
    local title, note = STR.Utils.EscapeText(annotation.title), STR.Utils.EscapeText(annotation.note)
    return ("%s:%d:%04.0f:%04.0f:%s:%s:%d"):format(
            annotation.questID or "", annotation.mapID,
            annotation.x * 10000, annotation.y * 10000,
            title, note, annotation.isTurnIn and 1 or 0), #title + #note
end

function Local.DecodeAnnotation(payload)
    local questID, mapID, x, y, title, note, isTurnIn = strsplit(":", payload)
    questID, mapID, x, y = tonumber(questID), tonumber(mapID), tonumber(x), tonumber(y)

    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    if not (mapInfo and x and y and title and note) then
        return
    end

    -- Transform the title to the proper language.
    -- Quest titles might not be immediately available if the user hasn't seen the quest recently.
    -- TODO: Eventually we can lookup the quest title in the background.
    if questID then
        title = C_QuestLog.GetTitleForQuestID(questID) or Local.UnescapeText(title)
    else
        title = mapInfo.name
    end

    return {
        questID = questID,
        mapID = mapID,
        x = x / 10000,
        y = y / 10000,
        title = title,
        note = note ~= "" and Local.UnescapeText(note) or nil,
        isTurnIn = isTurnIn == "1" or nil
    }
end

function Local.UnescapeText(text)
    return (text:gsub("%%(%x%x)", function(byte)
        return string.char(tonumber(byte, 16))
    end))
end
