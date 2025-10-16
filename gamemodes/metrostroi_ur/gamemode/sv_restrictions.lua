ZMS = ZMS or {}
local unranked_maxwagons = CreateConVar("zms_wagons_max_unranked", 4, FCVAR_ARCHIVE, "Maximum wagons allowed for unranked/unknown players (def = 4)")
local reduction_start_convar = CreateConVar("zms_wagons_reduction", 18, FCVAR_ARCHIVE, "Number of wagons on server to start tighten restriction at (def = 18)")
local max_wagons_convar = CreateConVar("zms_wagons_softmax", 25, FCVAR_ARCHIVE, "Soft maximum of wagons on server, can be penetrated by last spawn with metrostroi_advanced_minwagons (def = 25)")
local ply_count_restrictions = {
    [5] = 5,
    [7] = 4,
}

local function PlayerPermission(ply, permission)
    if ULib then
        return ULib.ucl.query(ply, permission)
    else
        return ply:IsSuperAdmin()
    end
end

local function LangMA(str)
    return MetrostroiAdvanced.Lang[str]
end

local function WagPlural(count)
    local digit = count % 100
    if digit > 4 and digit < 21 then return "вагонов" end
    digit = digit % 10
    if digit > 4 or digit == 0 then return "вагонов" end
    if digit > 1 then return "вагона" end
    return "вагон"
end

local function restriction_reason(reason)
    if reason == -1 then
        return "Без ранга"
    end
    if reason == -2 then
        return "Ограничение кол-ва вагонов"
    end
    if reason == -3 then
        return "Много игроков"
    end
    if reason == -4 then
        return "Сервер полон"
    end
    return "Базовое ограничене карты"
end

function ZMS.GetAllowedWagons(ply)
    local map_wagons = MetrostroiAdvanced and MetrostroiAdvanced.MapWagons and MetrostroiAdvanced.MapWagons[game.GetMap()]
    local mta_maxwagons = GetConVar("metrostroi_advanced_maxwagons"):GetInt() or 6
    map_wagons = map_wagons or mta_maxwagons
    local ply_maxwagons = map_wagons < mta_maxwagons and map_wagons or mta_maxwagons
    local ply_wagons = ply_maxwagons
    local max_wagons = max_wagons_convar:GetInt()
    local min_wagons = GetConVar("metrostroi_advanced_minwagons"):GetInt()
    local cur_wagons = GetGlobalInt("metrostroi_train_count")
    local avail_wagons = max_wagons - cur_wagons
    local unranked_player = not PlayerPermission(ply, "remove_ur_restrictions")

    -- Base maximum
    local restriction_type = 0
    if unranked_player then
        local ur_wagons = unranked_maxwagons:GetInt()
        ply_wagons = ur_wagons < ply_wagons and ur_wagons or ply_wagons
        restriction_type = -1
    elseif PlayerPermission(ply, "add_4wagons") then
        ply_wagons = ply_wagons + 4
    elseif PlayerPermission(ply, "add_3wagons") then
        ply_wagons = ply_wagons + 3
    elseif PlayerPermission(ply, "add_2wagons") then
        ply_wagons = ply_wagons + 2
    elseif PlayerPermission(ply, "add_1wagons") then
        ply_wagons = ply_wagons + 1
    end

    if ply_wagons > map_wagons then ply_wagons = map_wagons end
    -- Too many wagons on server
    local reduction_start = reduction_start_convar:GetInt()
    if cur_wagons + mta_maxwagons >= reduction_start then
        new_max = math.Round(Lerp(math.max(cur_wagons - reduction_start + min_wagons, 0) / (max_wagons - reduction_start), ply_maxwagons - 1, min_wagons))
        if new_max < ply_wagons then
            ply_wagons = new_max
            restriction_type = -2
        end
    end

    -- Too many players on server
    if not PlayerPermission(ply, "zms_restrictions_ignore_ply") then
        local ply_count = player.GetCount()
        for cnt, rstr in pairs(ply_count_restrictions) do
            if ply_count >= cnt and rstr < ply_wagons then
                ply_wagons = rstr
                restriction_type = -3
            end
        end
    end

    if ply_wagons < min_wagons then ply_wagons = min_wagons end
    print("ZMS Restriction: " .. ply_wagons .. " type " .. restriction_reason(restriction_type))
    return ply_wagons, min_wagons, avail_wagons, restriction_type, map_wagons
end

