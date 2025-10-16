ZMS = ZMS or {}

local headbgc, bodybgc = Color(234,237,255), Color(255,255,255)

local function ToggleRoute(open, route)
    local cmd = open and "sopen" or "sclose"
    local routes = string.Split(route, ",")
    for idx, r in ipairs(routes) do
        timer.Simple((idx - 1) * 0.1, function()
            RunConsoleCommand("ulx", cmd, r)
        end)
    end
end

local function is_signal(route)
    local route_name_lower = string.lower(route.name)
    return (
        string.StartsWith(route_name_lower, "[с") or -- Cyrillic letter
        string.StartsWith(route_name_lower, "[С") or -- Cyrillic letter
        string.StartsWith(route_name_lower, "[c") or -- Latin letter
        string.StartsWith(route_name_lower, "[s")
    )
end

local function create_header(parent, title, min_wide)
    min_wide = min_wide or 20

    parent:AddSpacer()

    local header = vgui.Create( "DPanel", parent )
    header:SetSize(math.max(parent:GetWide(), min_wide), 20 )
    header.Paint = function(self, w,h)
        draw.RoundedBox(0,0,0,w,h,headbgc)
    end
    local header_label = vgui.Create("DLabel", header)
    header_label:SetTextColor(Color(87,87,87))
    header_label:Dock(FILL)
    header_label:SetText(" " .. title)

    parent:AddPanel(header)
    parent:AddSpacer()
end

local function add_route(sm, route)
    local rm = sm:AddSubMenu(string.gsub(route.name, "^%s*%[.+%]%s*", ""), function()
        ToggleRoute(true, route.route)
    end)
    rm:AddOption("Открыть", function()
        ToggleRoute(true, route.route)
    end):SetImage("icon16/bullet_green.png")
    rm:AddOption("Закрыть", function()
        ToggleRoute(false, route.route)
    end):SetImage("icon16/bullet_red.png")
    create_header(rm, route.route)
end

function ZMS.OpenDispRoutesMenu(tbl, is_dispatcher)
    local empty = true
    if is_dispatcher or not MDispatcher or MDispatcher.Dispatcher == "отсутствует" then
        for _, station in ipairs(tbl) do
            local routes = station.routes or {}
            if #routes > 0 then
                empty = false
                break
            end
        end
    end

    local cm = DermaMenu(true)
    cm.Paint = function(self, w,h)
        draw.RoundedBox(0,0,0,w,h,bodybgc)
    end

    create_header(cm, "Меню ДЦХ и Радио", 210)

    if not empty then
        local cmr = cm:AddSubMenu("Маршруты")
        cmr.DoClick = function() end
        for _, station in ipairs(tbl) do
            local routes = station.routes or {}
            if #routes > 0 then
                local sm = cmr:AddSubMenu(station.name or "???")
                sm.DoClick = function() end
                if is_dispatcher then
                    create_header(sm, "Сигналы")
                    for _, route in ipairs(routes) do
                        if is_signal(route) then
                            add_route(sm, route)
                        end
                    end
                end
                create_header(sm, "Маршруты")
                for _, route in ipairs(routes) do
                    if not is_signal(route) then
                        add_route(sm, route)
                    end
                end
            end
        end
    end

    hook.Run("ZMS.Disp.CMenu", cm, is_dispatcher)

    local copt = cm:AddSubMenu("Опции")
    hook.Run("ZMS.Disp.CMenu.ClientOptions", copt, is_dispatcher)
    local op_asnp = copt:AddOption("Мониторинг АСНП", function() if ZMS and ZMS.ASNP then ZMS.ASNP.HudEnabled = not ZMS.ASNP.HudEnabled end end)
    local asnp_enabled = ZMS and ZMS.ASNP and ZMS.ASNP.HudEnabled
    op_asnp:SetIcon(asnp_enabled and "icon16/tick.png" or "icon16/cross.png")

    cm:Open(0, 140)
end

concommand.Add("zms_disp_routes", function()
    local permission = ULib.ucl.query(LocalPlayer(), "droute_menu")
    ZMS.OpenDispRoutesMenu(ZMS.DispRoutesTbl or {}, permission or not MDispatcher or MDispatcher.Dispatcher == LocalPlayer():Nick())
end)

hook.Add("OnContextMenuOpen", "ZMS.CtxMenu.DispRoutes", function()
    LocalPlayer():ConCommand("zms_disp_routes")
end)

local function UpdDispRoutes()
    net.Start("ZMS.DispRoutes")
    net.SendToServer()
end

timer.Create("ZMS.DispRoutesUpdate", 15, 0, UpdDispRoutes)
timer.Simple(1, UpdDispRoutes)

net.Receive("ZMS.DispRoutes", function()
    ZMS.DispRoutesTbl = net.ReadTable()
end)
