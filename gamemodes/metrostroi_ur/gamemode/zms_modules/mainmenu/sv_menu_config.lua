local motd_html_default = [[
<html>
    <head>
        <style>
            body {
                padding: 0;
                margin: 0;
                height: 100%;
                color: #fff;
                background-color: transparent;
            }
        </style>
    </head>
    <body>
        Lorem ipsum PIVO
    </body>
</html>
]]

util.AddNetworkString("ZMS.PauseMenu.RecvMotd")
util.AddNetworkString("ZMS.PauseMenu.RequestMotd")

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
local motd_compressed = nil
local motd_compressed_duration = nil
local bgcol = nil
net.Receive("ZMS.PauseMenu.RequestMotd", function(_, ply)
    local cb = function(motd_html)
        if not html_variables or not motd_compressed or not motd_compressed_duration or CurTime() > motd_compressed_duration then
            local cfg = ZMS.GetServerConfig()
            html_variables = {
                server_name = escape(GetHostName()),
                server_credit_footer = generate_credit(cfg),
                server_dev_team = generate_server_dev_team(cfg),
                server_links = generate_links(cfg),
                server_addons = server_addons,
            }
            html_variables = util.Compress(util.TableToJSON(html_variables))

            motd_compressed = util.Compress(motd_html)
            motd_compressed_duration = CurTime() + (zms_cv_debug:GetBool() and 1 or 180)

            bgcol = cfg.menu_bgcolor
        end

        net.Start("ZMS.PauseMenu.RecvMotd")
            net.WriteUInt(#motd_compressed, 32)
            net.WriteData(motd_compressed)
            net.WriteString(bgcol or "#d800cd")
            net.WriteUInt(#html_variables, 32)
            net.WriteData(html_variables)
        net.Send(ply)
    end

    if not file.Exists("zms_motd.txt", "DATA") then
        file.Write("zms_motd.txt", motd_html_default)
        cb(motd_html_default)
    else
        file.AsyncRead("zms_motd.txt", "DATA", function(_, _, status, data)
            if status < 0 then
                zms_err("MUR.PauseMenu", "Failed to read motd file, status", status)
                cb(motd_html_default)
            elseif status == FSASYNC_OK then
                cb(data)
            end
        end)
    end
end)
