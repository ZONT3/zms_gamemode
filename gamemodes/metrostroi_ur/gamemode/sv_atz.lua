ZMS = ZMS or {}
ZMS.ATZ = ZMS.ATZ or {}
ZMS.ATZ.storage = {}
ZMS.ATZ.active = {}

util.AddNetworkString("ZMS.ATZ.MenuOpen")

concommand.Add("zms_atz", function(ply, cmd, args)
    local name, idx
    if not IsValid(ply) then
        ply = Entity(tonumber(args[1]))
        if not IsValid(ply) or not ply:IsPlayer() then
            print("Player not found:", args[1])
            return
        end
        if not args[2] then
            print(ply)
            return
        end
        name = args[2]
        idx = 3
    else
        name = args[1]
        idx = 2
    end
    local options = {}
    for i, opt in args do if i > idx then table.insert(options, opt) end end
    ZMS.ATZ.Execute(
        ply, string.lower(name),
        args[idx] and args[idx] == "rear" or false,
        args[idx] and args[idx] == "all" or false,
        args[idx] and string.StartsWith(args[idx], "w") and tonumber(string.sub(2)) or nil,
        options)
end)

concommand.Add("zms_atz_clear", function(ply, cmd, args)
    if not IsValid(ply) then
        ply = Entity(tonumber(args[1]))
        if not IsValid(ply) or not ply:IsPlayer() then
            print("Player not found:", args[1])
        end
    end
    ZMS.ATZ.ClearAll(ply)
end)

local function inject_hooks(targets)
    for _, ent in pairs(targets) do
        if not ent.zms_atz_injection then
            local baseThink = ent.Think
            function ent.Think(wagon)
                local baseRes = { baseThink(wagon) }
                if not SERVER then return unpack(baseRes) end
                local hooks = ZMS.ATZ.active[wagon:EntIndex()]
                if not hooks then return end
                for _, case in pairs(hooks) do
                    if not case then continue end
                    if isfunction(case.think) then case.think(wagon, case) end
                end
                return unpack(baseRes)
            end
            ent.zms_atz_injection = true
        end
    end
end

local function clear_wagon(ent_idx)
    if ZMS.ATZ.active[ent_idx] then
        for _, case in pairs(ZMS.ATZ.active[ent_idx]) do
            local wagon = Entity(ent_idx)
            if isfunction(case.cleanup) then case.cleanup(IsValid(wagon) and wagon or nil, case) end
        end
        ZMS.ATZ.active[ent_idx] = {}
    end
end

function ZMS.ATZ.ForEachWagon(train, fnc, predicate)
    for _, wag in pairs(train.WagonList) do
        if not isfunction(predicate) or predicate(wag) then
            fnc(wag)
        end
    end
end

function ZMS.ATZ.GetOpposite(head_wag)
    for _, wag in pairs(head_wag.WagonList) do
        if wag ~= head_wag and wag:GetClass() == head_wag:GetClass() then
            return wag
        end
    end
end

