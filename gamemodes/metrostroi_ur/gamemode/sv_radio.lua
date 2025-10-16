local range_cvar = CreateConVar("zms_radio_use_range", "180", FCVAR_ARCHIVE, "Distance of hearable radio sound", 10, 500)
-- local prox_range_cvar = CreateConVar("zms_proximity_chat_distance", "700", FCVAR_ARCHIVE, "Distance of hearable radio sound", 100, 1500)

util.AddNetworkString("ZMS.Radio.ToggleMode")

hook.Add("PlayerButtonDown", "ZMS.Radio.Transmit.Down", function(ply, button)
    local ptt = ply:GetInfoNum("zms_radio_ptt_mode", 0) == 0
    if ptt then
        local shift = ply:GetInfoNum("zms_radio_key", 0) == 0
        if shift and (button == KEY_LSHIFT or button == KEY_RSHIFT) then
            ply:SetNW2Bool("ZMS.Radio.Transmitting", true)
        elseif not shift and (button == KEY_LALT or button == KEY_RALT) then
            ply:SetNW2Bool("ZMS.Radio.Transmitting", true)
        end
    else
        local key = ply:GetInfoNum("zms_radio_toggle_key", 0)
        if key == 0 then return end
        if key == button then
            net.Start("ZMS.Radio.ToggleMode")
            net.Send(ply)
        end
    end
end)

hook.Add("PlayerButtonUp", "ZMS.Radio.Transmit.Up", function(ply, button)
    local shift = ply:GetInfoNum("zms_radio_key", 0) == 0
    if shift and (button == KEY_LSHIFT or button == KEY_RSHIFT) then
        ply:SetNW2Bool("ZMS.Radio.Transmitting", false)
    elseif not shift and (button == KEY_LALT or button == KEY_RALT) then
        ply:SetNW2Bool("ZMS.Radio.Transmitting", false)
    end
end)

hook.Add("MDispatcher.TookPost", "ZMS.Radio.DispatcherUpdate", function(name)
    if not SERVER then return end
    local ply = nil
    for _, p in player.Iterator() do
        if p:Nick() == name then
            ply = p
        end
    end
    SetGlobal2Int("ZMS.Radio.Dispatcher", IsValid(ply) and ply:EntIndex() or 0)
end)

hook.Add("MDispatcher.FreedPost", "ZMS.Radio.DispatcherUpdateFree", function(name)
    if not SERVER then return end
    SetGlobal2Int("ZMS.Radio.Dispatcher", 0)
    SetGlobal2Bool("ZMS.Radio.Immersive", false)
    -- ulx.fancyLog("Иммерсивный режим радио выключен, так как диспетчер покинул пост.")
end)

local function get_station(wagon)
    local cur_st = wagon:ReadCell(49160) % 100
    local prev_st = wagon:ReadCell(49162) % 100
    local next_st = wagon:ReadCell(49161) % 100
    if prev_st > 0 and next_st > 0 and math.abs(prev_st - next_st) <= 2 then
        return (prev_st + next_st) / 2
    end
    return cur_st >= 0 and cur_st or next_st >= 0 and next_st or prev_st >= 0 and prev_st or 0
end

local function radio_active(wagon)
    if wagon.PUAV and wagon.VB then
        if wagon.VB.Value > 0 then
            return true
        end
    elseif wagon.RVS then
        if wagon.RVS.State > 0 then
            return true
        end
    elseif wagon.Panel and wagon.Panel.RST then
        if wagon.Panel.RST > 0 then
            return true
        end
    elseif wagon.Panel and wagon.Panel.VPR then
        if wagon.Panel.VPR > 0 then
            return true
        end
    elseif string.find(wagon:GetClass(), "22_new") then
        if wagon.Electric.Power > 0 and (wagon.SF17.Value + wagon.SF18.Value) > 0 then
            return true
        end
    elseif string.find(wagon:GetClass(), "722") then
        if wagon.Electric.Power > 0 and (wagon.SF14.Value + wagon.SF15.Value) > 0 then
            return true
        end
    elseif wagon.SF9 and wagon.Battery then
        if wagon.SF9.Value * wagon.Battery.Value > 0 then
            return true
        end
    end
    return false
end

ZMS.Radio = ZMS.Radio or {}
ZMS.Radio.Stations = {}

