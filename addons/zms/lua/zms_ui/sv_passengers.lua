local next_check = -1

local function check_update(ply, wagon_count, passenger_count)
    local cur_w = ply:GetNW2Float("ZMS.CurrentTrain.WagonCount", -1)
    local cur_p = ply:GetNW2Float("ZMS.CurrentTrain.PassengerCount", -1)
    return cur_w ~= wagon_count or cur_p ~= passenger_count
end

hook.Add("Think", "ZMS.TrainPassengerListener", function()
    if CurTime() < next_check then return end

    for _, ply in player.Iterator() do
        if not ply.GetTrain then return end
        local train = ply:GetTrain()
        if not train or not train.WagonList then
            if ply:GetNW2Bool("ZMS.CurrentTrain.Available", false) then
                ply:SetNW2Bool("ZMS.CurrentTrain.Available", false)
            end

        else
            local wagon_count = #train.WagonList
            local passenger_count = train:GetNW2Float("PassengerCount")
            for _, wagon in ipairs(train.WagonList) do
                if wagon ~= train then passenger_count = passenger_count + wagon:GetNW2Float("PassengerCount") end
            end

            local cur_avl = ply:GetNW2Bool("ZMS.CurrentTrain.Available", false)
            if not cur_avl or check_update(ply, wagon_count, passenger_count) then
                if not cur_avl then
                    ply:SetNW2Bool("ZMS.CurrentTrain.Available", true)
                end
                ply:SetNW2Float("ZMS.CurrentTrain.WagonCount", wagon_count)
                ply:SetNW2Float("ZMS.CurrentTrain.PassengerCount", passenger_count)
            end
        end
    end

    next_check = CurTime() + 1.2
end)
