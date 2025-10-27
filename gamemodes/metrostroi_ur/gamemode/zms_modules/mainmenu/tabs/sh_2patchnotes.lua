if not CLIENT then return end

local html_body = [[
<html>
    <head>
        <style>
            body {
                padding: 0 16px 0 16px;
                margin: 0;
                color: #fff;
                background-color: transparent;
                font-family: Roboto,system-ui,Avenir,Helvetica,Arial,sans-serif;
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
            .focus {
                color: #fffb00;
                font-weight: bold;
            }
        </style>
    </head>
    <body>
        <h1>Патчноут</h1>
        {{patchnotes}}
    </body>
</html>
]]

local patchnotes_repo = {}

ZMS = ZMS or {}
ZMS.PauseMenu = ZMS.PauseMenu or {}

function ZMS.PauseMenu.RegisterPatchnote(name, tbl)
    if tbl.timestamp then tbl = { tbl } end
    for _, pn in ipairs(tbl) do
        pn.name = name
        if pn.timestamp then
            table.insert(patchnotes_repo, pn)
        end
    end
end

hook.Add("ZMS.PauseMenu.InitTabs", "ZMS.PauseMenu.InitTabs.Patchnote", function(menu_panel, prepare_html)
    patchnotes_repo = {}
    hook.Run("ZMS.PauseMenu.InitPatchnotes")
    table.SortByMember(patchnotes_repo, "timestamp")

    local patchnotes = {}
    local cur_name = nil
    for _, pn in ipairs(patchnotes_repo) do
        local pn_str = cur_name ~= pn.name and { string.format("<h2>%s</h2>", pn.name) } or { }
        cur_name = pn.name

        table.insert(pn_str, string.format("<h3>%s — %s</h3>", pn.title or "", os.date("%B %d %Y", pn.timestamp)))
        if pn.description then
            table.insert(pn_str, string.format("<p>%s</p>", pn.description))
        end
        if istable(pn.features) and #pn.features > 0 then
            table.insert(pn_str, "<ul>")
            for _, feat in ipairs(pn.features) do
                table.insert(pn_str, string.format("<li>%s</li>", feat))
            end
            table.insert(pn_str, "</ul>")
        end
        if not pn.description and not (istable(pn.features) and #pn.features > 0) then
            table.insert(pn_str, "<p><i>Нет описания. Хоть что-то обновили?</i></p>")
        end
        table.insert(patchnotes, table.concat(pn_str, "\n"))
    end

    menu_panel:AddMenuTab("Патчноут", function(root)
        local pnl = root:Add("DHTML")
        prepare_html(pnl, nil, html_body, { patchnotes = table.concat(patchnotes, "\n") })
        return pnl
    end, 2)
end)


hook.Add("ZMS.PauseMenu.InitPatchnotes", "ZMS", function()
    -- https://currentmillis.com/
    ZMS.PauseMenu.RegisterPatchnote("ZONT's Metrostroi Addon", {
        timestamp = 1761596810, title = "Пре-Релиз 1.0",
        description = "Началное пре-релизное состояние аддона",
        features = {
            "HUD",
            "Отметки на панелях",
            "Утилиты диспетчера",
            "Иммерсивное радио",
            "Скрипты для АТЗ",
            "Прошивка АСНП",
            "Категоризированное спавнменю",
            "Удочка под напряжением убивает",
            "<code>ZMS.Trains</code> API (WIP)",
        }
    })

    ZMS.PauseMenu.RegisterPatchnote("Metrostroi Gamemode", {
        timestamp = 1761596815, title = "Альфа 0.1",
        description = "Начальное состояние аддона первой версии в ограниченном релизе",
        features = {
            "Главное меню",
            "Телепорты из главного меню",
        }
    })
end)