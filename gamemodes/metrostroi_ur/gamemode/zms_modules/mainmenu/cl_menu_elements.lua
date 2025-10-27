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

hook.Add("ZMS.PauseMenu.InitMenu", "ZMS.PauseMenu.InitMenu.Main", function(menu_panel)
    for _, button in ipairs(mainmenu_buttons) do
        if not istable(button) then
            if button == SPACER then
                local p = menu_panel:Add("Panel")
                p:SetTall(16)
                menu_panel:SetupElement(p)
            elseif button == TABS then
                menu_panel:AddTabsButtons()
            end
        else
            local pnl = menu_panel:AddButton()
            pnl:SetText(button[1])
            pnl.DoClick = button[2]
        end
    end
end)
