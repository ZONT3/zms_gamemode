util.AddNetworkString("ZMS.PauseMenu.RecvPage")
util.AddNetworkString("ZMS.PauseMenu.RequestPage")


ZMS = ZMS or {}
ZMS.PauseMenu = ZMS.PauseMenu or {}

ZMS.PauseMenu.HtmlDefaults = {}
ZMS.PauseMenu.HtmlCompressed = {}
ZMS.PauseMenu.HtmlCompressedDurations = {}

function ZMS.PauseMenu.SvRegisterHtmlTab(identifier, default_html)
    ZMS.PauseMenu.HtmlDefaults[identifier] = default_html
end


local function escape(str)
    return str:gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function generate_credit(cfg)
    if not cfg.credit then return end
    local span = [[
<span><code>%s</code> server by <a href="#" onclick="gmod.openUrl('https://steamcommunity.com/profiles/%s')">%s</a></span>
]]
    return string.format(span, escape(cfg.server_name or GetHostName()), cfg.credit.author_steamid64 or "0", escape(cfg.credit.author or "unknown author"))
end

local function generate_server_dev_team(cfg)
    if not cfg.team then return end

    local sv_team = {}
    for _, x in ipairs(cfg.team.devs or {}) do
        table.insert(sv_team,
            string.format("<li>%s: <a href=\"#\" onclick=\"gmod.openUrl('https://steamcommunity.com/profiles/%s')\">%s</a></li>",
                x.role, x.steamid64, x.name))
    end
    sv_team = string.format("<ul>%s</ul>", table.concat(sv_team, "\n"))

    local p = [[
<h2>Сервер %s</h2>
<p>%s</p>
<p>%s</p>
]]
    return string.format(p, escape(cfg.server_name or GetHostName()), sv_team, cfg.team.description or "no description")
end

local function generate_links(cfg)
    if not cfg.menu_links then return end

    local links = {}
    for _, x in ipairs(cfg.menu_links) do
        table.insert(links, string.format("<a class=\"link\" href=\"#\" onclick=\"gmod.openUrl('%s')\"><img src=\"%s\" title=\"%s\"></img></a>", x.url, x.pic, x.title or ""))
    end
    return table.concat(links, "")
end

local function generate_addons()
    local result = {}
    local addons = engine.GetAddons()
    table.SortByMember(addons, "title", true)
    for _, addon in ipairs(addons) do
        if not addon.mounted then continue end
        if addon.wsid then
            table.insert(result, string.format("<li><b>%s</b> — <a href=\"#\" onclick=\"gmod.openUrl('https://steamcommunity.com/sharedfiles/filedetails/?id=%s')\">Steam Workshop</a></li>", addon.title, addon.wsid))
        else
            table.insert(result, string.format("<li><b>%s</b> — <i>Local</i>", addon.title))
        end
    end
    return string.format("<ul>\n%s\n</ul>", table.concat(result, "\n"))
end


local server_addons = generate_addons()

local html_variables = nil
local bgcol = nil

local function update_html_vars(arguments)
    if not html_variables then
        local cfg = ZMS.GetServerConfig()
        html_variables = {
            server_name = escape(GetHostName()),
            server_credit_footer = generate_credit(cfg),
            server_dev_team = generate_server_dev_team(cfg),
            server_links = generate_links(cfg),
            server_addons = server_addons,
        }
        html_variables = util.Compress(util.TableToJSON(html_variables))
        bgcol = cfg.menu_bgcolor
    end
end

net.Receive("ZMS.PauseMenu.RequestPage", function(_, ply)
    local identifier = net.ReadString()

    local html_default = ZMS.PauseMenu.HtmlDefaults[identifier]
    if not html_default then
        zms_err("PauseMenu", "Unknown identifier", identifier)
        return
    end

    local cb = function(html_str)
        update_html_vars()

        local html_compressed = ZMS.PauseMenu.HtmlCompressed[identifier]
        local html_compressed_duration = ZMS.PauseMenu.HtmlCompressedDurations[identifier]

        if not html_compressed or not html_compressed_duration or CurTime() > html_compressed_duration then
            html_compressed = util.Compress(html_str)
            ZMS.PauseMenu.HtmlCompressed[identifier] = html_compressed
            ZMS.PauseMenu.HtmlCompressedDurations[identifier] = CurTime() + (zms_cv_debug:GetBool() and 1 or 180)
        end

        net.Start("ZMS.PauseMenu.RecvPage")
            net.WriteUInt(#html_compressed, 32)
            net.WriteData(html_compressed)
            net.WriteString(bgcol or "#d800cd")
            net.WriteUInt(#html_variables, 32)
            net.WriteData(html_variables)
        net.Send(ply)
    end

    local fname = string.format("zms_motd/%s.txt", identifier)
    if not file.Exists("zms_motd", "DATA") then
        file.CreateDir("zms_motd")
    end
    if not file.Exists(fname, "DATA") then
        file.Write(fname, html_default)
        cb(html_default)
    else
        file.AsyncRead(fname, "DATA", function(_, _, status, data)
            if status < 0 then
                zms_err("MUR.PauseMenu", "Failed to read motd file, status", status)
                cb(html_default)
            elseif status == FSASYNC_OK then
                cb(data)
            end
        end)
    end
end)
