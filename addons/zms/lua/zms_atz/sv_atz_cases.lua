ZMS = ZMS or {}
ZMS.ATZ = ZMS.ATZ or {}

local normal_disabled = { "A10,714", "A54,714" }
local function cleanup_av(wagon, av_name)
    local av = IsValid(wagon) and wagon[av_name] or nil
    if av then
        local disabled = false
        for _, v in ipairs(normal_disabled) do
            local c_av_name, pattern = unpack(string.Split(v, ","))
            if c_av_name == av_name and (not pattern or string.match(wagon:GetClass(), pattern)) then
                disabled = true
                break
            end
        end
        if disabled and av.Value > 0 or av.Value < 1 then
            av:TriggerInput("Set", disabled and 0 or 1)
        end
    end
end

local predefined_restrictions = {
    {
        restrict_types = {"71[74]", "~71[74].9"},
        restrict_desc = "только 717/714",
    }
}

local function fnc_aux_by_realy(relay, wire, relay_hint, prob, restriction_type)
    prob = tonumber(prob)
    local wire_n = tonumber(wire)
    if not wire_n or not relay then
        print(string.format("[ZMS.ATZ.Register] INVALID CONFIG FOR fnc_aux_by_realy(%s, %s)", wire, relay))
        return
    end
    local rel_str = relay_hint and string.format("%s (%s)", relay, relay_hint) or relay
    local rel_id = string.format("zms_atz_relay_%s", relay)
    local next_prob = 0
    local prob_r = true
    local restriction = restriction_type and predefined_restrictions[restriction_type] or {}
    return {
        desc = string.format("Постороннее питание на пп. №%s от реле %s", wire, rel_str),
        restrict_types = restriction.restrict_types,
        restrict_desc = restriction.restrict_desc,
        on_run = function(wagon)
            local r = wagon[relay]
            if not r then
                print("Not found relay on wagon", relay, wagon:EntIndex())
                return
            end
            wagon[rel_id] = r
        end,
        think = function(wagon)
            local r = wagon[rel_id]
            if prob and CurTime() >= next_prob then
                next_prob = CurTime() + math.Rand(0.2, 1.8)
                prob_r = math.random() < prob
            end
            if r then
                wagon.TrainWireOutside[wire_n] = (r.Value > 0 and prob_r) and 1 or nil
            end
        end,
        cleanup = function(wagon) if IsValid(wagon) then wagon.TrainWireOutside[wire_n] = nil end end
    }
end

local function fnc_break_by_wire(wire, relay, relay_hint, prob, restriction_type)
    prob = tonumber(prob)
    local wire_n = tonumber(wire)
    if not wire_n or not relay then
        print(string.format("[ZMS.ATZ.Register] INVALID CONFIG FOR fnc_break_by_wire(%s, %s)", wire, relay))
        return
    end
    local rel_str = relay_hint and string.format("%s (%s)", relay, relay_hint) or relay
    local rel_id = string.format("zms_atz_relay_%s", relay)
    local next_prob = 0
    local restriction = restriction_type and predefined_restrictions[restriction_type] or {}
    return {
        desc = string.format("Выбивание %s от питания на пп. №%s", rel_str, wire),
        restrict_types = restriction.restrict_types,
        restrict_desc = restriction.restrict_desc,
        on_run = function(wagon)
            local r = wagon[relay]
            if not r then
                print("Not found relay on wagon", relay, wagon:EntIndex())
                return
            end
            wagon[rel_id] = r
        end,
        think = function(wagon)
            local r = wagon[rel_id]
            if r and wagon:ReadTrainWire(wire_n) * r.Value > 0 then
                if prob and CurTime() >= next_prob then
                    next_prob = CurTime() + 1
                    if math.random() >= prob then return end
                elseif prob then
                    return
                end
                r:TriggerInput("Set", 0)
            end
        end,
        cleanup = function(wagon) cleanup_av(wagon, rel_id) end
    }
end

