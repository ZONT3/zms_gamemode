ZMS = ZMS or {}
ZMS.Ping = ZMS.Ping or {}
ZMS.Ping.Data = ZMS.Ping.Data or {}

-- Spizheno from Metrostroi Addon
local function FindAimButton()
    local ply = LocalPlayer()
    local train = nil
    if IsValid(ply.InMetrostroiTrain) and ply.InMetrostroiTrain.ButtonMap then
        train = ply.InMetrostroiTrain
    else
        local weapon = IsValid(LocalPlayer():GetActiveWeapon()) and LocalPlayer():GetActiveWeapon():GetClass()
        if weapon ~= "train_kv_wrench" and weapon ~= "train_kv_wrench_gold" then return end
        train = util.TraceLine({
            start = LocalPlayer():GetPos(),
            endpos = LocalPlayer():GetPos() - LocalPlayer():GetAngles():Up() * 100,
            filter = function( ent ) if ent.ButtonMap ~= nil then return true end end
        }).Entity
        if not IsValid(train) then
            train = util.TraceLine({
                start = LocalPlayer():EyePos(),
                endpos = LocalPlayer():EyePos() + LocalPlayer():EyeAngles():Forward() * 300,
                filter = function( ent ) if ent.ButtonMap ~= nil then return true end end
            }).Entity
        end
        if not IsValid(train) then return end
    end

    local panel, panelDist = nil, 1e9
    for kp, pan in pairs(train.ButtonMap) do
        if not train:ShouldDrawPanel(kp) then continue end
        if pan.aimedAt and (pan.buttons or pan.sensor or pan.mouse) and pan.aimedAt < panelDist then
            panel = pan
            panelDist = pan.aimedAt
        end
    end

    if not panel then return end
    if panel.aimX and panel.aimY and (panel.sensor or panel.mouse) and math.InRangeXY(panel.aimX, panel.aimY, 0, 0, panel.width, panel.height) then return end
    if not panel.buttons then return end
    local buttonTarget
    for _, button in pairs(panel.buttons) do
        if (train.Hidden[button.PropName] or train.Hidden.button[button.PropName]) and (not train.ClientProps[button.PropName] or not train.ClientProps[button.PropName].config or not train.ClientProps[button.PropName].config.staylabel) then continue end
        if (train.Hidden[button.ID] or train.Hidden.button[button.ID]) and (not train.ClientProps[button.ID] or not train.ClientProps[button.ID].config or not train.ClientProps[button.ID].config.staylabel) then continue end
        if button.w and button.h then
            if panel.aimX >= button.x and panel.aimX <= (button.x + button.w) and panel.aimY >= button.y and panel.aimY <= (button.y + button.h) then
                buttonTarget = button
            end
        else
            local dist = math.Distance(button.x, button.y, panel.aimX, panel.aimY)
            if dist < (button.radius or 10) then
                buttonTarget = button
            end
        end
    end

    return buttonTarget or nil, panel or nil, train or nil
end

local angle_zero = Angle(0, 0, 0)

local function PingButton()
    if not IsValid(LocalPlayer()) then return end
    if not LocalPlayer():Alive() then return end

    local button, panel, train = FindAimButton()
    if not button or not panel or not IsValid(train) then return end

    local button_pos = Vector(button.x, -button.y, 0)
    if button.w and button.h then
        button_pos.x = button_pos.x + button.w / 2
        button_pos.y = button_pos.y - button.h / 2
    end
    button_pos:Mul(panel.scale or 1)

    local button_train = LocalToWorld(button_pos, angle_zero, panel.pos, panel.ang)
    -- local button_world = train:LocalToWorld(button_train)

    net.Start("ZMS.Ping.Send")
        net.WriteVector(button_train)
        net.WriteUInt(train:EntIndex(), 16)
        net.WriteString(button.tooltip or "")
    net.SendToServer()
end

