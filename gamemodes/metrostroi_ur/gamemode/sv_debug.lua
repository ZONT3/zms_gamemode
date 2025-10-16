local telemetry = false
concommand.Add("telemetry", function(ply)
    telemetry = telemetry == false and os.date() or false
    print(string.format("%s recording telemetry", telemetry ~= false and "Started" or "Stopped"))
end)

hook.Add("Think", "ZMS.TrainTelemetry", function()
    if telemetry then
        local ply = player.GetBySteamID64("76561198058158985")
        if not IsValid(ply) then ply = Entity(1) end
        if not IsValid(ply) then return end
        local train = ply.InMetrostroiTrain
        if not IsValid(train) then return end

        local filename = string.lower(string.format("zms_telemetry/%s %s.json", ply:SteamID64()))
        local header = string.format("===== %05.03f =====", CurTime())
        local tab = util.TableToJSON(train:GetTable(), true)
        if not file.Exists("data/" .. filename, "GAME") then
            file.Write(filename, string.format("%s\n%s\n", header, tab))
        else
            file.Append(filename, string.format("\n%s\n%s\n", header, tab))
        end
    end
end)

concommand.Add("fwss_debug", function(_, cmd, args)
    local id = args[1]
    if not id then return end
    local ply = Entity(tonumber(id))
    local train = ply:GetTrain()
    if not train then return end

    local ply_pos = ply:GetPos()
    local found = ents.FindInSphere(ply_pos, 800)
    local found_d = {}
    local nearest_ent = nil
    local nearest_val = -1
    for idx, ent in ipairs(found) do
        if IsValid(ent) and ent:GetClass() == "gmod_track_pa_marker" then
            local dist = ent:GetPos():Distance(ply_pos)
            table.insert(found_d, dist)
            if not IsValid(nearest_ent) or dist < nearest_val then
                nearest_val = dist
                nearest_ent = ent
            end
        end
    end

    local train_pos = Metrostroi.TrainPositions[train]
    if train_pos then train_pos = train_pos[1] end

    local result = {
        ["station_id_next"] = train:ReadCell(49161),
        ["distance_cell"] = train:ReadCell(49165) - 7,
        ["train_pos"] = train_pos.x,
        ["pa_pos"] = nearest_ent and nearest_ent.TrackX,
        ["pa_distance"] = nearest_ent and nearest_ent.TrackX and train_pos and train_pos.x and nearest_ent.TrackX - train_pos.x or nil,
        ["ents"] = found_d,
        ["map"] = game.GetMap(),
    }
    PrintTable(result)
end)
