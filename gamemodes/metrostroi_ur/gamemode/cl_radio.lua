local ptt_mode_cvar = CreateClientConVar("zms_radio_ptt_mode", "0", true, true, "Push-to-talk radio mode. 0: Talk to radio with Shift/Alt, 1: Always use radio, 2: Always use proximity", 0, 2)
local ptt_key_cvar = CreateClientConVar("zms_radio_key", "0", true, true, "Push-to-talk radio key. 0: Shift, 1: Alt", 0, 1)
local toggle_key_cvar = CreateClientConVar("zms_radio_toggle_key", "0", true, true, "Key to toggle proximity/radio chat instead of push-to-talk. Should be a {BUTTON_CODE} number.")
local show_note_cvar = CreateClientConVar("zms_radio_note", "1", true, false, "Show notification about immersive radio when it is enabled on server", 0, 1)

local note_message = table.concat({
    "На сервере включено иммерсивное радио. Это означает, что вы сможете общаться голосом на любом расстоянии только с диспетчером и только через поездную ",
    "или станционную радиостанцию. С другими игроками - только поблизости (как напрямую, так и через радио). Для разговора в радио, убедитесь, ",
    "что вы в кабине поезда со включенной радиостанцией, либо около станционного радио/телефона. Значок слева от этого сообщения подскажет вам об этом. ",
    "Удерживайте клавишу Shift при нажатии вашей клавишы войс-чата (х по умолчанию) для использования радио. Если нужна помощь - пишите в текстовый чат, ",
    "он по-прежнему доступен всегда. Выключить это сообщение можно в С-меню - Меню ДЦХ и Радио - Опции."
})

