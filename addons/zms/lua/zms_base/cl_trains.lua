ZMS = ZMS or {}
ZMS.Players = ZMS.Players or {}

local PANEL = {}

function PANEL:Init()
    self:SetTitle("Trains on map")
    self:SetSize(400, 800)

    self.list = self:Add("DTree")
    self.list:Dock(FILL)

    self.buttons = self:Add("DPanel")
    self.buttons:Dock(BOTTOM)
    self.buttons:SetTall(24)

    self.buttons.close = self.buttons:Add("DButton")
    self.buttons.close:SetText("Закрыть")
    self.buttons.close:Dock(LEFT)
    self.buttons.close.DoClick = function()
        self:Close()
    end

    self.buttons.action = self.buttons:Add("DButton")
    self.buttons.action:Dock(RIGHT)
    self.buttons.action:SetVisible(false)

    self.buttons.teleport = self.buttons:Add("DButton")
    self.buttons.teleport:SetText("Телепорт")
    self.buttons.teleport:Dock(RIGHT)
    self.buttons.teleport.DoClick = function()
        local selected = self.list:GetSelectedItem()
        if not selected or not selected.wag then
            return
        end
        local wag = Entity(selected.wag)
        local pos = IsValid(wag) and wag:GetPos() or nil
        if pos then
            net.Start("ZMS.Trains.Teleport")
                net.WriteVector(pos)
            net.SendToServer()
        end
    end
end

function PANEL:Setup(trains, action)
    self.list:Clear()
    if action == ZMS.Trains.RM or action == ZMS.Trains.RM_SILENT then
        self.buttons.action:SetText("Удалить")
        self.buttons.action:SetVisible(true)
        self.buttons.action.DoClick = function()
            local selected = self.list:GetSelectedItem()
            if not selected or not selected.wag then
                return
            end
            if selected.isadmin and not LocalPlayer():IsAdmin() then
                Derma_Message("You cannot remove this train because it is owned by an admin.", "Error", "OK")
                return
            end
            if selected.train then
                local data = util.Compress(table.concat(selected.train, ","))
                local ln = #data
                net.Start("ZMS.Trains.Remove")
                    net.WriteUInt(ln, 32)
                    net.WriteData(data, ln)
                    net.WriteBool(action == ZMS.Trains.RM_SILENT)
                net.SendToServer()
            else
                local data = util.Compress(tostring(selected.wag))
                local ln = #data
                net.Start("ZMS.Trains.Remove")
                    net.WriteUInt(ln, 32)
                    net.WriteData(data, ln)
                    net.WriteBool(action == ZMS.Trains.RM_SILENT)
                net.SendToServer()
            end
            if selected.train_node and selected.train_node:GetChildNodeCount() <= 1 then
                selected.train_node:Remove()
            else
                selected:Remove()
            end
        end
    else
        self.buttons.action:SetVisible(false)
    end

    for tidx, train in ipairs(trains) do
        if #train.wagons == 0 then
            continue
        end

        local tn = self.list:AddNode(string.format(
            "%s | %s%s", train.head_type,
            train.owner_disconnected and "(DISCONNECTED) " or "",
            train.owner_name or "Unknown"
        ))
        tn.isadmin = train.owner_isadmin
        tn.wag = train.wagons[1]
        tn.train = train.wagons
        for idx, wag_type in ipairs(train.types) do
            local wag = tn:AddNode(wag_type)
            wag.wag = train.wagons[idx]
            wag.isadmin = train.owner_isadmin
            wag.train_node = tn
        end
    end

    self:InvalidateLayout()
end

vgui.Register("ZMS.Trains.List", PANEL, "DFrame")

local function ShowTrains(trains, action)
    local panel = vgui.Create("ZMS.Trains.List")
    panel:Setup(trains, action)
    panel:Center()
    panel:MakePopup()
end

net.Receive("ZMS.Trains.ShowList", function()
    local ln = net.ReadUInt(32)
    local trains = util.JSONToTable(util.Decompress(net.ReadData(ln)))
    local action = net.ReadUInt(16)

    ShowTrains(trains, action)
end)

function ZMS.Players.GetPosition()
    if ZMS.Players.cached_position then
        return ZMS.Players.cached_position
    end
    return {}
end

net.Receive("ZMS.Players.UpdPosition", function()
    local ln = net.ReadUInt(16)
    local pos = net.ReadData(ln)
    ZMS.Players.cached_position = util.JSONToTable(util.Decompress(pos))
end)
