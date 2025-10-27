local color_bg = Color(255, 255, 255, 10)
local color_bg_hover = Color(255, 255, 255, 35)
local color_text = Color(220, 220, 220)
local color_text_interval = Color(170, 170, 0)

local PANEL = {}

local function format_interval(int)
    if int < 0 or int > 599 then int = 0 end
    local mins = math.floor(int / 60)
    local secs = math.floor(int) - mins * 60
    if mins == 0 and secs == 0 then return " -.--" end
    if secs < 10 then secs = "0" .. secs end
    return mins .. "." .. secs
end

function PANEL:Init()
    self:SetTall(40)
    self:SetMouseInputEnabled(true)
    self:SetCursor("hand")

    self.title = self:Add("DLabel")
    self.title:SetFont("HudHintTextLarge")
    self.title:SetColor(color_text)

    self.interval1 = self:Add("DLabel")
    self.interval1:SetFont("HudHintTextLarge")
    self.interval1:SetColor(color_text_interval)
    self.interval2 = self:Add("DLabel")
    self.interval2:SetFont("HudHintTextLarge")
    self.interval2:SetColor(color_text_interval)
    self.delim = self:Add("DLabel")
    self.delim:SetFont("HudHintTextLarge")
    self.delim:SetColor(color_text)
    self.delim:SetText("/")
end

function PANEL:Paint(w, h)
    if self.is_header then
        draw.RoundedBoxEx(16, 0, 0, w, h, color_bg, true, true, false, false)
    else
        draw.RoundedBoxEx(16, 0, 0, w, h, self:IsHovered() and color_bg_hover or color_bg, false, false, self.is_last, self.is_last)
    end
end

function PANEL:PerformLayout(w, h)
    self.title:SizeToContents()
    self.interval1:SizeToContents()
    self.delim:SizeToContentsX(not self.is_header and 5 or 0)
    self.delim:SizeToContentsY()
    self.interval2:SizeToContents()

    if not self.is_header then
        if self.interval1:GetWide() < 35 then
            self.interval1:SetWide(35)
        end
        if self.interval2:GetWide() < 35 then
            self.interval2:SetWide(35)
        end
    end

    self.title:SetPos(18, 20 - self.title:GetTall() / 2)
    self.interval1:SetPos(w - 18 - self.interval1:GetWide() - self.interval2:GetWide() - self.delim:GetWide() - 16, 20 - self.interval1:GetTall() / 2)
    self.delim:SetPos(w - 18 - self.interval2:GetWide() - self.delim:GetWide() - 8, 20 - self.delim:GetTall() / 2)
    self.interval2:SetPos(w - 18 - self.interval2:GetWide(), 20 - self.interval2:GetTall() / 2)
end

function PANEL:Think()
    if not self.is_header then
        if self.station and MDispatcher and MDispatcher.Intervals[self.station] then
            local intervals = MDispatcher.Intervals[self.station]
            self.interval1:SetText(intervals[1] and format_interval(intervals[1]) or " -.--")
            self.interval2:SetText(intervals[2] and format_interval(intervals[2]) or " -.--")
        else
            self.interval1:SetText(" -.--")
            self.interval2:SetText(" -.--")
        end
        -- if not self.next_invalidation or CurTime() >= self.next_invalidation then
        --     self.next_invalidation = CurTime() + 1.0
        --     self:InvalidateLayout()
        -- end
    end

    if not isfunction(self.DoClick) then return end
    if self:IsHovered() and input.IsMouseDown(MOUSE_LEFT) then
        self.depressed = true
    elseif not input.IsMouseDown(MOUSE_LEFT) and self.depressed then
        self.depressed = false
        if self:IsHovered() then
            self:DoClick()
        end
    end
end

function PANEL:SetStation(station)
    self.station = station.ID
    self.title:SetText(station.Name)
end

function PANEL:SetHeader()
    self.is_header = true
    self.title:SetText("Станция               ---------               Интервалы")
    self.interval1:SetText("Путь I")
    self.interval2:SetText("Путь II")
end

function PANEL:SetLast()
    self.is_last = true
end

vgui.Register("ZMS.PauseMenu.Station", PANEL, "DPanel")
