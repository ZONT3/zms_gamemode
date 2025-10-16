local cvar_passengers     = CreateClientConVar("zms_hud_passengers", "1", true, false, "Onboard passengers count on hud", 0, 1)
local cvar_distance       = CreateClientConVar("zms_hud_distance", "1", true, false, "Distance to the nearest station or FWSS on hud", 0, 1)
local cvar_distance_score = CreateClientConVar("zms_hud_distance_score", "1", true, false, "Score of precise stop at a station, zms_hud_distance should be enabled for it to work", 0, 1)

local margin_x = 8
local margin_y = 6
local space_x = 8

local no_score = {
    ["gm_metro_minsk_1984"] = true,
}

local no_score_stations = {
    -- ["gm_metro_jar_imagine_line_v4"] = {
    --     [801] = true,
    --     [802] = true,
    --     [803] = true,
    --     [804] = true,
    -- }
}

local function draw_passengers()
    local wagon_count = LocalPlayer():GetNW2Float("ZMS.CurrentTrain.WagonCount", 2)
    local passenger_count = LocalPlayer():GetNW2Float("ZMS.CurrentTrain.PassengerCount", 0)
    local train_load = math.max(passenger_count / (200 * wagon_count), 0)

    surface.SetFont("HudDefault")

    local prefix_text = "Пассажиров в составе: "
    local suffix_text
    if train_load == nil then
        suffix_text = string.format("%d", passenger_count)
    else
        suffix_text = string.format("%d (%d%%)", passenger_count, math.Round(train_load * 100))
    end

    local full_text = prefix_text .. suffix_text
    local text_w, text_h = surface.GetTextSize(full_text)
    local x = 8 + margin_x
    local y = ScrH() - 8 - margin_y - text_h

    if not cvar_passengers:GetBool() then
        return x, y
    end

    draw.RoundedBox(8, x - margin_x, y - margin_y, text_w + margin_x * 2, text_h + margin_y * 2, Color(0, 0, 0, 96))

    surface.SetTextPos(x, y)
    surface.SetTextColor(255, 255, 255)
    surface.DrawText(prefix_text)
    if train_load == nil then
        surface.SetTextColor(0, 92, 179)
    else
        surface.SetTextColor(GradientGYR(train_load))
    end
    surface.DrawText(suffix_text)

    return x + text_w + margin_x + space_x, y
end

local function get_score(distance)
    distance = math.abs(distance)
    if distance < 8 then
        return "Четко у рейки!", {162, 0, 255}
    end
    if distance < 21 then
        return "Отлично!", {0, 220, 0}
    end
    if distance < 51 then
        return "Хорошо", {220, 220, 0}
    end
    if distance < 81 then
        return "Нормально", {220, 220, 0}
    end
    if distance < 151 then
        return "Сойдет", {220, 100, 0}
    end
    if distance < 221 then
        return "Плохо", {220, 0, 0}
    end
    if distance < 321 then
        return "Ужасно", {160, 0, 0}
    end
    return "", nil
end

local function draw_distance(x, y)
    if not cvar_distance:GetBool() then return x, y end

    local distance = LocalPlayer():GetNW2Float("ZMS.CurrentTrain.ToFWSS", nil)
    local station = LocalPlayer():GetNW2String("ZMS.CurrentTrain.ApproachingStationName", nil)
    local station_id = LocalPlayer():GetNW2Int("ZMS.CurrentTrain.ApproachingStation", nil)
    local is_precise = LocalPlayer():GetNW2Bool("ZMS.CurrentTrain.ToFWSS.Precise", false)

    if not station or station == "" or distance == nil then return x, y end

    local draw_score = cvar_distance_score:GetBool()
    local cm = math.abs(distance) < 3.2 and draw_score
    local unit = cm and "см" or "м"
    if cm then distance = math.Round(distance * 100) end

    local prefix_text = string.format("Станция %s: ", station)
    local value_text = string.format(not cm and distance < 100 and "%.02f " or "%d ", distance)

    local suffix_text, score_color, score_font = "", nil, nil
    local no_score_precision = (distance < 15 or cm) and not is_precise
    local cur_map = game.GetMap()
    local no_score_map = no_score[cur_map]
    local no_score_station = no_score_precision or no_score_map or (no_score_stations[cur_map] and no_score_stations[cur_map][station_id])
    if not draw_score then
        suffix_text, score_color, score_font = "", nil, nil
    elseif no_score_station then
        if cm or distance < 0 then
            suffix_text = string.format(" расстояние примерное, на %s нет конфига ПРОСТ", (no_score_map or no_score_precision) and "карте" or "станции")
            score_color = {180, 60, 60}
            score_font = "DebugOverlay"
        end
    else
        if not cm and distance < 0 then
            suffix_text = " [ Ты куда? ]"
            score_color = {160, 0, 0}
        elseif cm then
            suffix_text, score_color = get_score(distance)
            suffix_text = string.format(" [ %s ]", suffix_text)
        end
    end

    local full_text = string.format("%s%s%s%s", prefix_text, value_text, unit, not score_font and suffix_text or "")
    surface.SetFont("HudDefault")
    local text_w, text_h = surface.GetTextSize(full_text)
    if score_font then
        surface.SetFont(score_font)
        local score_w, score_h = surface.GetTextSize(suffix_text)
        text_w = text_w + score_w
        text_h = math.max(text_h, score_h)
        surface.SetFont("HudDefault")
    end
    draw.RoundedBox(8, x, y - margin_y, text_w + margin_x * 2, text_h + margin_y * 2, Color(0, 0, 0, 96))

    surface.SetTextPos(x + margin_x, y)
    surface.SetTextColor(255, 255, 255)
    surface.DrawText(prefix_text)
    if cm then
        surface.SetTextColor(GradientGYR(math.abs(distance) / 320))
    elseif distance < -3.2 then
        surface.SetTextColor(160, 0, 0)
    else
        surface.SetTextColor(0, 92, 179)
    end
    surface.DrawText(value_text)
    surface.SetTextColor(255, 255, 255)
    surface.DrawText(unit)
    if score_color then
        if score_font then
            surface.SetFont(score_font)
        end
        surface.SetTextColor(unpack(score_color))
        surface.DrawText(suffix_text)
    end
    return x + text_w + margin_x * 2 + space_x, y
end

local hud_hide = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
}

hook.Add("HUDShouldDraw", "ZMS.HideHUD", function(name) if hud_hide[name] then return false end end)
hook.Add("HUDPaint", "ZMS.HUDShouldDraw", function()
    if not LocalPlayer():GetNW2Bool("ZMS.CurrentTrain.Available") then return end
    local x, y
    x, y = draw_passengers()
    x, y = draw_distance(x, y)
end)

-- local function reposition_addons(delay)
--     timer.Create("ZMS.DSCPPanelReposition", delay or 1, 0, function()
--         print("Repositioning DSCPPanel...")
--         if not IsValid(MDispatcher.DSCPPanel) or not IsValid(MDispatcher.DPanel) or not IsValid(MDispatcher.SPanel) then return end
--         local dscp_h = MDispatcher.DSCPPanel:GetTall()
--         local dscp_y = ScrH() / 2 - dscp_h + 72
--         MDispatcher.DSCPPanel:SetY(dscp_y)
--         MDispatcher.DPanel:InvalidateLayout()
--         MDispatcher.SPanel:SetY(dscp_y + dscp_h + 5)
--         timer.Remove("ZMS.DSCPPanelReposition")
--         print("DSCPPanel repositioned")
--     end)
-- end

-- hook.Add("OnScreenSizeChanged", "ZMS.HudReposition", reposition_addons)
-- reposition_addons(10)
