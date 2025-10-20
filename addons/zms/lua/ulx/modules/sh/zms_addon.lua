ZMS = ZMS or {}
local CATEGORY_NAME = "ZONT_ Metrostroi"

function ulx.RemoveDispRoute( ply, route, station )
    if not SERVER then return end
    local fl = file.Read("zms_disp_routes.json", "DATA")
    local base_tbl = fl and util.JSONToTable(fl) or {}
    if not base_tbl[game.GetMap()] then
        ply:ChatPrint("No routes found for this map")
        return
    end
    local tbl = base_tbl[game.GetMap()]

    local function rm(s, v)
        for idx, data in ipairs(v) do
            if data.route == route then
                table.remove(v, idx)
                file.Write("zms_disp_routes.json", util.TableToJSON(base_tbl, true))
                ZMS.UpdDispRoutes(true)
                ply:ChatPrint(string.format("Removed %s from station %s", route, s))
                return true
            end
        end
    end

    if station and #station > 0 then
        local v = nil
        for _, s in ipairs(tbl) do
            if s.name == station then
                v = s.routes
                break
            end
        end
        if not v then
            ply:ChatPrint(string.format("No routes found for station %s", station))
            return
        end
        if not rm(station.name, v) then
            ply:ChatPrint(string.format("No route %s found for station %s", route, station))
        end
    else
        local found = false
        for _, s in ipairs(tbl) do
            if rm(s.name, s.routes) then
                found = true
            end
        end
        if not found then
            ply:ChatPrint(string.format("No route %s found in any station", route))
        end
    end
end
local drouterm = ulx.command( CATEGORY_NAME, "ulx drouterm", ulx.RemoveDispRoute, "!drouterm" )
drouterm:addParam{ type=ULib.cmds.StringArg, hint="Route identifier" }
drouterm:addParam{ type=ULib.cmds.StringArg, hint="Station name", ULib.cmds.optional }
drouterm:defaultAccess( ULib.ACCESS_ADMIN )
drouterm:help( "Remove route/signal from dispatcher c-menu for this map" )