function ZMS.ATZ.GetRandomWagon(cur_wagon, predicate)
    local wagons = {}
    ZMS.ATZ.ForEachWagon(cur_wagon, function(wag) table.insert(wagons, wag) end, predicate)
    if #wagons == 0 then return ZMS.ATZ.GetOpposite(cur_wagon) end
    local idx = math.random(#wagons)
    return wagons[idx]
end

function ZMS.ATZ.GetRandomWagons(train, count, return_map)
    count = count or 1
    if count == 1 then
        if not return_map then
            return { ZMS.ATZ.GetRandomWagon(train) }
        else
            return { [ZMS.ATZ.GetRandomWagon(train):EntIndex()] = true }
        end
    end

    local wagons_k = table.GetKeys(train.WagonList)
    count = math.min(#wagons_k, count)
    table.Shuffle(wagons_k)
    local targets = {}
    for idx, k in ipairs(wagons_k) do
        if idx > count then break end
        if not return_map then
            table.insert(targets, train.WagonList[k])
        else
            targets[train.WagonList[k]:EntIndex()] = true
        end
    end
    return targets
end

function ZMS.ATZ.GetRandomInter(cur_wagon, is_cur_inter)
    if is_cur_inter then
        return ZMS.ATZ.GetRandomWagon(cur_wagon, function(wag) return wag == cur_wagon or wag:GetClass() == cur_wagon:GetClass() end)
    else
        return ZMS.ATZ.GetRandomWagon(cur_wagon, function(wag) return wag ~= cur_wagon and wag:GetClass() ~= cur_wagon:GetClass() end)
    end
end

function ZMS.ATZ.ClearAll(ply)
    local train = ply:GetTrain()
    if not IsValid(train) then
        print("No train found")
        return
    end
    print("Removing cases:")
    ZMS.ATZ.GetCurrent(ply)
    for _, wagon in pairs(train.WagonList) do
        clear_wagon(wagon:EntIndex())
    end
end

function ZMS.ATZ.GetCurrent(ply)
    local train = ply:GetTrain()
    if not IsValid(train) then
        print("No train found")
        return
    end
    for _, wagon in pairs(train.WagonList) do
        if ZMS.ATZ.active[wagon:EntIndex()] then
            local wag_tbl = {}
            for name in pairs(ZMS.ATZ.active[wagon:EntIndex()]) do
                table.insert(wag_tbl, name)
            end
            print(string.format("[%d] %s: %s", wagon:EntIndex(), wagon:GetClass(), table.concat(wag_tbl, ", ")))
        end
    end
end

function ZMS.ATZ.UseRunnable(base_case, runnable, runnable_name)
    runnable_name = runnable_name or "runnable"
    if not runnable and not isfunction(base_case.create_runnable) then
        print("[ZMS.ATZ] Runnable not provided nor 'create_runnable' factory method provided in 'base_case'")
        return
    end
    return {
        desc = base_case.desc,
        target_all_wagons = base_case.target_all_wagons,
        target_opposite_wagon = base_case.target_opposite_wagon,
        target_n_wagons = base_case.target_n_wagons,
        restrict_types = base_case.restrict_types,
        restrict_desc = base_case.restrict_desc,
        case_weight = base_case.case_weight,

        before_run = function(train, opts, case)
            if isfunction(base_case.create_runnable) then
                case[runnable_name] = base_case.create_runnable(train, opts, case)
            else
                case[runnable_name] = runnable
            end
            if isfunction(base_case.before_run) then
                local ret = base_case.before_run(train, opts, case)
                if ret == true then return end
            end
            local cur_runnable = case[runnable_name]
            if isfunction(cur_runnable.before_run) then
                cur_runnable.before_run(train, opts, case)
            end
        end,
        on_run = function(wagon, opts, case)
            if isfunction(base_case.on_run) then
                local ret = base_case.on_run(wagon, opts, case)
                if ret == true then return end
            end
            local cur_runnable = case[runnable_name]
            if isfunction(cur_runnable.on_run) then
                cur_runnable.on_run(wagon, opts, case)
            end
        end,
        think = function(wagon, case)
            if isfunction(base_case.think) then
                local ret = base_case.think(wagon, case)
                if ret == true then return end
            end
            local cur_runnable = case[runnable_name]
            if isfunction(cur_runnable.think) then
                cur_runnable.think(wagon, case)
            end
        end,
        cleanup = function(wagon, case)
            if isfunction(base_case.cleanup) then
                local ret = base_case.cleanup(wagon, case)
                if ret == true then return end
            end
            local cur_runnable = case[runnable_name]
            if isfunction(cur_runnable.cleanup) then
                cur_runnable.cleanup(wagon, case)
            end
        end,
    }
end

function ZMS.ATZ.CheckRestrictions(train, case)
    if not istable(case.restrict_types) then return true end
    local matched = false
    for _, pattern in ipairs(case.restrict_types) do
        local invert = false
        if string.StartsWith(pattern, "~") then
            pattern = string.sub(pattern, 2)
            invert = true
        end
        if string.match(train:GetClass(), pattern) then
            if invert then
                return false
            end
            matched = true
        end
    end
    return matched
end

function ZMS.ATZ.Execute(ply, name, rear, all, wagons_count, options)
    local fnc_print = IsValid(ply) and ply:IsPlayer() and function(...) ply:ChatPrint(...) end or print
    if not name then
        fnc_print("No name provided")
        return
    end
    local train = ply:GetTrain()
    if not IsValid(train) then
        fnc_print("No train found")
        return
    end
    local case = ZMS.ATZ.storage[name]
    if not case then
        fnc_print("No case with name", name)
        return
    end

    if not ZMS.ATZ.CheckRestrictions(train, case) then
        local restr_desc = case.restrict_desc
        if not restr_desc then
            local tbl = {}
            for _, v in ipairs(case.restrict_types) do
                if string.StartsWith(pattern, "~") then
                    table.insert(tbl, "НЕ " .. string.sub(v, 2))
                else
                    table.insert(tbl, v)
                end
            end
            restr_desc = table.concat(tbl, ", ")
        end
        fnc_print("Данный случай не предназначен для этого поезда.")
        fnc_print("Подходят: " .. restr_desc)
        return
    end

    case = {
        desc = case.desc,
        target_all_wagons = case.target_all_wagons,
        target_opposite_wagon = case.target_opposite_wagon,
        target_n_wagons = case.target_n_wagons,
        restrict_types = case.restrict_types,
        restrict_desc = case.restrict_desc,

        case_weight = case.case_weight,

        before_run = case.before_run,
        on_run = case.on_run,
        think = case.think,
        cleanup = case.cleanup,
    }

    local targets = nil
    if case.target_n_wagons or wagons_count and not case.target_opposite_wagon and not case.target_all_wagons then
        targets = ZMS.ATZ.GetRandomWagons(train, case.target_n_wagons or wagons_count)
    elseif case.target_all_wagons or all and not case.target_opposite_wagon then
        targets = train.WagonList
    elseif case.target_opposite_wagon or rear then
        targets = { ZMS.ATZ.GetOpposite(train) }
    end
    if not targets then
        targets = { train }
    end

    options = options or {}

    if isfunction(case.before_run) then case.before_run(train, options, case) end
    if isfunction(case.on_run) then for _, target in pairs(targets) do case.on_run(target, options, case) end end
    if not isfunction(case.think) and not isfunction(case.cleanup) then return end

    for _, wagon in pairs(targets) do
        ZMS.ATZ.active[wagon:EntIndex()] = ZMS.ATZ.active[wagon:EntIndex()] or {}
        local cases = ZMS.ATZ.active[wagon:EntIndex()]
        local idx = table.Count(cases) + 1
        cases[name .. idx] = case
    end

    inject_hooks(targets)
end

timer.Create("ZMS.ATZ.DeletedCheck", 3, 0, function()
    for ent_idx, tbl in pairs(ZMS.ATZ.active) do
        if table.IsEmpty(tbl) then continue end
        local wagon = Entity(ent_idx)
        if not IsValid(wagon) then
            print("[ZMS.ATZ] Removing active cases for removed wagon", ent_idx)
            clear_wagon(ent_idx)
        end
    end
end)

function ZMS.ATZ.Register(name, tbl, runnable)
    if not tbl then
        print("[ZMS.ATZ] Error registering case", name)
        return
    end
    if runnable or isfunction(tbl.create_runnable) then
        ZMS.ATZ.storage[string.lower(name)] = ZMS.ATZ.UseRunnable(tbl, runnable)
    else
        ZMS.ATZ.storage[string.lower(name)] = tbl
    end
end
