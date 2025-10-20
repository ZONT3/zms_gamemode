GM.Name = "Metrostroi (Sandbox)"
GM.Author = "ZONT_"
GM.Email = "N/A"
GM.Website = "N/A"

DeriveGamemode( "sandbox" )

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

-- sv("sv_debug.lua")
sv("sv_dependencies.lua")
sv("sv_restrictions.lua")
