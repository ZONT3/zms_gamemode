local function apply_udochka_damage(ply, ent, attacker)
    local pos = ent:GetPos()
    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetScale(1)
    effectdata:SetMagnitude(2)
    util.Effect("ElectricSpark", effectdata, true, true)

    ent:EmitSound(string.format("ambient/energy/spark%d.wav", math.random(1, 6)), SNDLVL_90dB)

    -- local d = DamageInfo()
    -- d:SetDamage(ply:Health())
    -- d:SetAttacker(attacker or ply)
    -- d:SetInflictor(ent)
    -- d:SetDamageType(DMG_SHOCK)
    -- ply:TakeDamageInfo(d)

    ply:Kill()
end

local function on_pickup(ply, ent)
    if not IsValid(ent) or ent:GetClass() ~= "gmod_track_udochka" or not ent.VMF then return end
    if tonumber(ent.VMF.power) ~= 1 then return end
    ulx.fancyLog("#P не соблюдает технику безопасности", ply)
    apply_udochka_damage(ply, ent)
end

hook.Add("OnPhysgunPickup", "ZMS.UdochkaKills.Physgun", on_pickup)
hook.Add("OnPlayerPhysicsPickup", "ZMS.UdochkaKills.Arms", on_pickup)
