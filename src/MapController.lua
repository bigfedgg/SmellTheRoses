local _, STR = ...

---@class STRMapController: MapCanvasDataProviderMixin
---@field focusedQuestID number?
local STRMapController = CreateFromMixins(MapCanvasDataProviderMixin)

function STR.GetMapController()
    return STRMapController
end

function STRMapController:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)

    self.focusedQuestID = QuestMapFrame.DetailsFrame.questID

    map:RegisterCallback("SetFocusedQuestID", self.OnFocusedQuestChanged, self)
    map:RegisterCallback("ClearFocusedQuestID", self.OnFocusedQuestCleared, self)
end

function STRMapController:OnRemoved(map)
    self.focusedQuestID = nil

    map:UnregisterCallback("SetFocusedQuestID", self)
    map:UnregisterCallback("ClearFocusedQuestID", self)

    MapCanvasDataProviderMixin.OnRemoved(self, map)
end

function STRMapController:OnFocusedQuestChanged(questID)
    self.focusedQuestID = questID
    self:RefreshAllData()
end

function STRMapController:OnFocusedQuestCleared()
    self.focusedQuestID = nil
    self:RefreshAllData()
end

function STRMapController:RefreshAllData()
    if not STR.Loaded then
        return
    end

    self:RemoveAllData()

    local openedMap = self:GetMap()
    local openedMapID = openedMap:GetMapID()

    if self.focusedQuestID then
        local maps = STR.Data.QuestAnnotations[self.focusedQuestID]
        self:AddPinsForAnnotations(maps and maps[openedMapID])
    else
        for _, maps in pairs(STR.Data.QuestAnnotations) do
            self:AddPinsForAnnotations(maps[openedMapID])
        end
        self:AddPinsForAnnotations(STR.Data.MapAnnotations[openedMapID])
    end
end

function STRMapController:AddPinsForAnnotations(annotations)
    if annotations then
        local map = self:GetMap()
        for _, annotation in ipairs(annotations) do
            map:AcquirePin("STRMapPinTemplate", annotation)
        end
    end
end

function STRMapController:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate("STRMapPinTemplate")
end

function STRMapController:OnClick(canvas, button, x, y)
    if not STR.Loaded or button ~= "LeftButton" or not IsAltKeyDown() then
        return false
    end

    local openedMapID = canvas:GetMapID()
    if self.focusedQuestID then
        STR.AddQuestAnnotation(self.focusedQuestID, openedMapID, x, y)
    else
        STR.AddMapAnnotation(openedMapID, x, y)
    end

    self:RefreshAllData()

    return true
end
