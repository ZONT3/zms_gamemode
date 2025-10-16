zguides = zguides or {}
zguides.ply_train_settings = zguides.ply_train_settings or {}


local function find_train(ply)
    for train in pairs(Metrostroi.SpawnedTrains) do
        if IsValid(train) and IsValid(train.Owner) and train.Owner == ply then
            return train
        end
    end
end

local ply_idx = 1
local plys_hash = nil

hook.Add("MetrostroiSpawnerRestrict", "ZMS.SpawnerSettingsHook", function(ply, settings)
    if not IsValid(ply) then return end
    zguides.ply_train_settings[ply:SteamID64()] = settings
end)

timer.Create("ZMS.TrainLabels.ServerUpdate", 0.6, 0, function()
    local players = player.GetAll()
    if #players == 0 then
        return
    end
    local steamids = {}
    for _, ply in ipairs(players) do
        table.insert(steamids, ply:SteamID64())
    end
    local hash = util.SHA256(table.concat(steamids, " "))
    if not plys_hash or plys_hash ~= hash then
        ply_idx = 1
        plys_hash = hash
    end
    if ply_idx > #players then
        ply_idx = 1
    end

    local idx2lb = zguides.GetTrainLabelTable()
    local ply = players[ply_idx]
    ply_idx = ply_idx + 1

    local train = ply.GetTrain and ply:GetTrain()
    if not IsValid(train) then
        train = find_train(ply)
    end
    local train_class = IsValid(train) and train:GetClass() or nil
    local train_settings = zguides.ply_train_settings[ply:SteamID64()]

    if train_class then
        if train_settings and train_settings["Train"] then
            train_class = train_settings["Train"]
        end
        ply:SetNW2String("ZMS.TrainClass", train_class)
    else
        ply:SetNW2String("ZMS.TrainClass", "")
    end

    local data_chunks = math.ceil(#idx2lb / 32)
    for ch_idx = 1, data_chunks do
        local value = 0
        if IsValid(train) then
            for idx = 1, 32 do
                local lb_idx = (ch_idx - 1) * 32 + idx
                if lb_idx > #idx2lb then break end
                local lb = zguides.labels.trains[idx2lb[lb_idx]]
                if lb and lb.condition and lb.condition(train_class, train, train_settings) then
                    value = bit.bor(value, bit.lshift(1, idx - 1))
                end
            end
        end
        ply:SetNW2Int("ZMS.TrainLabels." .. ch_idx, value)
    end
end)


concommand.Add("zms_spawner_values", function(_, _, _, ply_id)
    local ply = Entity(ply_id and #ply_id > 0 and tonumber(ply_id) or 1)
    if not IsValid(ply) then return end
    PrintTable({
        train_class = ply:GetNW2String("ZMS.TrainClass", train_class),
        spawner_settings = zguides.ply_train_settings[ply:SteamID64()],
    })
end)
