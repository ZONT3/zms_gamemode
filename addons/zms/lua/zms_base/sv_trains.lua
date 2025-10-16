--[[
    Author: ZONT_ a.k.a. enabled person
    Description: API for retreiving information about Metrostroi trains and their owners.
]]

ZMS = ZMS or {}
ZMS.Trains = ZMS.Trains or {}
ZMS.Players = ZMS.Players or {}

ZMS.Trains.List = {}
ZMS.Trains.Cache = {}
ZMS.Players.TrainOwners = {}
ZMS.Players.WagonOwners = {}
ZMS.Players.Cache = {}

function ZMS.Trains.All()
    return ZMS.Trains.List
end

function ZMS.Players.AllWagons()
    local players_tbl = {}
    for ent_id, d in pairs(ZMS.Players.Cache) do
        players_tbl[d.steamid] = players_tbl[d.steamid] or {
            name = d.name,
            wagon_count = 0,
            wagons = {},
        }
        local ply_tbl = players_tbl[d.steamid]
        local wagon = Entity(ent_id)
        local wag_type
        if IsValid(wagon) then
            wag_type = wagon:GetClass()
        else
            wag_type = "Invalid"
        end
        ply_tbl.wagon_count = ply_tbl.wagon_count + 1
        table.insert(ply_tbl.wagons, string.format("%s (%s)", wag_type, ent_id))
    end

    return players_tbl
end

--[[
    Returns a train, that the wagon belongs to.
    @param wagon: The wagon entity to check.
    @return train: The train struct that the wagon belongs to
    @return idx: The index of the train in ZMS.Trains.List
    @return nothing if the wagon is invalid or not found in the cache.
]]
function ZMS.Trains.GetByWagon(wagon)
    if not ZMS.Trains.Cache or not ZMS.Trains.List or not IsValid(wagon) then
        return nil
    end
    local cached_idx = ZMS.Trains.Cache[wagon:EntIndex()]
    if cached_idx then
        return ZMS.Trains.List[cached_idx], cached_idx
    end
end