local function fnc_break_by_relay(relay_src, relay_tgt, relay_src_hint, relay_tgt_hint, prob, restriction_type)
    prob = tonumber(prob)
    if not relay_src or not relay_tgt then
        print(string.format("[ZMS.ATZ.Register] INVALID CONFIG FOR fnc_break_by_relay(%s, %s)", relay_src, relay_tgt))
        return
    end
    local relay_src_str = relay_src_hint and string.format("%s (%s)", relay_src, relay_src_hint) or relay_src
    local relay_tgt_str = relay_tgt_hint and string.format("%s (%s)", relay_tgt, relay_tgt_hint) or relay_tgt
    local relay_src_id = string.format("zms_atz_relay_%s", relay_src)
    local relay_tgt_id = string.format("zms_atz_relay_%s", relay_tgt)
    local next_prob = 0
    local restriction = restriction_type and predefined_restrictions[restriction_type] or {}
    return {
        desc = string.format("Выбивание %s от питания на реле %s", relay_tgt_str, relay_src_str),
        restrict_types = restriction.restrict_types,
        restrict_desc = restriction.restrict_desc,
        on_run = function(wagon)
            local rs = wagon[relay_src]
            local rt = wagon[relay_tgt]
            for _, r in ipairs({rs, rt}) do
                if not r then
                    print("Not found relay on wagon", r, wagon:EntIndex())
                    return
                end
            end
            wagon[relay_src_id] = rs
            wagon[relay_tgt_id] = rt
        end,
        think = function(wagon)
            local rs = wagon[relay_src_id]
            local rt = wagon[relay_tgt_id]
            if rs and rt and rs.Value * rt.Value > 0 then
                if prob and CurTime() >= next_prob then
                    next_prob = CurTime() + 1
                    if math.random() >= prob then return end
                elseif prob then
                    return
                end
                rt:TriggerInput("Set", 0)
            end
        end,
        cleanup = function(wagon) cleanup_av(wagon, relay_tgt_id) end
    }
end


