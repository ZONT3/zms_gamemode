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

local function include_dir(dir)
    local files, dirs = file.Find(dir .. "/*", "LUA")

    for _, fname in ipairs(files) do
        local fpath = string.format("%s/%s", dir, fname)
        if string.StartsWith(fname, "sv_") then
            sv(fpath)
            print("include sv", fpath)
        elseif string.StartsWith(fname, "cl_") then
            cl(fpath)
            print("include cl", fpath)
        else
            sh(fpath)
            print("include sh", fpath)
        end
    end

    for _, dname in ipairs(dirs) do
        include_dir(string.format("%s/%s", dir, dname))
    end
end

-- sv("sv_debug.lua")
sv("sv_dependencies.lua")
sv("sv_restrictions.lua")

include_dir("metrostroi_ur/gamemode/zms_modules")