hook.Add("ZMS.Disp.CMenu", "ZMS.Radio.Menu", function(cm)
    if MDispatcher and MDispatcher.Dispatcher ~= "отсутствует" and MDispatcher.Dispatcher == LocalPlayer():Nick() or LocalPlayer():IsAdmin() then
        local csettings = cm:AddSubMenu("Установки диспетчера")
        local set_annonce = csettings:AddOption("Установить сообщение",
            function()
                Derma_StringRequest(
                    "Сообщение Диспетчера",
                    "Введите новое сообщение диспетчера. Оставьте поле пустым для очистки текущего.",
                    "", function(text) LocalPlayer():ConCommand("ulx disp_msg " .. text) end)
            end)
        set_annonce:SetIcon(#GetGlobal2String("ZMS.Radio.Message", "") > 0 and "icon16/tick.png" or "icon16/cross.png")
        local set_immersive = csettings:AddOption("Иммерсивное радио", function() LocalPlayer():ConCommand("ulx disp_immersive") end)
        set_immersive:SetIcon(GetGlobal2Bool("ZMS.Radio.Immersive", false) and "icon16/tick.png" or "icon16/cross.png")
    end
end)

hook.Add("ZMS.Disp.CMenu.ClientOptions", "ZMS.Radio.Menu.Options", function(copt)
    local op_radio_settings = copt:AddOption("Настройки радио", function() vgui.Create("ZMS.Radio.Options") end)
    op_radio_settings:SetIcon("icon16/cog_edit.png")
    local op_immersive_note = copt:AddOption("Заметка о радио", function() show_note_cvar:SetBool(not show_note_cvar:GetBool()) end)
    op_immersive_note:SetIcon(show_note_cvar:GetBool() and "icon16/tick.png" or "icon16/cross.png")
end)

local col_box = Color(0, 0, 0, 96)
local radio_online_box = Color(0, 220, 0, 96)
local radio_failed_box = Color(220, 0, 0, 96)
local transmit_icon = Material("icon16/transmit.png", "smooth")
local transmit_active_icon = Material("icon16/transmit_blue.png", "smooth")
local available_icon = Material("icon16/tick.png", "smooth")
local failed_icon = Material("icon16/cross.png", "smooth")

local scroll_progress = 0
local last_msg = ""
local scroll_delay_at_edge = 4.0
local last_scroll = 0
local px_per_sec = 140

hook.Add("HUDPaint", "ZMS.Radio.HUD", function()
    local message = GetGlobal2String("ZMS.Radio.Message", "")
    local has_message = #message > 0
    local personal_immersive = LocalPlayer():GetNW2Bool("ZMS.Radio.PersonalImmersive", false)
    local global_immersive = GetGlobal2Bool("ZMS.Radio.Immersive", false)
    local immersive = personal_immersive or global_immersive
    if not immersive and not has_message then return end

    local show_note = show_note_cvar:GetBool() and immersive

    local full_text = "Test string"
    local prefix_text = nil
    if has_message then
        prefix_text = "СООБЩЕНИЕ ДИСПЕТЧЕРА: "
        full_text = prefix_text .. message
    elseif show_note and global_immersive then
        prefix_text = "ВНИМАНИЕ: "
        message = note_message
        full_text = prefix_text .. message
    end

    surface.SetFont("CloseCaption_Bold")
    local text_w, text_h = surface.GetTextSize(full_text)

    local margin_x = 8
    local margin_y = 6

    local x = 8 + margin_x
    local y = 8 + margin_y
    if immersive then
        local mode = ptt_mode_cvar:GetInt()
        local transmit_state = mode == 0 and LocalPlayer():GetNW2Bool("ZMS.Radio.Transmitting", false) or mode == 1
        local transmitting = transmit_state and input.IsKeyDown(input.GetKeyCode(input.LookupBinding("+voicerecord", true)))
        local station = LocalPlayer():GetNW2Float("ZMS.Radio.OnStation", -1)
        local available = station >= 0 or LocalPlayer():EntIndex() == GetGlobal2Int("ZMS.Radio.Dispatcher", 0)
        local color = transmitting and available and radio_online_box or transmitting and not available and radio_failed_box or col_box
        draw.RoundedBox(8, 8, 8, text_h * 2 + margin_x * 3, text_h + margin_y * 2, color)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(transmit_state and transmit_active_icon or transmit_icon)
        surface.DrawTexturedRect(8 + margin_x, 8 + margin_y, text_h, text_h)
        surface.SetMaterial(available and available_icon or failed_icon)
        surface.DrawTexturedRect(8 + margin_x + text_h + margin_x, 8 + margin_y, text_h, text_h)
        surface.SetTextPos(8 + margin_x, 8 + margin_y)
        surface.SetTextColor(0, 0, 0)
        x = x + text_h * 2 + margin_x * 4
    end

    if prefix_text and message then
        local message_w = math.min(math.min(1280, ScrW()) - x - margin_x - 8, text_w)
        local scroll = message_w < text_w
        draw.RoundedBox(8, x - margin_x, y - margin_y, message_w + margin_x * 2, text_h + margin_y * 2, col_box)

        local x0 = x
        local y0 = y
        if scroll then
            if last_msg ~= message then
                scroll_progress = 0
                last_msg = message
                last_scroll = CurTime()
            end
            local dt = CurTime() - last_scroll
            if scroll_progress == 0 or scroll_progress >= text_w - message_w then
                if dt > scroll_delay_at_edge then
                    if scroll_progress > 0 then
                        scroll_progress = 0
                        last_scroll = CurTime()
                    else
                        scroll_progress = 1
                        last_scroll = CurTime()
                    end
                end
            else
                scroll_progress = math.min(scroll_progress + dt * px_per_sec, text_w - message_w + 1)
                last_scroll = CurTime()
            end
            x0 = x - scroll_progress
            y0 = y
        end
        render.SetScissorRect(x - 1, y - 1, x + message_w + 1, y + text_h + 1, true)
            surface.SetTextPos(x0, y0)
            surface.SetTextColor(255, 40, 40)
            surface.DrawText(prefix_text)
            surface.SetTextColor(255, 255, 255)
            surface.DrawText(message)
        render.SetScissorRect(0, 0, 0, 0, false)
    end
end)

net.Receive("ZMS.Radio.ToggleMode", function()
    ptt_mode_cvar:SetInt(ptt_mode_cvar:GetInt() == 1 and 2 or 1)
end)


local PANEL = {}

function PANEL:Init()
    self:SetSize(400, 190)
    self:SetTitle("Radio Options")
    self:Center()
    self:MakePopup()

    self.cb_ptt = self:Add("DCheckBoxLabel")
    self.cb_ptt:SetText("Push-to-talk")
    self.cb_ptt.OnChange = function(_, val)
        local mode = ptt_mode_cvar:GetInt()
        if val and mode == 0 then return end
        if not val and mode > 0 then return end
        val = val and 0 or 1
        if val == ptt_mode_cvar:GetInt() then return end
        ptt_mode_cvar:SetInt(val)
        self:Update()
    end

    self.ptt_label = self:Add("DLabel")
    self.ptt_label:SetAutoStretchVertical(true)

    self.cb_ptt_alt = self:Add("DCheckBoxLabel")
    self.cb_ptt_alt:SetText("Alt вместо Shift")
    self.cb_ptt_alt.OnChange = function(_, val)
        val = val and 1 or 0
        if val == ptt_key_cvar:GetInt() then return end
        ptt_key_cvar:SetInt(val)
        self:Update()
    end

    self.mode_button_label = self:Add("DLabel")
    self.mode_button_label:SetText("Смена режима:")

    self.binder = self:Add( "DBinder", frame )
    self.binder.OnChange = function(_, val)
        if val == toggle_key_cvar:GetInt() then return end
        toggle_key_cvar:SetInt(val)
        self:Update()
    end

    self:Update()
end

function PANEL:Update()
    local ptt = ptt_mode_cvar:GetInt() == 0
    self.cb_ptt:SetValue(ptt)
    if ptt then
        self.cb_ptt_alt:SetVisible(true)
        self.cb_ptt_alt:SetValue(ptt_key_cvar:GetInt() == 1)

        self.mode_button_label:SetVisible(false)
        self.binder:SetVisible(false)

        self.ptt_label:SetText(
[[Говорить в рацию при нажатой клавише Shift
и клавише войс-чата одновременно. Значок слева сверху
покажет, говорите ли вы в рацию. Если не нажать Shift,
или слева сверху - крестик, то вас слышат только игроки поблизости.]])
    else
        self.mode_button_label:SetVisible(true)
        self.binder:SetVisible(true)
        self.binder:SetValue(toggle_key_cvar:GetInt())

        self.cb_ptt_alt:SetVisible(false)

        self.ptt_label:SetText(
[[Менять режим указанной клавишей. Синий значок слева сверху
означает, что выбрана рация; оранжевый - чат только с игроками
поблизости. Если слева сверху - крестик, то вас слышат только
игроки поблизости в любом случае.]])
    end

    self.cb_ptt:Dock(TOP)
    self.ptt_label:Dock(TOP)
    self.ptt_label:SizeToContentsY()
    self.cb_ptt_alt:Dock(TOP)
    self.mode_button_label:Dock(TOP)
    self.binder:Dock(TOP)

    self:InvalidateLayout()
end

vgui.Register("ZMS.Radio.Options", PANEL, "DFrame")