net.Receive("ZMS.Ping.Receive", function()
    local pos = net.ReadVector()
    local train_idx = net.ReadUInt(16)
    local ply_idx = net.ReadUInt(16)
    local train = Entity(train_idx)
    local ply = Entity(ply_idx)
    if not IsValid(ply) or not ply:Alive() or not IsValid(train) then return end

    ZMS.Ping.Data[ply_idx] = {
        name = ply:Nick(),
        color = team.GetColor(ply:Team()),
        pos = pos,
        time = CurTime() + 5.0,
        train = train,
    }
end)

hook.Add("PlayerButtonDown", "ZMS.Pings.MouseDown", function(ply, button)
    if button ~= MOUSE_5 and button ~= KEY_P then return end
    if not IsFirstTimePredicted() then return end
    timer.Simple(0, PingButton)
end)


local period = 0.5
local sine_period = math.pi / period
local max_size = 1.0
local min_size = 0.2
local max_distance2 = 6500 * 6500

hook.Add("PostDrawTranslucentRenderables", "ZMS.Pings.Draw3D", function()
    local ply = LocalPlayer()
    for _, ping_data in pairs(ZMS.Ping.Data) do
        if not ping_data or not IsValid(ping_data.train) or not ping_data.pos then continue end
        if CurTime() >= ping_data.time then continue end
        local pos = ping_data.train:LocalToWorld(ping_data.pos)
        if pos:DistToSqr(ply:GetPos()) > max_distance2 then continue end

        local scale = (math.sin((CurTime() + (ping_data.time % 10)) * sine_period) + 1) / 2
        local size = Lerp(scale, min_size, max_size)
        ping_data.color.a = 255 - 100 * scale
        render.SetColorMaterial()
        render.DrawSphere(pos, size, 24, 24, ping_data.color)
    end
end)


local spikeH = 24
local margin = 16
local edgePad = 8
local maxScaleDist2 = 50 * 50
local font = "DermaDefaultBold"

