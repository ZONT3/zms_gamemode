DeriveGamemode( "sandbox" )

GM.Name = "Metrostroi Unranked (Sandbox)"
GM.Author = "ZONT_"
GM.Email = "N/A"
GM.Website = "N/A"

local sv, cl, sh
if SERVER then
    sv = include
    cl = AddCSLuaFile
    sh = function(path)
        AddCSLuaFile(path)
        include(path)
    end
else
    sv = function() end
    cl = include
    sh = include
end

sv("sv_debug.lua")
sv("sv_dependencies.lua")

sv("sv_restrictions.lua")

sv("sv_disp_routes.lua")
cl("cl_disp_routes.lua")

sv("sv_udochka_kills.lua")
sv("sv_asnp.lua")
cl("cl_asnp.lua")

sv("sv_pings.lua")
cl("cl_pings.lua")

sv("sv_atz.lua")
sv("sv_atz_cases.lua")
cl("cl_atz_menu.lua")

cl("cl_radio.lua")
sv("sv_radio.lua")
