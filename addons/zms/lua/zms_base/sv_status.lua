--[[
    Author: ZONT_ a.k.a. enabled person
    Description: API for retreiving information about the server, Metrostroi trains, stations and players.
]]

ZMS = ZMS or {}
ZMS.Status = ZMS.Status or {}

local function toHEX(color)
    return string.format("#%02x%02x%02x", color.r, color.g, color.b)
end

function ZMS.Status.Get()
    return {
        uptime = math.floor(RealTime()),
        svtime = math.floor(os.time() * 1000),
        max_wagons = ZMS.Status.GetMaxWagons(),
        map = game.GetMap(),
        players = ZMS.Status.GetPlayers(),
        asnp_list = ZMS.Status.GetAsnpList(),
        stations = ZMS.Status.GetStations(),
    }
end


function ZMS.Status.GetMaxWagons()
    local zms_convar = GetConVar("zms_wagons_softmax")
    if zms_convar then
        return zms_convar:GetInt()
    end

    return GetConVar("metrostroi_maxwagons"):GetInt() * GetConVar("metrostroi_maxtrains"):GetInt()
end


function ZMS.Status.GetPlayers()
    local trains = ZMS.Trains.All()
    local players = {}

    for idx, train in ipairs(trains) do
        local ply = player.GetBySteamID64(train.owner_steamid)
        local session_time = ply and ply:TimeConnected() or 0
        local ply_data = players[train.owner_steamid]
        if not ply_data then
            players[train.owner_steamid] = {
                steamid = train.owner_steamid or "invalid",
                name = train.owner_name or "Unknown",
                rank = ply and team.GetName(ply:Team()) or "disconnected",
                color = ply and toHEX(team.GetColor(ply:Team())) or "#cccccc",
                current_role = train.owner_name == (MDispatcher and MDispatcher.Dispatcher) and "dispatcher" or nil,
                session_time = math.floor(session_time),
                active_train = nil,
                trains = {},
            }
            ply_data = players[train.owner_steamid]
        end

        table.insert(ply_data.trains, train)
        if not ply_data.active_train and ply then
            local wagon = ply:GetTrain()
            if IsValid(wagon) then
                local _, driving_train_idx = ZMS.Trains.GetByWagon(wagon)
                if driving_train_idx and driving_train_idx == idx then
                    ply_data.active_train = #ply_data.trains
                end
            end
        end
    end

    for _, ply in player.Iterator() do
        local steamid = ply:SteamID64()
        if not players[steamid] then
            players[steamid] = {
                steamid = steamid,
                name = ply:Nick(),
                rank = team.GetName(ply:Team()),
                color = toHEX(team.GetColor(ply:Team())),
                current_role = ply:Nick() == (MDispatcher and MDispatcher.Dispatcher) and "dispatcher" or nil,
                session_time = math.floor(ply:TimeConnected()),
                active_train = nil,
                trains = {},
            }
        end
    end

    players = table.ClearKeys(players)
    table.sort(players, function(a, b)
        return a.session_time > b.session_time
    end)

    return players
end


function ZMS.Status.GetAsnpList()
    -- TODO
    return {}
end


function ZMS.Status.GetStations()
    -- TODO
    return {}
end

util.AddNetworkString("ZMS.Players.UpdPosition")
timer.Create("ZMS.Players.UpdPosition", 5, 0, function()
    for _, ply_data in ipairs(ZMS.Status.GetPlayers()) do
        local ply = player.GetBySteamID64(ply_data.steamid)
        local train = ply_data.active_train and ply_data.trains and ply_data.trains[ply_data.active_train] or nil
        local pos, ln
        if ply and train and train.position then
            pos = util.Compress(util.TableToJSON(train.position))
            ln = #pos
        elseif ply then
            pos = util.Compress(util.TableToJSON({}))
            ln = #pos
        end
        if ply then
            net.Start("ZMS.Players.UpdPosition")
                net.WriteUInt(ln, 16)
                net.WriteData(pos, ln)
            net.Send(ply)
        end
    end
end)
