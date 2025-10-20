MEL.DefineRecipe("asnp_new", {
    "gmod_subway_81-717_6",
    "gmod_subway_81-717_5m",
    "gmod_subway_81-717_5a",
    "gmod_subway_81-717_mvm",
    "gmod_subway_81-717_ars_minsk",
    "gmod_subway_81-720",
    "gmod_subway_81-721",
    "gmod_subway_81-720_1",
    "gmod_subway_81-721_1",
    "gmod_subway_81-720a",
    "gmod_subway_81-721a",
    "gmod_subway_81-740_4_mvm",
    "gmod_subway_ezh3ru1",
})

RECIPE.Description = "ASNP Firmware mod. by ZONT_"

function RECIPE:Inject(ent)
    if not isfunction(ent.TrainSpawnerUpdate) then
        function ent.TrainSpawnerUpdate(wagon) end
    end

    MEL.InjectIntoSharedFunction(ent, "Think", function(wagon)
        if not wagon.ASNP then return end
        if wagon.ASNP_OLD then
            if wagon.SyncAsnpAt and CurTime() >= wagon.SyncAsnpAt then
                local slave_found = false
                for _, w in pairs(wagon.WagonList) do
                    if w.SyncAsnpAt and wagon ~= w then
                        slave_found = true
                        w.SyncAsnpAt = nil
                    end
                end
                if not slave_found then return end
                wagon.SyncAsnpAt = nil
                wagon.ASNP:UpdateBoards()
                wagon.ASNP:SyncASNP()
            end
            return
        end
        if wagon:GetNW2Int("ZMS.ASNP.Firmware", 1) ~= 2 then return end

        wagon.ASNP_OLD = wagon.ASNP
        wagon.Systems.ASNP = nil
        wagon:LoadSystem("ASNP", "81_71_ASNP_ZMS")

        if CLIENT and not istable(wagon.ASNP_OLD) then
            wagon.ASNP = wagon.ASNP_OLD
        end

        if SERVER then
            wagon.ASNP:Trigger("R_ASNPPath", false)
            wagon.SyncAsnpAt = CurTime() + 2.5
        end
    end, -1)
end

function RECIPE:InjectSpawner(ent)
    if ent:find("721") then
        return
    end
    MEL.AddSpawnerField(ent, {
        "ZMS.ASNP.Firmware",
        "Прошивка АСНП",
        "List",
        {"Старая", "Новая"},
        2
    })
end

