ZMS = ZMS or {}
ZMS.ASNP = ZMS.ASNP or { HudEnabled = true }

local initial_height = 24
local max_height = 280
local elem_height = 40
local gap = 5


local ElemPanel = {}

function ElemPanel:Init()
    self.LC = self:Add("Panel")
    self.RC = self:Add("Panel")
    self.TLL = self.LC:Add("DLabel")
    self.BLL = self.LC:Add("DLabel")
    self.TRL = self.RC:Add("DLabel")
    self.BRL = self.RC:Add("DLabel")

    self.TLL:SetFont("MDispSmallTitle")
    self.TLL:SetTextColor(Color(255, 255, 255))

    local info = { self.BLL, self.TRL, self.BRL }
    for _, p in ipairs(info) do
        p:SetFont("MDispSmall")
        p:SetTextColor(Color(255, 255, 255))
    end
end

function ElemPanel:Paint(w, h)
    surface.SetDrawColor(255, 255, 255, 60)
    surface.DrawLine(0, 0, w, 0)
end

function ElemPanel:PerformLayout()
    self.LC:SetWide(30)
    self.LC:Dock(LEFT)
    self.LC:DockMargin(gap * 2, 4, 0, 0)
    self.RC:Dock(FILL)
    self.RC:DockMargin(gap * 2, 4, gap * 2, 0)
    for _, p in ipairs({ self.TLL, self.BLL, self.TRL, self.BRL }) do
        p:SetTall(self:GetTall() / 2 - 2)
        p:Dock(TOP)
    end
end

function ElemPanel:SetData(data)
    self.TLL:SetText(data.RouteNumber)
    if not data.Operational or not data.Active then
        self.BLL:SetText(" ---")
        self.TRL:SetText(data.Active and "Ошибка получения данных" or "АСНП не настроен")
        self.BRL:SetText("-----------------")
        return
    end
    self.BLL:SetText((data.LockedL and "X" or "O") .. (data.LockedR and "X" or "O"))
    self.TRL:SetText(string.format("%s %s", data.Arrived and "Отпр." or "Приб.", data.Station))
    self.BRL:SetText(string.format("Путь %d %s", data.Path, data.LastStation))
end

vgui.Register("ZMS.DispAsnp.Panel.Element", ElemPanel, "Panel")


local Panel = {}

function Panel:Init()
    self.Title = vgui.Create("DLabel", self)
    self.Title:SetFont("MDispMain")
    self.Title:SetText("Мониторинг АСНП")
    self.Root = vgui.Create("DScrollPanel", self)

    self.TargetHeight = initial_height
    self.Elements = {}

    self.ScrollDirection = false
    self.ScrollState = false
    self.ScrollBreakpoint = 0

    self:SetVisible(false)
end

function Panel:Paint(w, h)
    draw.RoundedBox(5, 0, 0, w, h, Color(0, 0, 0, 150))
end

function Panel:PerformLayout()
    local target_height = self.TargetHeight or initial_height
    self:SetSize(250, target_height + initial_height)
    self:SetPos(ScrW() - self:GetWide() - gap, ScrH() - self:GetTall() - gap)
    self.Title:SizeToContents()
    self.Title:SetPos((self:GetWide() / 2) - (self.Title:GetWide() / 2), gap)
    self.Title:SetTextColor(Color(255, 255, 255))
    self.Root:SetPos(0, initial_height)
    self.Root:SetSize(250, target_height)
    local sb = self.Root:GetVBar()
    sb:SetSize(0, 0)
end

function Panel:Update(data)
    local len = #data
    if 0 >= len then
        self.Elements = {}
        self.Root:Clear()
        self:SetVisible(false)
        return
    end
    self.TargetHeight = math.Clamp(len * elem_height + (len - 1) * gap, 0, max_height)

    local elem_len = #self.Elements
    for idx, pd in ipairs(data) do
        local elem
        if elem_len >= idx then
            elem = self.Elements[idx]
        else
            elem = self.Root:Add("ZMS.DispAsnp.Panel.Element")
            elem:SetTall(elem_height)
            elem:Dock(TOP)
            elem:DockMargin(0, 0, 0, gap)
            self.Elements[idx] = elem
        end

        elem:SetData(pd)
        elem:InvalidateLayout()
    end

    if elem_len > len then
        for idx = 1, elem_len - len do
            local elem = self.Elements[idx + len]
            elem:Remove()
            self.Elements[idx + len] = nil
        end
    end

    self:SetVisible(true)
    self:InvalidateLayout()
end

function Panel:Think()
    local vbar = self.Root:GetVBar()
    if self.Root:GetCanvas():GetTall() <= self.TargetHeight then
        self.ScrollDirection = false
        self.ScrollState = false
        self.ScrollBreakpoint = 0
        vbar:SetScroll(0)
        return
    end

    local max_scroll = self.Root:GetCanvas():GetTall() - self.TargetHeight
    local time_to_scroll = max_scroll / 30.0

    if self.ScrollBreakpoint < CurTime() then
        self.ScrollState = not self.ScrollState
        if not self.ScrollState then self.ScrollDirection = not self.ScrollDirection end
        self.ScrollBreakpoint = CurTime() + (self.ScrollState and time_to_scroll or 4)
    end
    if not self.ScrollState then
        if not self.ScrollDirection then
            vbar:SetScroll(0)
        else
            vbar:SetScroll(max_scroll)
        end
    else
        local left = self.ScrollBreakpoint - CurTime()
        local complete = (time_to_scroll - left) / time_to_scroll
        if self.ScrollDirection then
            vbar:SetScroll(max_scroll - complete * max_scroll)
        else
            vbar:SetScroll(complete * max_scroll)
        end
    end
end

vgui.Register("ZMS.DispAsnp.Panel", Panel, "Panel")

net.Receive("ZMS.DispAsnp.Update", function()
    local ln = net.ReadUInt(32)
    local tbl = util.JSONToTable(util.Decompress(net.ReadData(ln)))
    if not ZMS.ASNP.HudEnabled then return end
    if not IsValid(ZMS.ASNP.HudPanel) then
        ZMS.ASNP.HudPanel = vgui.Create("ZMS.DispAsnp.Panel")
    end
    ZMS.ASNP.HudPanel:Update(tbl)
end)

timer.Simple(10, function()
    timer.Create("ZMS.DispAsnp.UpdateClient", 5, 0, function()
        local permission = ULib.ucl.query(LocalPlayer(), "zms_droute_menu")
        if not ZMS.ASNP.HudEnabled or not (permission or not MDispatcher or MDispatcher.Dispatcher == LocalPlayer():Nick()) then
            if IsValid(ZMS.ASNP.HudPanel) then
                ZMS.ASNP.HudPanel:Remove()
            end
            return
        end
        net.Start("ZMS.DispAsnp.Update")
        net.SendToServer()
    end)
end)
