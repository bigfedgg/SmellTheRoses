local addonName, STR = ...
local Local = {}

-- Native talent build followed by CSTR-questID:mapID:x:y:title:note.
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
        ChatFrameUtil.DisplaySystemMessageInPrimary("The annotation content is too large to share.")
        return
    end

    ChatFrameUtil.InsertLink(link)
end

function Local.FormatLinkForChat(_, _, message, sender, ...)
    local text, count = message:gsub(transportLinkPattern, function(payload)
        return Local.CreateDisplayLink(Local.DecodeAnnotation(payload))
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
    local title = annotation.title
    local link = LinkUtil.FormatLink(LinkTypes.AddOn, "[StR: " .. title:gsub("|", "||") .. "]", addonName, payload)
    return "|cffffff00" .. link .. "|r", contentSize
end

function Local.OnLinkEntered(_, chatFrame, link)
    local payload = link:match("^addon:" .. addonName .. ":(.+)$")
    if not payload then
        return
    end

    local annotation = Local.DecodeAnnotation(payload)
    GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR")
    GameTooltip_SetTitle(GameTooltip, annotation.title)
    GameTooltip_AddNormalLine(GameTooltip, ("(%.2f, %.2f)"):format(annotation.x * 100, annotation.y * 100))
    if annotation.note then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip_AddNormalLine(GameTooltip, annotation.note, true)
    end
    GameTooltip_AddBlankLineToTooltip(GameTooltip)
    GameTooltip_AddInstructionLine(GameTooltip, "<Click to add annotation>")
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
    if IsModifiedClick("CHATLINK") then
        STR.ShareAnnotation(annotation)
    else
        Local.ReceiveAnnotation(annotation)
    end
end

function Local.ReceiveAnnotation(annotation)
    local error = STR.AddAnnotation(annotation)
    if error == "invalid" then
        ChatFrameUtil.DisplaySystemMessageInPrimary("The annotation is not valid.")
        return
    elseif error == "duplicate" then
        ChatFrameUtil.DisplaySystemMessageInPrimary("The annotation already exists.")
        return
    end

    STR.GetMapController():OpenAnnotation(annotation)
    ChatFrameUtil.DisplaySystemMessageInPrimary("The annotation has been added to your map.")
end

function Local.EncodeAnnotation(annotation)
    local title, note = STR.EscapeText(annotation.title), STR.EscapeText(annotation.note)
    return ("%s:%d:%04.0f:%04.0f:%s:%s"):format(
        annotation.questID or "", annotation.mapID,
        annotation.x * 10000, annotation.y * 10000,
        title, note), #title + #note
end

function Local.DecodeAnnotation(payload)
    local questID, mapID, x, y, title, note = payload:match("^([^:]*):(%d+):(%d+):(%d+):([^:]*):(.*)$")
    return {
        questID = tonumber(questID),
        mapID = tonumber(mapID),
        x = tonumber(x) / 10000,
        y = tonumber(y) / 10000,
        title = Local.UnescapeText(title),
        note = note ~= "" and Local.UnescapeText(note) or nil
    }
end

function STR.EscapeText(text)
    if not text then
        return ""
    end
    return (text:gsub("[%c%%|{}]", function(character)
        return ("%%%02X"):format(character:byte())
    end)):gsub(":", "%%3A")
end

function Local.UnescapeText(text)
    return (text:gsub("%%(%x%x)", function(byte)
        return string.char(tonumber(byte, 16))
    end))
end