-- 2D ping box rendering
hook.Add("HUDPaint", "ZMS.Pings.Draw2D", function()
    local scrW, scrH = ScrW(), ScrH()
    local ply = LocalPlayer()

    for _, ping_data in pairs(ZMS.Ping.Data) do
        if not ping_data or not IsValid(ping_data.train) or not ping_data.pos then continue end
        if CurTime() >= ping_data.time then continue end
        local pos3d = ping_data.train:LocalToWorld(ping_data.pos)
        if pos3d:DistToSqr(ply:GetPos()) > max_distance2 then continue end

        local pos = pos3d:ToScreen()
        local color = Color(ping_data.color.r, ping_data.color.g, ping_data.color.b, 220)
        local name = ping_data.name or "???"
        local boxW, boxH = 120, 32
        local dist2 = ply:EyePos():DistToSqr(pos3d)
        local pointerOffset = math.Clamp(Lerp(dist2 / maxScaleDist2, 50, 8), 8, 50)

        local x, y = pos.x, pos.y
        local onScreen = pos.visible and x > 0 and x < scrW and y > 0 and y < scrH

        -- Clamp to screen edge if off-screen
        local pointerX, pointerY = x, y - pointerOffset
        if not onScreen then
            local cx, cy = scrW / 2, scrH / 2
            local dx, dy = pointerX - cx, pointerY - cy
            local angle = math.atan2(dy, dx)
            local edgeX = math.Clamp(cx + math.cos(angle) * (cx - margin), edgePad, scrW - edgePad)
            local edgeY = math.Clamp(cy + math.sin(angle) * (cy - margin), edgePad, scrH - edgePad)
            pointerX, pointerY = edgeX, edgeY
        end

        surface.SetFont(font)
        local textW, textH = surface.GetTextSize(name)
        boxW = math.max(boxW, textW + 16)
        boxH = math.max(boxH, textH + 8)

        -- Box position: above pointer if possible, else below
        local boxX = pointerX - boxW / 2
        local boxY = pointerY - spikeH - boxH
        local spikeUp = false
        if boxY < margin then
            pointerY = pointerY + pointerOffset * 2
            boxY = pointerY + spikeH + edgePad
            spikeUp = true
        end

        if boxX < edgePad then
            boxX = edgePad
        elseif boxX + boxW > scrW - edgePad then
            boxX = scrW - boxW - edgePad
        end

        -- Draw rounded box
        draw.RoundedBox(8, boxX, boxY, boxW, boxH, color)

        -- Draw player name centered
        draw.SimpleText(name, font, boxX + boxW / 2, boxY + boxH / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if onScreen then
            -- Draw spike pointer
            surface.SetDrawColor(color)
            draw.NoTexture()
            local spikeMidX = pointerX
            if not spikeUp then
                surface.DrawPoly({
                    {x = spikeMidX, y = pointerY},
                    {x = spikeMidX - 8, y = boxY + boxH + 4},
                    {x = spikeMidX + 8, y = boxY + boxH + 4},
                })
            else
                surface.DrawPoly({
                    {x = spikeMidX, y = pointerY},
                    {x = spikeMidX + 8, y = boxY - 4},
                    {x = spikeMidX - 8, y = boxY - 4},
                })
            end
        end
    end
end)

concommand.Add("zms_find_button", function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then return end
    local tr = util.QuickTrace(LocalPlayer():GetShootPos(), LocalPlayer():GetAimVector() * 1000, LocalPlayer())
    local train = tr.Entity
    if not IsValid(train) or not train.ButtonMap then
        LocalPlayer():ChatPrint("You need to be looking at a train to use this command.")
        return
    end

    local buttons = {}
    for kp, panel in pairs(train.ButtonMap) do
        if not train:ShouldDrawPanel(kp) then continue end
        for kb, button in pairs(panel.buttons or {}) do
            local button_pos = Vector(button.x, -button.y, 0)
            if button.w and button.h then
                button_pos.x = button_pos.x + button.w / 2
                button_pos.y = button_pos.y - button.h / 2
            end
            button_pos:Mul(panel.scale or 1)
            button_pos = LocalToWorld(button_pos, angle_zero, panel.pos, panel.ang)
            table.insert(buttons, { button = button.tooltip or "", pos = button_pos, data = {
                button = button,
                hidden = train.Hidden[button.ID] or train.Hidden.button[button.ID] or false
            } })
        end
    end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Train Interactable")
    frame:SetSize(400, 900)
    frame:Center()
    frame:MakePopup()
    local blist = vgui.Create("DListView", frame)
    blist:Dock(FILL)
    blist:SetMultiSelect(false)
    blist:AddColumn("Interactable")

    local field = vgui.Create("DTextEntry", frame)
    field:Dock(TOP)
    field:SetPlaceholderText("Search...")
    field.OnChange = function(self)
        local search_text = string.lower(self:GetValue())
        local apply_query = #search_text >= 2 and not string.StartsWith(search_text, "search")
        blist:Clear()
        for _, btn in ipairs(buttons) do
            if not apply_query or string.find(string.lower(btn.button), search_text) then
                local line = blist:AddLine(btn.button)
                line:SetValue(1, btn.button)
                line.data = btn
            end
        end
    end

    local button = vgui.Create("DButton", frame)
    button:SetText("Ping")
    button:Dock(BOTTOM)
    button.DoClick = function()
        if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then return end
        if not IsValid(train) then return end

        local sel_idx = blist:GetSelectedLine()
        if not sel_idx then return end
        local data = blist:GetLine(sel_idx)
        if not data then return end
        data = data.data
        if not data or not data.button or not data.pos then return end

        PrintTable(data.data or {})
        net.Start("ZMS.Ping.Send")
            net.WriteVector(data.pos)
            net.WriteUInt(train:EntIndex(), 16)
            net.WriteString(data.button)
        net.SendToServer()
    end

    timer.Simple(0, function() field.OnChange(field) end)
end)
