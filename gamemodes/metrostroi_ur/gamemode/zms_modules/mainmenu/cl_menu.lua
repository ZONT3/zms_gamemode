local color_background = Color(216, 0, 205, 60)
local color_button_normal = Color(220, 220, 220)
local color_button_disabled = Color(220, 220, 220, 100)
local color_button_hover = Color(247, 230, 0)
local color_button_click = Color(247, 49, 0)

local margin = 16
local size_footer_h = 86
local size_menu_w = 480

local html_pages_cache = {}
local motd_shown = false

local footer_html = [[
<html>
    <head>
        <style>
            body {
                padding: 0 16px 0 16px;
                margin: 0;
                color: #fff;
                background-color: #0003;
                font-family: Roboto,system-ui,Avenir,Helvetica,Arial,sans-serif;

                display: flex;
                flex-direction: row;
                align-items: center;
                justify-content: space-between;
                max-width: 100vw;
                max-height: 100vh;
                overflow: hidden;
            }
            a {
                color: #fffb00;
                text-decoration-line: none;
            }
            a:hover {
                color: #ffbb00;
                text-decoration-line: underline;
            }
            code, .code {
                color: #fff;
                background-color: #0005;
                border: 1px solid #fff3;
                border-radius: 6px;
                font-family: 'Courier New', Courier, monospace;
                font-size: 12pt;
                padding: 2px 4px 2px 4px;
                text-decoration-line: none;
            }
            .code:hover {
                background-color: #1b15;
            }
            .container {
                display: flex;
                flex-direction: column;
                align-items: left;
                justify-content: center;
                gap: 4px;
            }
            .container.horizontal {
                flex-direction: row;
                justify-content: flex-end;
                gap: 16px;
            }
            .link, .link img {
                display: block;
                opacity: 0.5;
                width: 64px;
                height: 64px;
                cursor: pointer;
            }
            .link:hover {
                opacity: 1;
            }
        </style>
    </head>
    <body>
        <div class="container">
            {{server_credit_footer}}
            <span><a href="#" onclick="gmod.openUrl('https://steamcommunity.com/sharedfiles/filedetails/?id=3590738674')" class="code">metrostroi_ur</a> gamemode by <a href="#" onclick="gmod.openUrl('https:/\/steamcommunity.com/id/ZONT3/')">ZONT_</a></span>
            <span><a href="#" onclick="gmod.openUrl('https://steamcommunity.com/sharedfiles/filedetails/?id=261801217')" class="code">Metrostroi Subway Simulator</a> by Metrostroi Team & FoxWorks Aerospace s.r.o.</span>
        </div>
        <div class="container horizontal">
            {{server_links}}
        </div>
    </body>
</html>
]]


local function escape(str)
    return str:gsub("<", "&lt;"):gsub(">", "&gt;")
end

local html_variables = {
    server_name = escape(GetHostName()),
}

local function resolve_html_variables(html_str)
    return string.gsub(html_str, "{{(.-)}}", function(k)
        return html_variables[k] or ""
    end)
end

local function request_page(identifier)
    if not isstring(identifier) then return end
    net.Start("ZMS.PauseMenu.RequestPage")
        net.WriteString(identifier)
    net.SendToServer()
end


local PANEL = {}

function PANEL:Init()
    local succ, err = pcall(self.InitUnsafe, self)
    if not succ then
        ErrorNoHalt("Error at init PauseMenu", err)
    end
end

function PANEL:InitUnsafe()
    self:SetSize(ScrW(), ScrH())

    self.page = self:Add("DPanel")
    self.page.pause_menu = self
    self.page.Paint = function() end
    self.page.PerformLayout = function(this, w, h)
        if this.shown_panel then
            this.shown_panel:SetSize(w, h)
            this.shown_panel:SetPos(0, 0)
        end
    end

    local function prepare_html(html_pnl, html_identifier, local_html, local_vars)
        function html_pnl:OnDocumentReady()
            self:AddFunction("gmod", "openUrl", gui.OpenURL)
        end
        local html_string = local_html or not GetGlobalBool("ZMS.Debug", false) and html_identifier and html_pages_cache[html_identifier] or nil
        if html_string then
            for k, v in pairs(local_vars or {}) do html_variables[k] = v end
            html_pnl:SetHTML(resolve_html_variables(html_string))
        else
            html_pnl.html_identifier = html_identifier
            request_page(html_identifier)
        end
    end

    self.footer = self:Add("DHTML")
    prepare_html(self.footer, nil, footer_html)

    self.menu = self:Add("DScrollPanel")
    self.menu.pause_menu = self

    function self.menu:SetupElement(element)
        element:Dock(TOP)
        element:DockMargin(0, 0, 0, 5)
    end

    function self.menu:AddButton()
        local btn = self:Add("ZMS.PauseMenu.Button")
        self:SetupElement(btn)
        return btn
    end

    self.menu_tabs = {}
    hook.Run("ZMS.PauseMenu.InitTabs", self, prepare_html)

    function self.menu:AddTabsButtons()
        local pause_menu = self.pause_menu
        local menu_tabs = pause_menu.menu_tabs
        table.sort(menu_tabs, function(a, b)
            return not b[3] or a[3] and a[3] < b[3] or false
        end)
        self.tab_buttons = {}

        local function update_all()
            for _, btn in ipairs(self.tab_buttons) do
                if isfunction(btn.UpdateEnabled) then
                    btn:UpdateEnabled()
                end
            end
        end

        for idx, cfg in ipairs(menu_tabs) do
            local button = self:AddButton()
            local title, factory = unpack(cfg)
            if not isstring(title) or not (idx == 1 or isfunction(factory)) then continue end

            button:SetText(title)
            button.pause_menu = self.pause_menu

            button.DoClick = function(this)
                this.pause_menu:SetPage(idx)
                this.pause_menu.page.shown_panel = factory(this.pause_menu.page)
                this.pause_menu.page:InvalidateLayout()
                update_all()
            end
            button.UpdateEnabled = function(this)
                this:SetEnabled(this.pause_menu.tab_shown ~= idx)
            end
            button:UpdateEnabled()

            self.tab_buttons[idx] = button
        end

        if pause_menu.tab_shown > 0 then
            local btn = self.tab_buttons[pause_menu.tab_shown]
            btn:DoClick()
        end
    end

    self:SetPage(not motd_shown and 1 or 0)
    if not motd_shown then motd_shown = true end

    self.shown_at = SysTime()
    self:MakePopup(true)

    hook.Run("ZMS.PauseMenu.InitMenu", self.menu)
