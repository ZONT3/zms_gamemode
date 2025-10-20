util.AddNetworkString("ZMS.Ping.Send")
util.AddNetworkString("ZMS.Ping.Receive")

net.Receive("ZMS.Ping.Send", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local pos = net.ReadVector()
    local train_entid = net.ReadUInt(16)
    local button_name = net.ReadString()
    local train = Entity(train_entid)
    if not pos or not IsValid(train) then return end
    if string.Trim(button_name) == "" then button_name = nil end
    net.Start("ZMS.Ping.Receive")
        net.WriteVector(pos)
        net.WriteUInt(train:EntIndex(), 16)
        net.WriteUInt(ply:EntIndex(), 16)
    net.Broadcast()
    ulx.fancyLog(
        "#P указывает на \"#s\"",
        ply, button_name or "(неизвестно)"
    )
end)
