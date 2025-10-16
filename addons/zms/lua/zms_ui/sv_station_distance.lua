ZMS_FWSS_CORRECTIONS = {
    ["gm_metro_minsk_1984"] = {
        [-111] = 4.10, -- global for map
    },
    ["gm_metro_kaluzhskaya_line6"] = {
        [-111] = 5.80, -- global for map
    },
    ["gm_metro_kalinin_v3"] = {
        [-111] = -0.30, -- global for map
    },
    ["gm_metro_mpl_v1"] = {
        [-111] = 0.50, -- global for map
    },
}

ZMS_STATION_NAMES = {
    ["gm_metro_jar_imagine_line_v4"] = {
        [801] = "Проспект Энергетиков",
    }
}

local map_corrections = ZMS_FWSS_CORRECTIONS[game.GetMap()]

local function get_station_name(station_id, locale_id)
    if ZMS_STATION_NAMES[game.GetMap()] and ZMS_STATION_NAMES[game.GetMap()][station_id] then
        return ZMS_STATION_NAMES[game.GetMap()][station_id]
    end
    if Metrostroi.StationConfigurations and Metrostroi.StationConfigurations[station_id] then
        local value = Metrostroi.StationConfigurations[station_id].names[locale_id or 1]
        if value then return value end
        local fallback = Metrostroi.StationConfigurations[station_id].names[1]
        if fallback then return fallback end
    end
    return nil
end

local function find_fwss_dist(ply, train)
    local ply_pos = ply:GetPos()
    local found = ents.FindInSphere(ply_pos, 800)
    local nearest_ent = nil
    local nearest_val = -1
    for idx, ent in ipairs(found) do
        if IsValid(ent) and ent:GetClass() == "gmod_track_pa_marker" then
            local dist = ent:GetPos():Distance(ply_pos)
            if not IsValid(nearest_ent) or dist < nearest_val then
                nearest_val = dist
                nearest_ent = ent
            end
        end
    end

    local train_pos = Metrostroi.TrainPositions[train]
    if train_pos then train_pos = train_pos[1] end

    if train_pos and nearest_ent and nearest_ent.TrackX and train_pos.x then
        local cls = train:GetClass()
        if cls:find("722") then
            return nearest_ent.TrackX - train_pos.x - 3.2
        end
        if cls:find("760") then
            return nearest_ent.TrackX - train_pos.x - 3.75
        end
        return nearest_ent.TrackX - train_pos.x - 3 -- Тестировалось на 81-717, магическое число для него: 3
    end
end

local next_check = -1

hook.Add("Think", "ZMS.StationDistanceListener", function()
    if CurTime() < next_check then return end

    for _, ply in player.Iterator() do
        if not ply.GetTrain then return end
        local train = ply:GetTrain()
        if not train or not IsValid(train) then continue end
        local distance = train:ReadCell(49165) - 7
        if distance == -7 or distance > 5500 then
            ply:SetNW2String("ZMS.CurrentTrain.ApproachingStationName", "")
            continue
        end

        local station = train:ReadCell(49161)
        local station_name = get_station_name(station)
        if not station_name or station_name == "" then
            local orig_station = station
            station = train:ReadCell(49160)
            station_name = get_station_name(station)
            if not station_name or station_name == "" then
                station_name = string.format("UNKNOWN (%d, %d)", orig_station, station)
            end
        end

        local is_precise = false
        if distance < 15 then
            local precise_dist = find_fwss_dist(ply, train)
            if precise_dist then
                distance = precise_dist
                is_precise = true
            end
        end

        if map_corrections then
            if map_corrections[station] then
                distance = distance + map_corrections[station]
            elseif map_corrections[-111] then
                distance = distance + map_corrections[-111]
            end
        end

        ply:SetNW2Bool("ZMS.CurrentTrain.ToFWSS.Precise", is_precise)
        ply:SetNW2Float("ZMS.CurrentTrain.ToFWSS", distance)
        ply:SetNW2String("ZMS.CurrentTrain.ApproachingStationName", station_name)
        ply:SetNW2Int("ZMS.CurrentTrain.ApproachingStation", math.floor(station))
    end

    next_check = CurTime() + 0.2
end)