function ZMS.Radio.AddStation(id, pos)
    local data = util.JSONToTable(file.Read("zms_radio_stations.json") or "{}") or {}
    data[game.GetMap()] = data[game.GetMap()] or {}
    table.insert(data[game.GetMap()], {id = id, pos = pos})
    ZMS.Radio.Stations = data[game.GetMap()]
    file.Write("zms_radio_stations.json", util.TableToJSON(data, true))
end

function ZMS.Radio.ReloadStations()
    local data = util.JSONToTable(file.Read("zms_radio_stations.json") or "{}") or {}
    ZMS.Radio.Stations = data[game.GetMap()] or {}
end

hook.Add("Initialize", "ZMS.Radio.LoadStations", ZMS.Radio.ReloadStations)

local z_far_vector = Vector(1, 1, 10)
local function find_radio(ply)
    local range = range_cvar:GetInt()
    local range2 = range * range

    local station = -1
    local train = ply:GetTrain()
    if IsValid(train) and radio_active(train) then
        station = get_station(train)
        if station > 0 then return station end
    end

    local ply_pos = ply:GetPos() * z_far_vector

    local ent_list = ents.FindInSphere(ply:GetPos(), range)
    table.sort(ent_list, function(a, b)
        local av = a:GetPos() * z_far_vector
        local bv = b:GetPos() * z_far_vector
        return ply_pos:DistToSqr(av) < ply_pos:DistToSqr(bv)
    end)
    for _, ent in ipairs(ent_list) do
        if string.StartsWith(ent:GetClass(), "gmod_subway_") and radio_active(ent) then
            local s = get_station(ent)
            if s > 0 then return s end
            if s == 0 then station = 0 end
        end
    end

    local stations = {}
    for _, st in ipairs(ZMS.Radio.Stations) do
        local dist = ply_pos:DistToSqr(st.pos * z_far_vector)
        if dist <= range2 then
            table.insert(stations, {id = st.id, dist = dist})
        end
    end
    table.sort(stations, function(a, b) return a.dist < b.dist end)
    if #stations > 0 then
        return stations[1].id % 100
    end
    return station
end

local function is_transmitting(ply)
    local ptt_mode = ply:GetInfoNum("zms_radio_ptt_mode", 0)
    if ptt_mode > 0 then
        return ptt_mode == 1
    end
    return ply:GetNW2Bool("ZMS.Radio.Transmitting", false)
end

timer.Create("ZMS.Radio.StationUpdate", 1, 0, function()
    for _, ply in player.Iterator() do
        if not ply:Alive() then
            ply:SetNW2Float("ZMS.Radio.OnStation", -1)
            ply:SetNW2Bool("ZMS.Radio.Transmitting", false)
            continue
        end
        local station = find_radio(ply)
        ply:SetNW2Float("ZMS.Radio.OnStation", station)
    end
end)

hook.Add("PlayerCanHearPlayersVoice", "ZMS.Radio.VoiceChat", function(ply_l, ply_t)
    if not GetGlobal2Bool("ZMS.Radio.Immersive", false) then
        if ply_t:GetNW2Bool("ZMS.Radio.PersonalImmersive", false) then
            local talking_station = ply_t:GetNW2Float("ZMS.Radio.OnStation", -1)
            if talking_station >= 0 and ply_t:GetNW2Bool("ZMS.Radio.Transmitting", false) then
                return true
            end
            return true, true
        end
        return
    end

    local talking_dispatcher = ply_t:EntIndex() == GetGlobal2Int("ZMS.Radio.Dispatcher", 0)
    local talking_station = ply_t:GetNW2Float("ZMS.Radio.OnStation", -1)
    local talking_transmitting = is_transmitting(ply_t) and (talking_station >= 0 or talking_dispatcher)

    if talking_transmitting then
        local listener_dispatcher = ply_l:EntIndex() == GetGlobal2Int("ZMS.Radio.Dispatcher", 0)
        if listener_dispatcher then
            return true
        end
        local listener_station = ply_l:GetNW2Float("ZMS.Radio.OnStation", -1)
        if listener_station >= 0 and (talking_dispatcher or math.abs(listener_station - talking_station) <= 1.5) then
            return true
        end
    end

    return true, true
end)

hook.Add("PlayerSay", "ZMS.Radio.TextChat", function(ply, text)
    if not GetGlobal2Bool("ZMS.Radio.Immersive", false) then return end
    local radio = ply:EntIndex() == GetGlobal2Int("ZMS.Radio.Dispatcher", 0) or ply:GetNW2Float("ZMS.Radio.OnStation", -1) >= 0
    local prefix = radio and "*p* " or "(ooc) "
    return prefix .. text
end)