--[[
    Return most appropriate train owned by player, defined by following order of checks.
    If the player is driving a train owned by them, it will return that train.
    If the player has one or more owned trains, it will return the last one in the list.
    If the player is driving any train, it will return that train.
    Otherwise, nil is returned.
]]
function ZMS.Trains.GetByPlayer(ply)
    if not ZMS.Trains.Cache or not ZMS.Trains.List or not IsValid(ply) or not ply.GetTrain then
        return nil
    end

    local owned_trains = ZMS.Players.TrainOwners[ply:SteamID64()]
    local wagon = ply:GetTrain()
    local driving_train, driving_train_idx = nil, nil
    if IsValid(wagon) then
        driving_train, driving_train_idx = ZMS.Trains.GetByWagon(wagon)
        if driving_train_idx and #owned_trains < 1 or table.HasValue(owned_trains, driving_train_idx) then
            return driving_train, driving_train_idx
        end
    end
    if #owned_trains >= 1 then
        return ZMS.Trains.List[owned_trains[#owned_trains]], owned_trains[#owned_trains]
    end
    return nil
end

function ZMS.Trains.RemovePly(ply, inflictor_ply, silent)
    if not IsValid(ply) or not ply:IsPlayer() then
        ply:ChatPrint("Invalid player specified")
        return
    end
    if IsValid(inflictor_ply) and ply:IsAdmin() and not inflictor_ply:IsAdmin() then
        inflictor_ply:ChatPrint("You cannot remove trains of an admin.")
        return
    end
    for _, train in ipairs(ZMS.Trains.All()) do
        if train.owner_steamid == ply:SteamID64() then
            for _, wagon_entid in ipairs(train.wagons) do
                local wagon = Entity(wagon_entid)
                if IsValid(wagon) and wagon:IsValid() then
                    wagon:Remove()
                end
            end
        end
    end
    if IsValid(inflictor_ply) and not silent then
        ulx.fancyLog("#P удалил составы игрока #P", inflictor_ply, ply)
    elseif IsValid(inflictor_ply) then
        inflictor_ply:ChatPrint("Removed all trains of player " .. ply:Nick())
    end
end

function ZMS.Trains.RemoveAny(ply, silent)
    if not IsValid(ply) or not ply:IsPlayer() then
        ply:ChatPrint("Invalid player specified")
        return
    end
    local data = util.Compress(util.TableToJSON(ZMS.Trains.All and ZMS.Trains.All() or {}))
    local ln = #data
    net.Start("ZMS.Trains.ShowList")
        net.WriteUInt(ln, 32)
        net.WriteData(data, ln)
        net.WriteUInt(silent and ZMS.Trains.RM_SILENT or ZMS.Trains.RM, 16)
    net.Send(ply)
end


concommand.Add("zms_trains_ext", function()
    PrintTable(ZMS.Trains.All() or { message = "Failed" })
end)

concommand.Add("zms_wagons_ext", function()
    PrintTable(ZMS.Players.AllWagons() or { message = "Failed" })
end)

concommand.Add("zms_trains", function()
    local players_tbl = {}
    for _, train in ipairs(ZMS.Trains.All() or {}) do
        local owner = train.owner_name or "Unknown"
        local owner_steamid = train.owner_steamid or "Unknown"
        players_tbl[owner_steamid] = players_tbl[owner_steamid] or {
            name = owner,
            train_count = 0,
            wagon_count = 0,
            trains = {},
            owner_disconnected = train.owner_disconnected,
        }

        local ply_tbl = players_tbl[owner_steamid]
        ply_tbl.train_count = ply_tbl.train_count + 1
        ply_tbl.wagon_count = ply_tbl.wagon_count + #train.wagons
        ply_tbl.owner_disconnected = ply_tbl.owner_disconnected or train.owner_disconnected

        local station_str = train.position.station or string.format("%s - %s", train.position.prev_station or "N/A", train.position.next_station or "N/A")
        table.insert(
            ply_tbl.trains,
            string.format(
                "%s (%s wagons) [%s | Path %s] %s",
                train.head_type, #train.wagons,
                train.position.line or "N/A", train.position.path or "N/A", station_str
            )
        )
    end

    for steamid, data in pairs(players_tbl) do
        if #data.trains > 0 then
            local disconnected = data.owner_disconnected and " DISCONNECTED!" or ""
            print(string.format("Trains: %d\tWagons: %d\tOwner: %s (%s)%s",
                data.train_count, data.wagon_count, data.name, steamid, disconnected))
            for _, train_info in ipairs(data.trains) do
                print("  - " .. train_info)
            end
        end
    end
end)


--[[
    Private part of the module
]]

local TrainClasses = nil

local hundreds_routes = {
    ["gmod_subway_em508"] = true,
    ["gmod_subway_81-702"] = true,
    ["gmod_subway_81-703"] = true,
    ["gmod_subway_81-705_old"] = true,
    ["gmod_subway_ezh"] = true,
    ["gmod_subway_ezh3"] = true,
    ["gmod_subway_ezh3ru1"] = true,
    ["gmod_subway_81-717_mvm"] = true,
    ["gmod_subway_81-718"] = true,
    ["gmod_subway_81-720"] = true,
    ["gmod_subway_81-720_1"] = true,
    ["gmod_subway_81-720a"] = true,
    ["gmod_subway_81-717_freight"] = true,
    ["gmod_subway_81-717_5a"] = true,
    ["gmod_subway_81-717_5m"] = true,
    ["gmod_subway_81-717_ars_minsk"] = true,
}

local function FindRouteNumber(wagon)
    local route = -3
    local class = wagon:GetClass()

    if class:find("722") or class:find("7175p") then
        if wagon.RouteNumberSys then
            route = wagon.RouteNumberSys.CurrentRouteNumber
        end
    elseif class:find("717_6") or class:find("740_4") then
        if wagon.ASNP then
            route = wagon.ASNP.RouteNumber
        end
    else
        if wagon.RouteNumber then
            route = wagon.RouteNumber.RouteNumber
        end
    end

    local result = -3
    if class ~= "-" and route ~= "-" and (not isnumber(route) or route > 0) then
        local rnum = tonumber(route)
        if hundreds_routes[class] then rnum = rnum / 10 end
        result = rnum
    end
    return math.floor(tonumber(result))
end

local function GetLocation(pos)
    local station = 0
    local radius2 = 4000 * 4000
    if not Metrostroi.StationConfigurations then return station end

    for k, v in pairs(Metrostroi.StationConfigurations) do
        if v.names[1] == "ДДЭ" or v.names[1] == "Диспетчерская" then continue end

        local map_pos
        if isnumber(k) and v.positions[2] then
            map_pos = v.positions and v.positions[2]
        else
            map_pos = v.positions and v.positions[1]
        end

        if map_pos then
            local z_dist = 250
            if (pos.z > 0 and map_pos[1].z < 0) or (pos.z < 0 and map_pos[1].z > 0) then
                z_dist = math.abs(pos.z) + math.abs(map_pos[1].z)
            end
            if (pos.z > 0 and map_pos[1].z > 0) or (pos.z < 0 and map_pos[1].z < 0) then
                z_dist = math.abs(pos.z - map_pos[1].z)
            end
            if z_dist < 220 then
                local cur_dist2 = pos:DistToSqr(map_pos[1])
                if cur_dist2 < radius2 then
                    station = k
                    radius2 = cur_dist2
                end
            end
        end
    end
    return station
end

local function GetStationName(station)
    if
        station > 0 and
        Metrostroi.StationConfigurations and
        Metrostroi.StationConfigurations[station] and
        Metrostroi.StationConfigurations[station].names[1]
    then
        return Metrostroi.StationConfigurations[station].names[1]
    end
    return "Неизвестно"
end

local function GetLine(wagon, station)
    local announcer_val = wagon:GetNW2Int("Announcer", 1)
    local cfg = Metrostroi.ASNPSetup and Metrostroi.ASNPSetup[announcer_val]
    if not cfg then cfg = Metrostroi.ASNPSetup[1] end
    if not cfg then return nil end
    for _, cfgi in pairs(cfg) do
        for _, st in ipairs(istable(cfgi) and cfgi or {}) do
            if st[1] == station then
                return cfgi.Name or nil
            end
        end
    end
    return nil
end

function ZMS.Trains.GetPosition(wagon)
    local prev_st = 0
    local cur_st = 0
    local next_st = 0
    local path = 0

    cur_st = wagon:ReadCell(49160)
    if cur_st > 0 then
        path = wagon:ReadCell(49168)
    else
        prev_st = wagon:ReadCell(49162)
        next_st = wagon:ReadCell(49161)
        if prev_st > 0 and next_st > 0 then
            path = wagon:ReadCell(49167)
        else
            cur_st = GetLocation(wagon:GetPos())
        end
    end

    return {
        line = GetLine(wagon, isnumber(cur_st) and cur_st > 0 and cur_st or next_st > 0 and next_st or prev_st),
        station = isnumber(cur_st) and cur_st > 0 and GetStationName(cur_st) or isstring(cur_st) and cur_st or nil,
        prev_station = prev_st > 0 and GetStationName(prev_st) or nil,
        next_station = next_st > 0 and GetStationName(next_st) or nil,
        path = path > 0 and path < 3 and path or 0,
    }
end

local function TrainsUpdate()
    if not Metrostroi or not Metrostroi.SpawnedTrains or not TrainClasses then return end

    local wagons = {}
    local trains = {}
    local trains_cache = {}

    local wagon_owners = {}
    local train_owners = {}
    local owners_cache = {}

    for ent in pairs(Metrostroi.SpawnedTrains) do
        if IsValid(ent) and TrainClasses[ent:GetClass()] and not wagons[ent:EntIndex()] then
            if not ent.WagonList or #ent.WagonList < 1 then
                zms_err("Status.Trains", "Wagon %s (%s) has no WagonList!", ent:GetClass(), ent:EntIndex())
                continue
            end

            local heads = {}
            local inters = {}
            local train_wagons = {}
            local types = {}

            local position = nil
            local route_number = -2

            local head_type = "unknown"
            local head_owner = nil
            local head_owner_name = nil
            local head_owner_disconnected = false
            local head_owner_isadmin = false
            local found_owner_seated = nil
            local failed = false

            for idx, wagon in ipairs(ent.WagonList) do
                if not IsValid(wagon) then
                    zms_err("Status.Trains", "Wagon %s (%s) has invalid wagon in its trainset!",
                        ent:GetClass(), ent:EntIndex()
                    )
                    failed = true
                    break
                end

                local ent_id = wagon:EntIndex()
                local is_head = idx == 1 or idx == #ent.WagonList

                if is_head then
                    if head_type == "unknown" then
                        head_type = wagon:GetClass()
                    end
                    table.insert(heads, ent_id)
                else
                    table.insert(inters, ent_id)
                end
                wagons[ent_id] = true
                types[idx] = wagon:GetClass()
                train_wagons[idx] = ent_id

                local steamid, name, owner_seated
                local ply = wagon.Owner
                if IsValid(ply) then
                    steamid = ply:SteamID64()
                    name = ply:Nick()
                    owner_isadmin = ply:IsAdmin() and true or false
                    owner_seated = ply.GetTrain and ply:GetTrain() == wagon or false
                    if owner_seated then
                        found_owner_seated = true
                    end
                else
                    local cached = ZMS.Players.Cache and ZMS.Players.Cache[ent_id] or nil
                    steamid = cached and cached.steamid or "unknown"
                    name = cached and cached.name or "unknown"
                    owner_seated = cached and cached.owner_seated or false
                    ply = player.GetBySteamID64(steamid)
                    owner_isadmin = IsValid(ply) and ply:IsAdmin() or cached.isadmin or false
                    if IsValid(ply) then
                        wagon.Owner = ply
                    end
                end

                local cached = ZMS.Players.Cache and ZMS.Players.Cache[ent_id] or nil
                if cached and not owner_seated and not found_owner_seated and cached.owner_seated then
                    owner_seated = true
                end

                owners_cache[ent_id] = { steamid = steamid, name = name, owner_seated = owner_seated, isadmin = owner_isadmin }
                if is_head and (owner_seated or not head_owner or route_number < 0) then
                    head_owner = steamid
                    head_owner_name = name
                    head_owner_disconnected = not IsValid(ply)
                    head_owner_isadmin = owner_isadmin
                    route_number = FindRouteNumber(wagon)
                    position = ZMS.Trains.GetPosition(wagon)
                end
                wagon_owners[steamid] = wagon_owners[steamid] or {}
                table.insert(wagon_owners[steamid], ent_id)
            end

            if not failed then
                local train = {
                    heads = heads,
                    inters = inters,
                    wagons = train_wagons,
                    head_type = head_type,
                    types = types,
                    owner_steamid = head_owner,
                    owner_name = head_owner_name,
                    owner_disconnected = head_owner_disconnected,
                    owner_isadmin = head_owner_isadmin,
                    route_number = route_number,
                    position = position,
                }
                table.insert(trains, train)

                for _, ent_id in ipairs(train.wagons) do
                    trains_cache[ent_id] = #trains
                end

                if head_owner then
                    train_owners[head_owner] = train_owners[head_owner] or {}
                    table.insert(train_owners[head_owner], #trains)
                end

            else
                zms_err("Status.Trains", "Wagon %s (%s) has invalid trainset!", ent:GetClass(), ent:EntIndex())
            end
        end
    end

    ZMS.Trains.List = trains
    ZMS.Trains.Cache = trains_cache
    ZMS.Players.TrainOwners = train_owners
    ZMS.Players.WagonOwners = wagon_owners
    ZMS.Players.Cache = owners_cache
end

timer.Create("ZMS.Trains.Init", 0.5, 20, function()
    if not Metrostroi or not Metrostroi.TrainClasses then return end
    local classes = {}
    for _, class in pairs(Metrostroi.TrainClasses) do
        classes[class] = true
    end
    TrainClasses = classes
    timer.Create("ZMS.Trains.Updater", 3, 0, TrainsUpdate)
    timer.Remove("ZMS.Trains.Init")
    timer.Remove("ZMS.Trains.Init.FailCheck")
    zms_log("Status.Trains", "Metrostroi train classes initialized successfully.")
end)

timer.Create("ZMS.Trains.Init.FailCheck", 12, 1, function()
    if not TrainClasses then
        zms_err("Status.Trains", "Failed to initialize Metrostroi train classes. Module DISABLED.")
    end
end)

util.AddNetworkString("ZMS.Trains.ShowList")
util.AddNetworkString("ZMS.Trains.Teleport")
util.AddNetworkString("ZMS.Trains.Remove")

net.Receive("ZMS.Trains.Teleport", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply:SetPos(net.ReadVector())
end)

net.Receive("ZMS.Trains.Remove", function(len, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local ln = net.ReadUInt(32)
    local data = net.ReadData(ln)
    local silent = net.ReadBool()
    local train_data = util.Decompress(data)
    local wagons = string.Explode(",", train_data)
    if not wagons or #wagons < 1 then
        ply:ChatPrint("Invalid train data received.")
        return
    end
    local invalid = 0
    for _, wag_entid in ipairs(wagons) do
        local wagon = Entity(tonumber(wag_entid))
        if IsValid(wagon) then
            wagon:Remove()
        else
            invalid = invalid + 1
        end
    end
    if not silent then
        ulx.fancyLog("#P удалил #s вагон(-а/-ов)", ply, #wagons)
    else
        ply:ChatPrint("Removed " .. (#wagons - invalid) .. " wagon(s).")
    end
end)

hook.Add("CanProperty", "ZMS.Trains.Restrictions.ContextMenuAction", function(ply, pr, ent, property)
    if not IsValid(ent) then return end
    if ply:IsAdmin() then return end
    local cls = ent:GetClass()

    if not string.StartsWith(cls, "gmod_subway_") then return end
    local train = ZMS.Trains.GetByWagon(ent)
    if not train then return end
    if train.owner_isadmin and not ply:IsAdmin() then
        ply:ChatPrint("You cannot perform any action on a train owned by an admin.")
        return false
    end
end)

hook.Add("CanTool", "ZMS.Trains.Restrictions.ToolGun", function(ply, tr, toolname, tool, button)
    if ply:IsAdmin() then return end
    if toolname ~= "remover" then return end
    local cls = IsValid(tr.Entity) and tr.Entity:GetClass() or "unknown"

    if not string.StartsWith(cls, "gmod_subway_") then return end
    local train = ZMS.Trains.GetByWagon(tr.Entity)
    if not train then return end
    if train.owner_isadmin and not ply:IsAdmin() then
        ply:ChatPrint("You cannot remove a train owned by an admin.")
        return false
    end
end)
