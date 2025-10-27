ZMS = ZMS or {}
ZMS.PauseMenu = ZMS.PauseMenu or {}

function ZMS.PauseMenu.RegisterHtmlTab(identifier, display_name, default_html, priority)
    if CLIENT then
        hook.Add("ZMS.PauseMenu.InitTabs", "ZMS.PauseMenu.InitTabs.RegisteredHtml." .. identifier, function(menu_panel, prepare_html)
            menu_panel:AddMenuTab(display_name, function(root)
                local pnl = root:Add("DHTML")
                prepare_html(pnl, identifier)
                return pnl
            end, priority)
        end)
    end

    if SERVER then
        ZMS.PauseMenu.SvRegisterHtmlTab(identifier, default_html)
    end
end