--[[                                           CASES                                           ]]
ZMS.ATZ.Register("kd", {
    on_run = function(wagon)
        local val = wagon.A13.Value > 0 and 0 or 1
        wagon.A13:TriggerInput("Set", val)
        print("KD now", val)
    end
})
ZMS.ATZ.Register("autostop", {
    desc = "Сорвать скобу автостопа",
    on_run = function(wagon)
        wagon.Pneumatic.EmergencyValve = true
        if wagon.UAVAC then
            wagon.UAVAC:TriggerInput("Set", 0)
        end
    end
})
ZMS.ATZ.Register("hod_breaker", fnc_break_by_wire("1", "A1", nil, nil, 1))
ZMS.ATZ.Register("vmk_bpsn_breaker", fnc_break_by_relay("VMK", "A45", "Выключатель МК", nil, nil, 1))
ZMS.ATZ.Register("tormoz_a54_breaker", fnc_break_by_wire("6", "A54", nil, nil, 1))
ZMS.ATZ.Register("tormoz_a29_breaker", fnc_break_by_wire("6", "A29", nil, nil, 1))
ZMS.ATZ.Register("rd_a13_breaker", fnc_break_by_relay("RD", "A13", "Сигнализация дверей", nil, nil, 1))
ZMS.ATZ.Register("rd_aux2", fnc_aux_by_realy("RD", "2", "Сигнализация дверей", nil, 1))
ZMS.ATZ.Register("kvd_aux1", {
    desc = "Постороннее питание на 1-м проводе от (Л)КВД",
    restrict_types = {"71[74]", "~71[74].9"},
    restrict_desc = "только 717/714",
    think = function(wagon)
        wagon.TrainWireOutside[1] = wagon:GetPackedBool("KVD", false) and 1 or nil
    end,
    cleanup = function(wagon) if IsValid(wagon) then wagon.TrainWireOutside[1] = nil end end
})
ZMS.ATZ.Register("hiamper_aux31", {
    desc = "Постороннее питание на 31-м проводе от выс. тока на ТЭД",
    restrict_types = {"71[74]", "~71[74].9"},
    restrict_desc = "только 717/714",
    think = function(wagon)
        wagon.TrainWireOutside[31] = wagon.Electric.I24 > 300 and 1 or nil
    end,
    cleanup = function(wagon) if IsValid(wagon) then wagon.TrainWireOutside[31] = nil end end
})
ZMS.ATZ.Register("kd_delay", {
    desc = "Задержка контроля дверей. Опции: [<сред. сек>]",
    target_all_wagons = true,
    restrict_types = {"7[1246][07]"},
    restrict_desc = "только головные 717, 720, 740, 760",
    before_run = function(head_wagon, options, case)
        local delay = tonumber(options[1]) or 2.8
        local wagon = ZMS.ATZ.GetRandomInter(head_wagon)
        wagon.zatz_kd_delay = delay
        case.bukp = not not string.match(wagon:GetClass(), "7[26][013]")

        if case.bukp then
            case.rd_get = function(w)
                return not (w.DoorsOpened or w.BUV.DoorsOpened)
            end
            case.vud_get = function(w) return w.BUV.CloseDoors end
            case.a13_set = function(w, val)
                if val > 0 then
                    local i = w.zms_atz_door_i or 1
                    local spdl = w.zms_atz_door_speed_l or w.Pneumatic.LeftDoorSpeed[i]
                    local spdr = w.zms_atz_door_speed_r or w.Pneumatic.RightDoorSpeed[i]
                    w.Pneumatic.LeftDoorSpeed[i] = spdl < 4 and spdl or 2.25
                    w.Pneumatic.RightDoorSpeed[i] = spdr < 4 and spdr or 2.25
                    w.zms_atz_door_i = nil
                    w.zms_atz_door_speed_l = nil
                    w.zms_atz_door_speed_r = nil
                else
                    local i = w.zms_atz_door_i
                    if not i then
                        w.zms_atz_door_i = math.random(1, 4)
                        i = w.zms_atz_door_i
                    end
                    if not w.zms_atz_door_speed_l then
                        w.zms_atz_door_speed_l = w.Pneumatic.LeftDoorSpeed[i]
                        w.zms_atz_door_speed_r = w.Pneumatic.RightDoorSpeed[i]
                    end
                    w.Pneumatic.LeftDoorSpeed[i] = 26.0
                    w.Pneumatic.RightDoorSpeed[i] = 26.0
                end
            end
            case.a13_get = function(w) return not w.zms_atz_door_i end
            case.open_get = function(w) return w.BUV.OpenLeft or w:ReadTrainWire(38) > 0 or w.BUV.OpenRight or w:ReadTrainWire(37) > 0 end

        else
            case.rd_get = function(w) return w.RD.Value > 0 end
            case.vud_get = function(w) return w:ReadTrainWire(16) > 0 end
            case.a13_set = function(w, val) w.A13:TriggerInput("Set", val) end
            case.a13_get = function(w) return w.A13.Value > 0 end
            case.open_get = function(w) return (w:ReadTrainWire(32) + w:ReadTrainWire(31)) > 0 end
        end
    end,
    think = function(wagon, case)
        if wagon.zatz_kd_delay == nil then return end

        local kd = case.rd_get(wagon)
        if wagon.zatz_kd_delay_timer == -2 then
            if not kd then return end
            local cur_delay = wagon.zatz_kd_delay
            wagon.zatz_kd_delay_timer = nil
            wagon.zatz_kd_delay = nil
            if wagon.zatz_kd_is_slave then
                wagon.zatz_kd_is_slave = nil
                return
            end

            if case.bukp then
                local max_count = math.ceil(table.Count(wagon.WagonList) * 0.7)
                local count = math.Clamp(math.random(1, max_count * 2) - max_count, 1, max_count)
                local wagons = ZMS.ATZ.GetRandomWagons(wagon, count)
                for idx, w in ipairs(wagons) do
                    w.zatz_kd_delay = cur_delay
                    if idx > 1 then
                        w.zatz_kd_is_slave = true
                    end
                end
            else
                local w = ZMS.ATZ.GetRandomInter(wagon, true)
                w.zatz_kd_delay = cur_delay
            end
            return
        end

        local first_time = wagon.zatz_kd_delay_timer == nil
        local a13 = case.a13_get(wagon)
        local vud = case.vud_get(wagon)
        if first_time and a13 and vud then
            if kd then return end
            case.a13_set(wagon, 0)
        elseif not a13 then
            if first_time and vud and wagon.zatz_kd_delay >= 1 then
                -- Запускаем таймер
                wagon.zatz_kd_delay_timer = CurTime() + math.max(0.5, wagon.zatz_kd_delay + math.Rand(-1, 1))
            elseif first_time and vud and wagon.zatz_kd_delay < 1 then
                -- Ждем переигровки дверьми
                wagon.zatz_kd_delay_timer = -1
            end

            if not vud and wagon.zatz_kd_delay_timer == -1 and case.open_get(wagon) then  -- Переиграл дверьми
                wagon.zatz_kd_delay_timer = CurTime() + 1.2
            elseif vud and wagon.zatz_kd_delay_timer >= 0 and CurTime() > wagon.zatz_kd_delay_timer then  -- Таймер вышел
                wagon.zatz_kd_delay_timer = -2
                case.a13_set(wagon, 1)
            end
        end
    end,
    cleanup = function(wagon)
        if IsValid(wagon) then
            if wagon.A13 then
                wagon.A13:TriggerInput("Set", 1)
            end
            wagon.zatz_kd_delay_timer = nil
            wagon.zatz_kd_delay = nil
            wagon.zatz_kd_is_slave = nil
            wagon.zms_atz_door_i = nil
            wagon.zms_atz_door_speed_l = nil
            wagon.zms_atz_door_speed_r = nil
        end
    end
})

