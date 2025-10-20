ZMS = ZMS or {}

util.AddNetworkString("ZMS.DispRoutes")

net.Receive("ZMS.DispRoutes", function(ln, ply)
    local tbl = ZMS.DispRoutesSv or {}
    net.Start("ZMS.DispRoutes")
        net.WriteTable(tbl)
    net.Send(ply)
end)

function ZMS.UpdDispRoutes(broadcast)
    local fl = file.Read("zms_disp_routes.json", "DATA")
    local tbl = fl and util.JSONToTable(fl) or {}
    ZMS.DispRoutesSv = tbl[game.GetMap()] or {}

    if broadcast then
        net.Start("ZMS.DispRoutes")
            net.WriteTable(ZMS.DispRoutesSv)
        net.Broadcast()
    end
end

timer.Create("ZMS.DispRoutesUpdate.SV", 15, 0, ZMS.UpdDispRoutes)
ZMS.UpdDispRoutes()
