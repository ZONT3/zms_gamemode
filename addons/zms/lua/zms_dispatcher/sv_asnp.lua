ZMS = ZMS or {}
ZMS.ASNP = ZMS.ASNP or {}

util.AddNetworkString("ZMS.DispAsnp.Update")

local function GetAsnpData(train)
    local sys = IsValid(train) and train.ASNP or nil
    if not sys then return nil end
    if sys.State ~= 7 then
        return { Active = false, RouteNumber = tonumber(sys.RouteNumber) or -1 }
    end

    local d = { Active = true, RouteNumber = tonumber(sys.RouteNumber) or -1 }

    local announcer_val = train:GetNW2Int("Announcer", 1)
    local cfg = Metrostroi.ASNPSetup[announcer_val] and Metrostroi.ASNPSetup[announcer_val][sys.Line]
    -- PrintTable(cfg)
    if cfg then
        if cfg.Loop and sys.LastStation == 0 then
            d.LastStation = "Кольцевой"
        else
            d.LastStation = cfg[sys.Path and sys.FirstStation or sys.LastStation][2]
        end
        d.Station = cfg[sys.Station][2]
        d.Arrived = sys.Arrived
        d.Line = cfg.Name
        d.Path = sys.Path and 2 or 1
    else
        d.Operational = false
    end

    d.LockedL = sys.K1 == 0
    d.LockedR = sys.K2 == 0

    d.Operational = d.Operational ~= false
    return d
end

local function UpdateAsnpData()
    ZMS.ASNP.Cache = ZMS.ASNP.Cache or {}
    local data = {}

    for _, ply in player.Iterator() do
        local train = ply:GetTrain()
        if IsValid(train) then
            local ent_id = train:EntIndex()
            ZMS.ASNP.Cache[ent_id] = train
            for _, wagon in ipairs(train.WagonList or {}) do
                if IsValid(wagon) then
                    local wag_id = wagon:EntIndex()
                    if wag_id ~= ent_id then
                        -- Будет рандомная хуйня, если в более чем одной кабине состава есть игроки, но похуй
                        ZMS.ASNP.Cache[wag_id] = nil
                    end
                end
            end
        end
    end

    for _, ent_id in ipairs(table.GetKeys(ZMS.ASNP.Cache)) do
        local train = ZMS.ASNP.Cache[ent_id]
        if not IsValid(train) then
            ZMS.ASNP.Cache[ent_id] = nil
        else
            local sys = GetAsnpData(train)
            if sys then
                table.insert(data, sys)
            end
        end
    end

    table.SortByMember(data, "RouteNumber", true)
    ZMS.ASNP.Data = data
    -- PrintTable(ZMS.ASNP.Data)
end

timer.Create("ZMS.ASNP.Update", 2, 0, UpdateAsnpData)

net.Receive("ZMS.DispAsnp.Update", function(_, ply)
    local data = util.Compress(util.TableToJSON(ZMS and ZMS.ASNP and ZMS.ASNP.Data or {}))
    local ln = #data
    net.Start("ZMS.DispAsnp.Update")
        net.WriteUInt(ln, 32)
        net.WriteData(data, ln)
    net.Send(ply)
end)