function ulx.AddDispRoute( ply, station_name, route, display_name, position )
    if not SERVER then return end
    local fl = file.Read("zms_disp_routes.json", "DATA")
    local base_tbl = fl and util.JSONToTable(fl) or {}
    if not base_tbl[game.GetMap()] then
        base_tbl[game.GetMap()] = {}
    end
    local tbl = base_tbl[game.GetMap()]
    local station = nil
    for _, s in ipairs(tbl) do
        if s.name == station_name then
            station = s
            break
        end
    end
    if not station then
        station = { name=station_name, routes={} }
        table.insert(tbl, station)
    end
    if position and position > 0 and (position == 1 or (#station.routes + 1) >= position) then
        table.insert(station.routes, position, { route=route, name=display_name or route })
    else
        table.insert(station.routes, { route=route, name=display_name or route })
    end
    file.Write("zms_disp_routes.json", util.TableToJSON(base_tbl, true))
    ZMS.UpdDispRoutes(true)
    ply:ChatPrint(string.format("Added %s to station %s", route, station.name))
end
local droute = ulx.command( CATEGORY_NAME, "ulx droute", ulx.AddDispRoute, "!droute" )
droute:addParam{ type=ULib.cmds.StringArg, hint="Station name" }
droute:addParam{ type=ULib.cmds.StringArg, hint="Route identifier" }
droute:addParam{ type=ULib.cmds.StringArg, hint="Display name", ULib.cmds.optional }
droute:addParam{ type=ULib.cmds.NumArg, hint="Insert at position", default=0, ULib.cmds.optional }
droute:defaultAccess( ULib.ACCESS_ADMIN )
droute:help( "Add route/signal to dispatcher c-menu for this map" )

function ulx.RemovePlayerTrains( ply, target_plys, silent )
    if not SERVER or not ZMS or not ZMS.Trains.RemovePly then return end
    for _, tgt in ipairs(target_plys) do
        ZMS.Trains.RemovePly(tgt, ply, silent)
    end
end
local rmtrains = ulx.command( CATEGORY_NAME, "ulx rmtrains", ulx.RemovePlayerTrains, "!rmtrains" )
rmtrains:addParam{ type=ULib.cmds.PlayersArg, default="^", hint="Target player" }
rmtrains:addParam{ type=ULib.cmds.BoolArg, hint="Silently", ULib.cmds.optional }
rmtrains:defaultAccess( ULib.ACCESS_ADMIN )
rmtrains:help( "Remove all trains of player" )

function ulx.RemoveTrains( ply, silent )
    if not SERVER or not ZMS or not ZMS.Trains.RemoveAny then return end
    ZMS.Trains.RemoveAny(ply, silent)
end
local rmanytrains = ulx.command( CATEGORY_NAME, "ulx rmanytrains", ulx.RemoveTrains, "!rmanytrains" )
rmanytrains:addParam{ type=ULib.cmds.BoolArg, hint="Silently", ULib.cmds.optional }
rmanytrains:defaultAccess( ULib.ACCESS_ADMIN )
rmanytrains:help( "Remove any trains on map (GUI)" )


function ulx.ExecuteAtz( ply, target, case_name, options )
    if not SERVER or not IsValid(target) or not ZMS or not ZMS.ATZ.Execute then return end
    local opts_list = options and #options > 0 and string.Split(options, " ") or {}
    local rear = false
    local all = false
    local count = nil
    for idx, opt in ipairs(opts_list) do
        local opl = string.lower(opt)
        if opl == "rear" or opl == "all" then
            rear = opl == "rear"
            all = not rear
            table.remove(opts_list, idx)
            break
        else
            local m = string.match(opl, "^w(%d)$")
            if m then
                count = tonumber(m)
                table.remove(opts_list, idx)
                break
            end
        end
    end
    ZMS.ATZ.Execute(target, string.lower(case_name), rear, all, count, opts_list)

    local opt_string = options and #options > 0 and (" " .. options) or ""
    ulx.logString(string.format("%s applied ATZ case %s%s on player %s", ply:Nick(),
        case_name, opt_string, target:Nick()), true)
    if IsValid(ply) and ply:IsPlayer() then
        ply:ChatPrint("Случай АТЗ применен")
        ply:ChatPrint(case_name .. opt_string)
    end
end
local atz_exec = ulx.command( CATEGORY_NAME, "ulx atz", ulx.ExecuteAtz, "!atz" )
atz_exec:addParam{ type=ULib.cmds.PlayerArg, default="^", hint="Target player" }
atz_exec:addParam{ type=ULib.cmds.StringArg, hint="Case Name" }
atz_exec:addParam{ type=ULib.cmds.StringArg, hint="Options...", ULib.cmds.optional, ULib.cmds.takeRestOfLine }
atz_exec:defaultAccess( ULib.ACCESS_ADMIN )
atz_exec:help( "Executes ATZ case" )

function ulx.RemoveAtzCases( ply, target )
    if not SERVER or not IsValid(target) or not ZMS or not ZMS.ATZ.ClearAll then return end
    ZMS.ATZ.ClearAll(target)
    if IsValid(ply) then
        if ply == target then
            ulx.fancyLog("#P очистил случаи АТЗ на своем составе", ply)
        else
            ulx.fancyLog("#P очистил случаи АТЗ на составе игрока #P", ply, target)
        end
    end
end
local atz_clear = ulx.command( CATEGORY_NAME, "ulx atzcl", ulx.RemoveAtzCases, "!atzcl" )
atz_clear:addParam{ type=ULib.cmds.PlayerArg, default="^", hint="Target player" }
atz_clear:defaultAccess( ULib.ACCESS_ADMIN )
atz_clear:help( "Resets any ATZ cases" )

local function get_restriction(case)
    if not istable(case.restrict_types) then return end
    local restr_desc = case.restrict_desc
    if not restr_desc then
        local restr_tbl = {}
        for _, v in ipairs(case.restrict_types) do
            if string.StartsWith(pattern, "~") then
                table.insert(restr_tbl, "НЕ " .. string.sub(v, 2))
            else
                table.insert(restr_tbl, v)
            end
        end
        return table.concat(restr_tbl, ", ")
    end
    return restr_desc
end
function ulx.AtzMenu( ply )
    if not SERVER or not IsValid(ply) then return end
    local train = ply:GetTrain()
    local tbl = {}
    for k, case in pairs(ZMS.ATZ.storage) do
        if case.desc then
            table.insert(tbl, {
                name = k,
                desc = case.desc,
                restriction = get_restriction(case),
                allowed = IsValid(train) and ZMS.ATZ.CheckRestrictions(train, case),
                per_wagon = not case.target_all_wagons and not case.target_opposite_wagon and not case.target_n_wagons
            })
        end
    end
    local data = util.Compress(util.TableToJSON(tbl))
    local ln = #data
    net.Start("ZMS.ATZ.MenuOpen")
        net.WriteUInt(ln, 16)
        net.WriteData(data, ln)
    net.Send(ply)
end
local atzmenu = ulx.command( CATEGORY_NAME, "ulx atzmenu", ulx.AtzMenu, "!atzmenu" )
atzmenu:defaultAccess( ULib.ACCESS_ADMIN )
atzmenu:help( "Открыть меню АТЗ" )


local function not_dispatcher(ply)
    return IsValid(ply) and not ply:IsAdmin() and ply:EntIndex() ~= GetGlobal2Int("ZMS.Radio.Dispatcher", 0) and
        not (MDispatcher and MDispatcher.Dispatcher == ply:Nick())
end

function ulx.ToggleImmersiveRadio( ply )
    if not SERVER or not IsValid(ply) and (not MDispatcher or MDispatcher.Dispatcher == "отсутствует") then return end
    if not_dispatcher(ply) then
        ply:ChatPrint("Ты не диспетчер.")
        return
    end

    local val = not GetGlobal2Bool("ZMS.Radio.Immersive", false)
    SetGlobal2Bool("ZMS.Radio.Immersive", val)
    local io_disp = not MDispatcher or MDispatcher.Dispatcher == "отсутствует"
    if io_disp then
        SetGlobal2Int("ZMS.Radio.Dispatcher", val and IsValid(ply) and ply:EntIndex() or 0)
    end
    if val and IsValid(ply) then
        ulx.fancyLog("ВНИМАНИЕ, МАШИНИСТЫ! #P включил режим иммерсивного радио на сервере. Подробная информация вверху экрана, или в С-Меню - Меню ДЦХ - Опции - Заметка о радио.", ply)
        if io_disp then
            ulx.fancyLog("#P является ИО диспетчера, пока не заступит основной.", ply)
        end
    end
end
local disp_immersive = ulx.command( CATEGORY_NAME, "ulx disp_immersive", ulx.ToggleImmersiveRadio, "!disp_immersive" )
disp_immersive:defaultAccess( ULib.ACCESS_ALL )
disp_immersive:help( "Включить иммерсивное радио на сервере" )

function ulx.DispMsg( ply, message )
    if not SERVER then return end
    if not_dispatcher(ply) then
        ply:ChatPrint("Ты не диспетчер.")
        return
    end

    if not message or #message == 0 then
        SetGlobal2String("ZMS.Radio.Message", "")
        if IsValid(ply) then
            ulx.fancyLog("#P очистил приоритетное сообщение диспетчера.", ply)
        else
            print("Cleared dispatcher message")
        end
        return
    end
    if IsValid(ply) and #message > 512 then
        if IsValid(ply) then
            ply:ChatPrint("Максимум 512 символов.")
        end
        return
    end
    SetGlobal2String("ZMS.Radio.Message", message)
    if IsValid(ply) then
        ulx.fancyLog("#P установил приоритетное сообщение диспетчера: #s", ply, message)
    else
        ulx.fancyLog("Установлено приоритетное сообщение диспетчера: #s", message)
    end
end
local disp_msg = ulx.command( CATEGORY_NAME, "ulx disp_msg", ulx.DispMsg, "!disp_msg" )
disp_msg:addParam{ type=ULib.cmds.StringArg, hint="Message", ULib.cmds.optional, ULib.cmds.takeRestOfLine }
disp_msg:defaultAccess( ULib.ACCESS_ALL )
disp_msg:help( "Задать приоритетное сообщение диспетчера" )

function ulx.AddRadio( ply, id, pos )
    if not SERVER or not ZMS or not ZMS.Radio or not ZMS.Radio.AddStation then return end
    ZMS.Radio.AddStation(id, pos and string.lower(pos) ~= "position" and Vector(pos) or ply:GetPos())
end
local add_rst = ulx.command( CATEGORY_NAME, "ulx rst_add", ulx.AddRadio, "!rst_add" )
add_rst:addParam{ type=ULib.cmds.NumArg, hint="Station ID" }
add_rst:addParam{ type=ULib.cmds.StringArg, hint="Position", ULib.cmds.optional, ULib.cmds.takeRestOfLine }
add_rst:defaultAccess( ULib.ACCESS_ADMIN )
add_rst:help( "Add a radio point (station)" )

function ulx.UpdRadio( )
    if not SERVER or not ZMS or not ZMS.Radio or not ZMS.Radio.ReloadStations then return end
    ZMS.Radio.ReloadStations()
end
local upd_rst = ulx.command( CATEGORY_NAME, "ulx rst_upd", ulx.UpdRadio, "!rst_upd" )
upd_rst:defaultAccess( ULib.ACCESS_ADMIN )
upd_rst:help( "Update radio points (stations) from data file" )

function ulx.EnablePersonalImmersive( ply )
    if not SERVER or not IsValid(ply) then return end
    ply:SetNW2Bool("ZMS.Radio.PersonalImmersive", not ply:GetNW2Bool("ZMS.Radio.PersonalImmersive", false))
end
local local_immersive = ulx.command( CATEGORY_NAME, "ulx local_immersive", ulx.EnablePersonalImmersive, "!local_immersive" )
local_immersive:defaultAccess( ULib.ACCESS_ALL )
local_immersive:help( "Включить иммерсивный режим радио для себя" )


if SERVER then
    ULib.ucl.registerAccess("zms_restrictions_ignore_ply", ULib.ACCESS_ADMIN, "Ignore wagon restrictions caused by player count", CATEGORY_NAME)
    ULib.ucl.registerAccess("zms_restrictions_remove_ur", ULib.ACCESS_ADMIN, "Mark player as NOT unranked", CATEGORY_NAME)
    ULib.ucl.registerAccess("zms_droute_menu", ULib.ACCESS_ADMIN, "Permanent full access to dispatcher routes c-menu", CATEGORY_NAME)
end