local fuck_avs = { "A15", "A27", "A49", "A53" }
ZMS.ATZ.Register("hod_fuck", {
    desc = "Выбивание упр. ав. на всем составе периодически",
    target_all_wagons = true,
    restrict_types = {"71[74]", "~71[74].9"},
    restrict_desc = "только 717/714",
    think = function(wagon, case)
        local k = "next_prob_" .. wagon:EntIndex()
        local next_prob = case[k] or 0
        if CurTime() < next_prob then return end
        case[k] = CurTime() + 1.0

        local rand = math.random()
        if rand < 0.025 and wagon:ReadTrainWire(6) > 0 then
            wagon.A6:TriggerInput("Set", 0)
        end
        if rand < 0.008 and wagon:ReadTrainWire(14) > 0 then
            wagon.A14:TriggerInput("Set", 0)
        end
        if rand < 0.025 and wagon:ReadTrainWire(4) > 0 and wagon:ReadTrainWire(1) > 0 then
            wagon.A4:TriggerInput("Set", 0)
        end
        if rand < 0.025 and wagon:ReadTrainWire(5) > 0 and wagon:ReadTrainWire(1) > 0 then
            wagon.A5:TriggerInput("Set", 0)
        end
        if rand < 0.025 and wagon:ReadTrainWire(14) > 0 or wagon:ReadTrainWire(1) > 0 then
            if math.random() >= 0.15 then return end
            for i = 1, 2 do
                local av = wagon[fuck_avs[math.random(#fuck_avs)]]
                if av and av.Value > 0 then av:TriggerInput("Set", 0) end
            end
        end
    end,
    cleanup = function(wagon) if IsValid(wagon) then
        for _, av_k in ipairs({ "A15", "A27", "A49", "A53", "A14", "A4", "A5", "A6" }) do
            local av = wagon[av_k]
            if av and av.Value < 1 then
                av:TriggerInput("Set", 1)
            end
        end
    end end
})

local function fnc_fire()
    return {
        desc = "Эмуляция перегрева и пожара ПТР. Арг: [<задержк. до перегрева, сек> [<до пожара, сек>]]",
        before_run = function(wagon, opts, case)
            if opts[1] then
                local n = tonumber(opts[1])
                if n then
                    case.until_heat = n
                end
            end
            if opts[2] then
                local n = tonumber(opts[2])
                if n then
                    case.until_fire = n
                end
            end
        end,
        on_run = function(wagon, _, case)
            wagon.zms_atz_until_heat = CurTime() + (case.until_heat or math.Rand(5, 15))
            wagon.zms_atz_until_fire = case.until_fire and (CurTime() + case.until_fire) or (wagon.zms_atz_until_heat + math.Rand(2, 45))
        end,
        think = function(wagon, case, pause)
            if not wagon.IGLA_PCBK then return end
            if not wagon.zms_atz_until_heat or not wagon.zms_atz_until_fire then return end
            if pause then
                if not wagon.zms_atz_fire_paused_at then
                    wagon.zms_atz_fire_paused_at = CurTime()
                end
                return
            elseif wagon.zms_atz_fire_paused_at then
                local dt = CurTime() - wagon.zms_atz_fire_paused_at
                wagon.zms_atz_until_heat = wagon.zms_atz_until_heat + dt
                wagon.zms_atz_until_fire = wagon.zms_atz_until_fire + dt
                wagon.zms_atz_fire_paused_at = nil
            end

            local ct = CurTime()
            if ct >= wagon.zms_atz_until_heat then
                wagon.IGLA_PCBK:CANWrite("PTROverheating", 1)
            end
            if ct >= wagon.zms_atz_until_fire then
                wagon.IGLA_PCBK:CANWrite("PTROverheat", 1)
            end
        end,
        cleanup = function(wagon) if IsValid(wagon) then
            wagon.zms_atz_fire_paused_at = nil
            wagon.zms_atz_until_heat = nil
            wagon.zms_atz_until_fire = nil
            if wagon.IGLA_PCBK then
                wagon.IGLA_PCBK:CANWrite("PTROverheating", nil)
                wagon.IGLA_PCBK:CANWrite("PTROverheat", nil)
            end
        end end
    }
end
local function fnc_fire_by_wire(wire, ...)
    local extra_opts = { ... }
    return ZMS.ATZ.UseRunnable({
        desc = "Закономерность: пожар ПТР при питании на пп. Арг.: <ПП.> [<до перегр., сек> [<до пожара, сек>]]",
        before_run = function(wagon, opts, case)
            table.Add(opts, extra_opts)
            case.wire = wire or tonumber(opts[1])
            if wire then
                table.remove(opts, 1)
            end
            case.fnc_fire.before_run(wagon, opts, case)
            return true
        end,
        think = function(wagon, case)
            if not isnumber(case.wire) then return end
            case.fnc_fire.think(wagon, case, wagon:ReadTrainWire(case.wire) < 0.5)
            return true
        end
    }, fnc_fire(), "fnc_fire")
end
local function fnc_fire_by_relay(relay, ...)
    local extra_opts = { ... }
    return ZMS.ATZ.UseRunnable({
        desc = "Закономерность: пожар ПТР при питании на реле. Арг.: <Р.> [<до перегр., сек> [<до пожара, сек>]]",
        before_run = function(wagon, opts, case)
            table.Add(opts, extra_opts)
            case.relay = relay or opts[1]
            if not relay then
                table.remove(opts, 1)
            end
            case.fnc_fire.before_run(wagon, opts, case)
            return true
        end,
        think = function(wagon, case)
            if not case.relay or not wagon[case.relay] then return end
            case.fnc_fire.think(wagon, case, wagon[case.relay].Value < 0.5)
            return true
        end
    }, fnc_fire(), "fnc_fire")
end
ZMS.ATZ.Register("fire", fnc_fire())
ZMS.ATZ.Register("fire_by_wire", fnc_fire_by_wire())
ZMS.ATZ.Register("fire_by_relay", fnc_fire_by_relay())


ZMS.ATZ.Register("break_by_wire", {
    desc = "Закономерность: выбить автомат при питании на пп. Арг.: <ПП.> <АВ.> [<вероятность/сек (0.0-1.0)>]",
    create_runnable = function(wagon, opts, case)
        return fnc_break_by_wire(opts[1], opts[2], nil, opts[3] or nil)
    end
})
ZMS.ATZ.Register("break_by_relay", {
    desc = "Закономерность: выбить автомат при питании на реле. Арг.: <Р.> <АВ.> [<вероятность/сек (0.0-1.0)>]",
    create_runnable = function(wagon, opts, case)
        return fnc_break_by_relay(opts[1], opts[2], nil, nil, opts[3] or nil)
    end
})
ZMS.ATZ.Register("aux_by_relay", {
    desc = "Закономерность: постор. пит. на пп. от реле. Арг.: <Р.> <ПП.> [<вероятность/сек (0.0-1.0)>]",
    create_runnable = function(wagon, opts, case)
        return fnc_aux_by_realy(opts[1], opts[2], nil, opts[3] or nil)
    end
})
ZMS.ATZ.Register("break", {
    desc = "Выбить автомат. Арг.: <АВ.> [<не восстановить (1/0)> [<вероятность (0.0-1.0)>]]",
    before_run = function(wagon, opts, case)
        case.av = opts[1]
        case.prob = tonumber(opts[3])
        if opts[2] then
            local n = tonumber(opts[2])
            case.not_recovering = n and n == 1 or false
        else
            case.not_recovering = false
        end
    end,
    on_run = function(wagon, _, case)
        local prob_r = not case.prob or math.random() < case.prob
        local av = case.av and wagon[case.av] or nil
        if not prob_r then wagon.zms_atz_not_prob = true end
        if av and prob_r and av.Value > 0 then
            av:TriggerInput("Set", 0)
        end
    end,
    think = function(wagon, case)
        if not case.not_recovering or wagon.zms_atz_not_prob then return end
        local av = case.av and wagon[case.av] or nil
        if av and av.Value > 0 then
            av:TriggerInput("Set", 0)
        end
    end,
    cleanup = function(wagon, case)
        if not IsValid(wagon) then return end
        local av = case.av and wagon[case.av] or nil
        if av and av.Value < 1 then
            av:TriggerInput("Set", 1)
        end
        wagon.zms_atz_not_prob = nil
    end,
})


--[[                                       Random Quirk                                       ]]
local predefined_relays = { "VMK", "Ring", "VUS", "KVT", "PB", "RD", "KO", "KK" }
local predefined_avs = { "AR63", "AV1", "AV2", "AV4", "AV5", "AV6" }
local function check_presence(wagons, relay_name)
    for _, wagon in ipairs(wagons) do
        if wagon[relay_name] then return true end
    end
    return false
end
local function get_random_relay(wagons, av_only, relay_only)
    wagons = istable(wagons) and wagons or { wagons }
    for i = 1, 10 do
        if not relay_only and (av_only or math.random() < 0.6) then
            local name = "A" .. math.random(80)
            if check_presence(wagons, name) then return name end
        end
    end
    local name = table.Random(not av_only and predefined_relays or predefined_avs)
    if not check_presence(wagons, name) then
        -- fallbacks that present both on 717 and 714
        return not av_only and "RD" or "A16"
    end
    return name
end
local predefined_wires = { 1, 2, 3, 4, 5, 6, 16, 17, 25, 29, 31, 32, 39, 48 }
local function get_random_wire(wagon)
    if math.random() < 0.5 then return table.Random(predefined_wires) end
    return math.random(50)
end
local function wagon_map_to_list(wagons)
    if istable(wagons) then
        local w = {}
        for key, v in pairs(wagons) do
            if v then table.insert(w, Entity(tonumber(key))) end
        end
        return w
    else
        return nil
    end
end

local random_types = {
    break_by_wire = {
        before_run = function(wagon, _, case)
            case.rnd_wire = get_random_wire(wagon)
            case.rnd_av_name = get_random_relay(wagon_map_to_list(case.wagons) or wagon, true)
        end,
        think = function(wagon, case)
            local av = wagon[case.rnd_av_name]
            if isnumber(case.rnd_wire) and av and wagon:ReadTrainWire(case.rnd_wire) * av.Value > 0 then
                av:TriggerInput("Set", 0)
            end
        end,
        cleanup = function(wagon, case)
            cleanup_av(wagon, case.rnd_av_name)
        end,
        case_weight = 30
    },
    break_by_relay = {
        before_run = function(wagon, _, case)
            local wagons = wagon_map_to_list(case.wagons)
            case.rnd_relay_name = get_random_relay(wagons or wagon, false, true)
            case.rnd_av_name = get_random_relay(wagons or wagon, true)
        end,
        think = function(wagon, case)
            local relay = wagon[case.rnd_relay_name]
            local av = wagon[case.rnd_av_name]
            if relay and av and relay.Value * av.Value > 0 then
                av:TriggerInput("Set", 0)
            end
        end,
        cleanup = function(wagon, case)
            cleanup_av(wagon, case.rnd_av_name)
        end,
        case_weight = 30
    },
    aux_by_relay = {
        before_run = function(wagon, _, case)
            case.rnd_wire = get_random_wire(wagon)
            case.rnd_relay_name = get_random_relay(wagon_map_to_list(case.wagons) or wagon, false, math.random() < 0.85)
        end,
        think = function(wagon, case)
            local relay = wagon[case.rnd_relay_name]
            if isnumber(case.rnd_wire) and relay then
                wagon.TrainWireOutside[case.rnd_wire] = relay.Value > 0 and 1 or nil
            end
        end,
        cleanup = function(wagon, case)
            if IsValid(wagon) and isnumber(case.rnd_wire) then
                wagon.TrainWireOutside[case.rnd_wire] = nil
            end
        end,
        case_weight = 30
    },

    fire_by_relay = ZMS.ATZ.UseRunnable({
        create_runnable = function(wagon, _, case)
            case.rnd_relay_name = get_random_relay(wagon_map_to_list(case.wagons) or wagon, false, math.random() < 0.85)
            return fnc_fire_by_relay(case.rnd_relay_name)
        end,
        case_weight = 3
    }, nil, "fnc_fire_by_wire"),
    fire_by_wire = ZMS.ATZ.UseRunnable({
        create_runnable = function(wagon, _, case)
            case.rnd_wire = get_random_wire(wagon)
            return fnc_fire_by_wire(case.rnd_wire)
        end,
        case_weight = 3
    }, nil, "fnc_fire_by_wire"),
}
ZMS.ATZ.Register("random_quirk", {
    desc = "Случайная закономерность. Опции [<кол-во вагонов, дефолт: 1>]",
    target_all_wagons = true,
    restrict_types = {"71[74]", "~71[74].9"},
    restrict_desc = "только 717/714",
    before_run = function(train, opts, case)
        local wagons = ZMS.ATZ.GetRandomWagons(train, tonumber(opts[1]) or 1, true)

        local sum = 0
        for _, c in pairs(random_types) do
            sum = sum + (c.case_weight or 30)
        end
        local rand = math.random(math.floor(sum))
        sum = 0
        local case_type = "break_by_wire"
        for k, c in pairs(random_types) do
            sum = sum + (c.case_weight or 30)
            if sum >= rand then
                case_type = k
                break
            end
        end

        local case_runnable = random_types[case_type]
        case.wagons = wagons
        case.runnable = case_runnable
        case.runnable.before_run(train, {}, case)
        print("Random case type", case_type)
        print("wire", case.rnd_wire, "av", case.rnd_av_name, "relay", case.rnd_relay_name)
    end,
    on_run = function(wagon, _, case)
        if case.runnable and case.runnable.on_run then
            case.runnable.on_run(wagon, {}, case)
        end
    end,
    think = function(wagon, case)
        if case.wagons and case.wagons[wagon:EntIndex()] and case.runnable and case.runnable.think then
            case.runnable.think(wagon, case)
        end
    end,
    cleanup = function(wagon, case)
        if case.wagons and case.wagons[wagon:EntIndex()] and case.runnable and case.runnable.cleanup then
            case.runnable.cleanup(wagon, case)
        end
    end
})
