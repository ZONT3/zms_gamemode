net.Receive("ZMS.ATZ.MenuOpen", function()
    local ln = net.ReadUInt(16)
    local cases = util.JSONToTable(util.Decompress(net.ReadData(ln)))
    local atz_menu = vgui.Create("ZMS.ATZ.Menu")
    atz_menu:SetData(cases)
end)


local saved_case = nil
local saved_num = nil
local saved_wag = nil
local saved_opts = nil

local PANEL = {}

function PANEL:Init()
    self:SetSize(600, 600)
    self:Center()
    self:MakePopup()
    self:SetTitle("Управление АТЗ")

    self.list_c = self:Add("Panel")
    self.list = self.list_c:Add("DListView")
    self.clear = self.list_c:Add("DButton")

    self.detail = self:Add("Panel")
    self.desc = self.detail:Add("DLabel")
    self.options = self.detail:Add("DTextEntry")
    self.apply = self.detail:Add("Panel")
    self.apply_mode_label = self.apply:Add("DLabel")
    self.apply_mode = self.apply:Add("DComboBox")
    self.apply_number = self.apply:Add("DNumSlider")

    self.info = self.detail:Add("DLabel")
    self.exec = self.detail:Add("DButton")


    self.list:SetMultiSelect(false)
    self.list:AddColumn("Case")

    self.apply_number:SetMin(1)
    self.apply_number:SetMax(8)
    self.apply_number:SetDecimals(0)

    self.desc:SetAutoStretchVertical(true)
    self.desc:SetWrap(true)
    self.desc:SetText("Выберите случай")
    self.info:SetText("Случай недосупен для текущего состава")
    self.exec:SetText("Выполнить")
    self.clear:SetText("Очистить поезд")
    self.apply_mode_label:SetText("Вагон(-ы):")
    self.options:SetPlaceholderText("Опции...")

    self.list_c:Dock(LEFT)
    self.list_c:SetWide(300)
    self.list:Dock(FILL)
    self.clear:Dock(BOTTOM)
    self.detail:Dock(FILL)
    self.desc:Dock(FILL)
    self.apply:Dock(BOTTOM)
    self.apply:SetTall(35)
    self.apply_mode_label:Dock(LEFT)
    self.apply_mode:Dock(LEFT)
    self.apply_mode:SetWide(100)
    self.apply_number:Dock(FILL)
    self.options:Dock(BOTTOM)
    self.info:Dock(BOTTOM)
    self.exec:Dock(BOTTOM)

    self.clear.DoClick = function()
        RunConsoleCommand("ulx", "atzcl", "^")
    end
end

function PANEL:SelectCase(case)
    local desc = case.desc
    if case.restriction then
        desc = string.format("%s\n\nДоступно для: %s", desc, case.restriction)
    end
    self.desc:SetText(desc or "Нет описания")
    self.exec:SetEnabled(case.allowed)
    self.info:SetVisible(not case.allowed)
    self.apply:SetVisible(case.per_wagon)

    self.exec.DoClick = function()
        local opts = {  }
        local user_opts = string.Trim(self.options:GetValue() or "")
        local wagon_opt = case.per_wagon and self.wagon_opt or nil
        if #user_opts > 0 then
            table.insert(opts, user_opts)
        end
        if wagon_opt then
            table.insert(opts, wagon_opt)
        end
        RunConsoleCommand("ulx", "atz", "^", case.name, table.concat(opts, " "))

        saved_case = case.name
        saved_num = self.apply_number:GetValue()
        saved_opts = self.options:GetValue()
        saved_wag = self.apply_mode:GetSelectedID()
    end

    self.apply_mode:Clear()
    self.apply_mode:AddChoice("Текущий", "")
    self.apply_mode:AddChoice("Хвостовой", "rear")
    self.apply_mode:AddChoice("Все", "all")
    self.apply_mode:AddChoice("Случ. n…", "w")
    self.apply_number:SetVisible(false)
    self.wagon_opt = nil
    self.apply_mode.OnSelect = function(_, _, _, data)
        local w = data == "w"
        self.apply_number:SetVisible(w)
        self.wagon_opt = w and ("w" .. self.apply_number:GetValue()) or #data > 0 and data or nil
    end
    self.apply_number.OnValueChanged = function( _, value )
        if select(2, self.apply_mode:GetSelected()) == "w" then
            self.wagon_opt = "w" .. value
        end
    end

    self.apply_mode:ChooseOptionID(saved_wag or 1)
    if saved_opts then self.options:SetValue(saved_opts) end
    if saved_num then self.apply_number:SetValue(saved_num) end

    self:InvalidateLayout()
end

function PANEL:SetData(cases)
    self.list:Clear()
    for _, case in ipairs(cases) do
        local pnl = self.list:AddLine(case.name)
        pnl.case = case
        if case.name == saved_case then
            self.list:SelectItem(pnl)
            self:SelectCase(pnl.case)
        end
    end
    self.list.OnRowSelected = function(_, _, pnl)
        if pnl.case then
            self:SelectCase(pnl.case)
        end
    end
end

vgui.Register("ZMS.ATZ.Menu", PANEL, "DFrame")