end

function PANEL:SetPage(page)
    if self.page.shown_panel then
        if isfunction(self.page.shown_panel.Remove) then
            self.page.shown_panel:Remove()
        end
        self.page.shown_panel = nil
    end
    self.tab_shown = page == 0 and not self:IsSmallVersion() and 1 or page
    self.menu:SetVisible(self.tab_shown == 0 or not self:IsSmallVersion())
end

function PANEL:AddMenuTab(title, factory, priority)
    table.insert(self.menu_tabs, {title, factory, priority})
end

function PANEL:IsSmallVersion()
    return self:GetWide() < 1250
end

function PANEL:OnScreenSizeChanged(_, _, w, h)
    self:SetSize(w, h)
    self:InvalidateLayout()
    self:SetPage(0)
end

function PANEL:PerformLayout(w, h)
    local small_version = w < 1250

    local footer_y = h - size_footer_h
    local menu_w = not small_version and size_menu_w or (w - margin * 2)
    local menu_h = footer_y - margin * 2
    local motd_w = not small_version and (w - margin * 3 - menu_w) or menu_w
    local motd_h = menu_h
    local motd_x = not small_version and (margin * 2 + menu_w) or margin

    self.page:SetPos(motd_x, margin)
    self.page:SetSize(motd_w, motd_h)
    self.menu:SetPos(margin, margin)
    self.menu:SetSize(menu_w, menu_h)
    self.footer:SetPos(0, footer_y)
    self.footer:SetSize(w, size_footer_h)
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(color_background)
    surface.DrawRect(0, 0, w, h)
    Derma_DrawBackgroundBlur(self, self.shown_at - 0.5)
end

function PANEL:Think()
end

vgui.Register("ZMS.PauseMenu", PANEL, "DPanel")


local BUTTON = {}

function BUTTON:Init()
    self:SetFont("CloseCaption_Bold")
end

function BUTTON:Paint(w, h)

end

function BUTTON:UpdateColours()
    if not self:IsEnabled()   				then return self:SetTextStyleColor(color_button_disabled) end
    if self:IsDown() or self.m_bSelected	then return self:SetTextStyleColor(color_button_click) end
    if self.Hovered							then return self:SetTextStyleColor(color_button_hover) end
    return self:SetTextStyleColor(color_button_normal)
end

vgui.Register("ZMS.PauseMenu.Button", BUTTON, "DButton")


ZMS = ZMS or {}

function ZMS.ClosePauseMenu()
    if isfunction(ZMS.PauseMenuPanel.Remove) then
        ZMS.PauseMenuPanel:Remove()
    end
    ZMS.PauseMenuPanel = nil
end

function ZMS.OpenPauseMenu()
    if ZMS.PauseMenuPanel then ZMS.ClosePauseMenu() end
    ZMS.PauseMenuPanel = vgui.Create("ZMS.PauseMenu")
end

function ZMS.TogglePauseMenu()
    if IsValid(ZMS.PauseMenuPanel) then
        ZMS.ClosePauseMenu()
    else
        ZMS.OpenPauseMenu()
    end
end

hook.Add("OnPauseMenuShow", "ZMS.PauseMenuInterception", function()
    ZMS.TogglePauseMenu()
    return false
end)

net.Receive("ZMS.PauseMenu.RecvPage", function()
    local ln = net.ReadUInt(32)
    local html_string = util.Decompress(net.ReadData(ln))
    html_string = resolve_html_variables(html_string)

    local r, g, b = ColorFromStr(net.ReadString())
    color_background = Color(r, g, b, 60)

    ln = net.ReadUInt(32)
    html_variables = util.JSONToTable(util.Decompress(net.ReadData(ln)))

    local menu_panel = ZMS.PauseMenuPanel
    if menu_panel and menu_panel.page and menu_panel.footer then
        if menu_panel.page.shown_panel and menu_panel.page.shown_panel.html_identifier then
            menu_panel.page.shown_panel:SetHTML(html_string)
            if not GetGlobalBool("ZMS.Debug", false) then
                html_pages_cache[menu_panel.page.shown_panel.html_identifier] = html_string
            end
        end
        if not menu_panel.footer.was_set then
            menu_panel.footer:SetHTML(resolve_html_variables(footer_html))
            menu_panel.footer.was_set = true
        end
    end
end)

function ulx.showMotdMenu()
    motd_shown = false
    ZMS.OpenPauseMenu()
end

-- timer.Simple(1, request_page)
-- concommand.Add("zms_motd_update", request_page)
