ZMS = ZMS or {}

local SPACER = 0
local TABS = 1

local mainmenu_buttons = {
    { "Продолжить", function()
        ZMS.ClosePauseMenu()
    end },
    { "Возродиться", function()
        RunConsoleCommand("kill")
        ZMS.ClosePauseMenu()
    end },
    SPACER,
    TABS,
    SPACER,
    { "Меню игры", function()
        ZMS.ClosePauseMenu()
        if IsValid(LocalPlayer()) then
            LocalPlayer():ChatPrint("Для открытия стандартного меню, используйте Shift+Esc")
        end
    end },
    { "Отключиться", function()
        RunConsoleCommand("disconnect")
        ZMS.ClosePauseMenu()
    end },
}

local function insert_spacer(menu_panel)
    local p = menu_panel:Add("Panel")
    p:SetTall(16)
    menu_panel:SetupElement(p)
end

local function add_buttons(menu_panel)
    for _, button in ipairs(mainmenu_buttons) do
        if not istable(button) then
            if button == SPACER then
                insert_spacer(menu_panel)
            elseif button == TABS then
                menu_panel:AddTabsButtons()
            end
        else
            local pnl = menu_panel:AddButton()
            pnl:SetText(button[1])
            pnl.DoClick = button[2]
        end
    end
end

local function add_stations(menu_panel)
    if not MDispatcher or not MDispatcher.Stations then return end

    insert_spacer(menu_panel)
    local header = menu_panel:Add("ZMS.PauseMenu.Station")
    menu_panel:SetupElement(header)
    header:SetHeader()

    local last = nil
    for _, station in pairs(MDispatcher.Stations) do
        local st = menu_panel:Add("ZMS.PauseMenu.Station")
        last = st
        menu_panel:SetupElement(st)
        st:SetStation(station)
        st.DoClick = function()
            RunConsoleCommand("ulx", "station", tostring(station.ID))
        end
    end
    if last then
        last:SetLast()
    end
end

hook.Add("ZMS.PauseMenu.InitMenu", "ZMS.PauseMenu.InitMenu.Main", function(menu_panel)
    add_buttons(menu_panel)
    add_stations(menu_panel)
end)

timer.Create("ZMS.UpdateIntervals", 1, 0, function()
    if (
        IsValid(LocalPlayer()) and MDispatcher and MDispatcher.Intervals and IsValid(ZMS.PauseMenuPanel)
        and not LocalPlayer():GetNW2Bool("MDispatcher.ShowIntervals", false)
    ) then
        if table.Count(MDispatcher.Intervals) == 0 then return end
        for k,v in pairs(MDispatcher.Intervals) do
            local p1,p2
            if v[1] >= 0 then
                p1 = v[1] + 1
            else
                p1 = v[1]
            end
            if v[2] >= 0 then
                p2 = v[2] + 1
            else
                p2 = v[2]
            end
            MDispatcher.Intervals[k] = {p1, p2}
        end
    end
end)
