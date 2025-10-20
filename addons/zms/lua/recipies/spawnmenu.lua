MEL.DefineRecipe("categorized_spawnmenu", "all")

RECIPE.Description = "Categorized spawnmenu"

function RECIPE:Init()
    self.Specific.SpawnerFieldsToModify = {
        Texture = "Body",
        MaskType = "Body",
        BodyType = "Body",
        Type = "Body",
        HasMezhvag = "Body",
        DirtLevelCustom = "Body",
        Halogen = "Body",

        CabTexture = "Cabine.Visuals",
        KVSoundsType = "Cabine.Visuals",
        Cabin_glass = "Cabine.Visuals",
        icons = "Cabine.Equipment",
        Lighter = "Cabine.Equipment",
        RepairBook = "Cabine.Equipment",
        Smart = "Cabine.Equipment",
        RingType = "Cabine.Configuration",
        Cran = "Cabine.Configuration",
        ["ZMS.ASNP.Firmware"] = "Cabine.Configuration",
        ARSType = "Cabine.Console",
        KVTypeCustom = "Cabine.Console",
        VUDType = "Cabine.Console",

        PassTexture = "Interior",
        interrior_nameplate = "Interior",
        interrior_type = "Interior",
        Salon_glass = "Interior",
        Adverts = "Interior",

        BPSNType = "ExternalSounds",
        Anchoring = "ExternalSounds",
        PadSquealing = "ExternalSounds",
        ResonanceInterior = "ExternalSounds",
    }
end

local function getSpawnerEntclass(ent_or_entclass)
    local ent_class = MEL.GetEntclass(ent_or_entclass)
    if table.HasValue(MEL.TrainFamilies["717_714_mvm"], ent_class) then ent_class = "gmod_subway_81-717_mvm_custom" end
    if table.HasValue(MEL.TrainFamilies["717_714_lvz"], ent_class) then ent_class = "gmod_subway_81-717_lvz_custom" end
    return ent_class
end

function RECIPE:InjectSpawner(ent_class)
    ent_class = getSpawnerEntclass(ent_class)
    local fields_mod = MEL.RecipeSpecific.SpawnerFieldsToModify
    -- I assume there is no another option to ensure that our inject is last
    timer.Simple(0, function()
        local spawner = MEL.EntTables[ent_class].Spawner
        if not spawner then return end
        for i, field in pairs(spawner) do
            field = MEL.Helpers.SpawnerEnsureNamedFormat(field)
            if istable(field) then
                local field_mod = fields_mod[field.Name or ""]
                if not field_mod then continue end

                local section, subsection = unpack(string.Split(field_mod, "."))
                field.Section = section or field.Section or nil
                field.Subsection = subsection or field.Subsection or nil
                spawner[i] = field
            end
        end
    end)
end

