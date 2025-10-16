local guides = {
    -- GENERAL
    "zms_general",

    -- MAPS
    "gm_metro_jar_imagine_line",

    -- TRAINS
    "train_717",
    "train_760",
}

local incl
if SERVER then
    incl = function(file)
        AddCSLuaFile(file)
        include(file)
    end
else
    incl = function(file)
        include(file)
    end
end

for _, value in ipairs(guides) do
    incl(value .. ".lua")
end