local function AddRestrictionHooks()
    GetConVar("metrostroi_advanced_spawnmessage"):SetInt(0)

    hook.Add("MetrostroiSpawnerRestrict", "ZMS.SpawnerRestrictions", function(ply, settings)
        if not IsValid(ply) then return end
        local function msg_base()
            local wag_num = settings.WagNum
            local wag_str = WagPlural(wag_num)
            local tr = util.TraceLine(util.GetPlayerTrace(ply))
            local rr = Metrostroi.RerailGetTrackData(tr.HitPos, ply:GetAimVector())
            return wag_num, wag_str, tr, rr
        end

        local function spawn_msg()
            local wag_num, wag_str, tr, rr = msg_base()
            if ulx and tr.Hit and tr.HitPos and rr and rr.centerpos then
                ulx.fancyLog(
                    LangMA("Player") .. " #P " .. LangMA("Spawned") .. " #s #s #s.\n" .. LangMA("Location") .. ": #s.",
                    ply, tostring(wag_num), wag_str,
                    MetrostroiAdvanced.GetTrainName(settings.Train),
                    MetrostroiAdvanced.GetLocation(rr.centerpos)
                )
            end
        end

        local function restriction_msg(reason)
            local wag_num, wag_str, tr, rr = msg_base()
            if ulx and tr.Hit and tr.HitPos and rr and rr.centerpos then
                ulx.fancyLog(
                    LangMA("Player") .. " #P не смог заспавнить #s #s #s.\n" .. LangMA("Location") .. ": #s\nПричина: #s.",
                    ply, tostring(wag_num), wag_str,
                    MetrostroiAdvanced.GetTrainName(settings.Train),
                    MetrostroiAdvanced.GetLocation(rr.centerpos),
                    restriction_reason(reason)
                )
            end
        end

        local function restriction_result(reason)
            if ply:IsAdmin() then
                ply:ChatPrint("...но вы - админ, поэтому можно все!")
                spawn_msg()
                return
            end

            restriction_msg(reason)
            return true
        end

        local ply_wagons, min_wagons, avail_wagons, restriction_type, map_wagons = ZMS.GetAllowedWagons(ply)
        if string.find(settings.Train, "740") then
            map_wagons = math.floor(map_wagons / 1.45)
            ply_wagons = math.min(ply_wagons, map_wagons)
            min_wagons = 2
        end

        if avail_wagons <= 0 then
            ply:ChatPrint(string.format("На сервере слишком много вагонов (>= %d).", max_wagons_convar:GetInt()))
            ply:ChatPrint("Пока что можете поработать дежурным по депо/станции, маневровым машинистом")
            ply:ChatPrint("или ДЦХ/ДСЦП, если ваш ранг тому позволяет.")
            return restriction_result(-4)
        elseif avail_wagons < min_wagons then
            if settings.WagNum > min_wagons then
                ply:ChatPrint(string.format("На сервере слишком много вагонов, поэтому вы можете заспавнить только %d", min_wagons))
                return restriction_result(-2)
            end
        end

        if ply_wagons < settings.WagNum then
            if restriction_type == -1 then
                local ur_restriction = unranked_maxwagons:GetInt()
                ply:ChatPrint(string.format("Игрокам без ранга доступно только %d %s.", ur_restriction, WagPlural(ur_restriction)))
            elseif restriction_type == -2 then
                ply:ChatPrint(string.format("На сервере слишком много вагонов, поэтому вы можете заспавнить только %d", ply_wagons))
            elseif restriction_type == -3 then
                ply:ChatPrint(string.format("На сервере слишком много игроков, поэтому вы можете заспавнить только %d %s", ply_wagons, WagPlural(ply_wagons)))
            else
                ply:ChatPrint(string.format("Для спавна доступно только %d %s", ply_wagons, WagPlural(ply_wagons)))
            end
            return restriction_result(restriction_type)
        end

        spawn_msg()
    end)
end

timer.Simple(0, AddRestrictionHooks)

hook.Add("CanProperty", "ZMS.Restrictions.ContextMenuAction", function(ply, pr, ent, property)
    if not IsValid(ent) then return end
    local cls = ent:GetClass()
    ulx.logString(string.format("%s used context menu action %s on %s", ply:Nick(), pr, cls), true)

    if ply:IsAdmin() then return end

    if cls ~= "prop_door_rotating" then
        if pr == "remover" then
            ulx.fancyLog("#P использовал удаление на #s", ply, cls)
        end
        return
    end

    if pr == "remover" then
        ulx.fancyLog("#P - конченный", ply)
        return false
    end

    if string.EndsWith(pr, "door_close") or string.EndsWith(pr, "door_open") then
        ulx.fancyLog("#P перевел стрелку через c-меню", ply)
        return
    end
    ulx.fancyLog("#P манипулирует стрелкой действием #s", ply, pr)
end)

hook.Add("CanTool", "ZMS.Restrictions.ToolGun", function(ply, tr, toolname, tool, button)
    if toolname == "train_spawner" then return end
    local cls = IsValid(tr.Entity) and tr.Entity:GetClass() or "unknown"
    ulx.logString(string.format("%s used toolgun action %s, button %d, entity %s", ply:Nick(), toolname, button, cls), true)
    if ply:IsAdmin() then return end
    if toolname == "remover" and button < 3 then
        ulx.fancyLog("#P использовал удалитель на #s", ply, cls)
    end
end)
