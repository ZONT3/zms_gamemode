MEL.DefineRecipe("717_uavac_fix", "all")
function RECIPE:Inject(ent)
    local baseInitSystems = ent.InitializeSystems
    function ent.InitializeSystems(wagon)
        baseInitSystems(wagon)
        if not wagon.Systems.UAVAContact then
            wagon:LoadSystem("UAVAContact", "Relay", "Switch")
        end
    end

    local baseThink = ent.Think
    function ent.Think(wagon)
        local orRet = {baseThink(wagon)}
        if not SERVER then return unpack(orRet) end
        local toggle = wagon.UAVACToggle or wagon.UAVAContact or nil
        -- assert(toggle)
        if toggle and toggle.Value > 0.5 and wagon.UAVAC.Value < 0.5 then
            wagon.UAVAC:TriggerInput("Set", 1)
            wagon:PlayOnce("uava_reset", "bass", 1)
        end
        return unpack(orRet)
    end
end

function RECIPE:InjectNeeded(entclass)
    if not entclass:find("717") then return end
    if entclass == "gmod_subway_81-717_lvz" then return false end
    if entclass == "gmod_subway_81-717.9" then return false end

    local is_new_metrostroi = Metrostroi.Version > 1537278077
    if entclass == "gmod_subway_81-717_mvm" then return not is_new_metrostori end
    return is_new_metrostroi
end
