local sv, cl, sh
if SERVER then
    sv = include
    sh = function(path)
        AddCSLuaFile(path)
        include(path)
    end
    cl = CLIENT and sh or AddCSLuaFile
else
    sv = function() end
    sh = include
    cl = include
end

--[[
    SH and CL files
    shouldn't be loaded in timers, so here we go
]]

--[[ Basic ]]
sh("sh_zms_util.lua")
cl("zms_ui/cl_settings.lua")

--[[ Status ]]
sh("zms_base/sh_trains.lua")
cl("zms_base/cl_trains.lua")

--[[ UI Features ]]
cl("zms_ui/cl_utils.lua")
cl("zms_ui/cl_hud.lua")
cl("zms_ui/cl_pings.lua")

--[[ Guides ]]
sh("zms_guides/sh_init.lua")
sh("zms_guides_repo/sh_repo.lua")
cl("zms_guides/cl_guide_menu.lua")

--[[ Dispatcher Utils ]]
cl("zms_dispatcher/cl_disp_routes.lua")
cl("zms_dispatcher/cl_asnp.lua")

--[[ ATZ ]]
cl("zms_atz/cl_atz_menu.lua")

--[[ Immersive Radio ]]
cl("zms_radio/cl_radio.lua")

--[[
    SV files
    can be loaded in timers, so supports dependency awaiting
]]
local function init()
    if not Metrostroi or not Metrostroi.Version or Metrostroi.Version < 1537278077 then
        zms_err("INIT", "Incompatible Metrostroi version detected. Addon DISABLED.")
        return
    end

    --[[ Status ]]
    sv("zms_base/sv_trains.lua")
    sv("zms_base/sv_status.lua")

    --[[ UI Features ]]
    sv("zms_ui/sv_passengers.lua")
    sv("zms_ui/sv_station_distance.lua")
    sv("zms_ui/sv_pings.lua")

    --[[ GUIDES ]]
    sv("zms_guides/sv_init.lua")

    --[[ DISPATCHER UTILS ]]
    sv("zms_dispatcher/sv_disp_routes.lua")
    sv("zms_dispatcher/sv_asnp.lua")

    --[[ ATZ ]]
    sv("zms_atz/sv_atz.lua")
    sv("zms_atz/sv_atz_cases.lua")

    --[[ Immersive Radio ]]
    sv("zms_radio/sv_radio.lua")

    --[[ Misc ]]
    sv("zms_misc/sv_udochka_kills.lua")
end


local function check_deps()
    if not Metrostroi then return false, "Metrostroi Main Addon" end
    if not MetrostroiAdvanced then return false, "Metrostroi Advanced" end
    return true, nil
end

local init_timer = "ZMS.Init.WaitForDependencies"
timer.Create(init_timer, 0.5, 20, function()
    local result = check_deps()
    if not result then return end
    init()
    zms_log("INIT", "ZMS Addon initialized successfully.")
    timer.Remove(init_timer)
end)

timer.Simple(12, function()
    local result, reason = check_deps()
    if not result then
        zms_err("INIT", "Dependency not found: " .. reason .. ". Addon DISABLED.")
    end
end)

if SERVER then
    resource.AddFile("resource/localization/en/zms_general.properties")
    resource.AddFile("resource/localization/ru/zms_general.properties")
end
