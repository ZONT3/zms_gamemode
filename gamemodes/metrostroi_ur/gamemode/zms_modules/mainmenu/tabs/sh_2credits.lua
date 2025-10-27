local default_html = [[
<html>
    <head>
        <style>
            *::-webkit-scrollbar {
                width: 5px;
                height: 5px
            }

            *::-webkit-scrollbar-track {
                background: #0004;
                border-radius: 10px
            }

            *::-webkit-scrollbar-thumb {
                background: #fff4;
                border-radius: 10px
            }

            *::-webkit-scrollbar-thumb:hover {
                background: #fff7
            }

            body {
                padding: 0;
                margin: 0;
                /* height: 100%; */
                color: #fff;
                background-color: transparent;
                font-family: Roboto,system-ui,Avenir,Helvetica,Arial,sans-serif;
            }

            .header-large {
                display: flex;
                flex-direction: row;
                justify-content: flex-start;
                align-items: center;
                gap: 2rem;
                margin-top: 1rem;
                padding-left: 1rem;
            }

            h1 {
                font-size: 3.2em;
                line-height: 1.1
            }

            a {
                color: #fffb00;
                text-decoration-line: none;
            }

            a:hover {
                color: #ffbb00;
                text-decoration-line: underline;
            }

            code {
                background-color: #0005;
                border: 1px solid #fff3;
                border-radius: 6px;
                font-family: 'Courier New', Courier, monospace;
                font-size: 12pt;
                padding: 2px 4px 2px 4px;
            }
        </style>
    </head>
    <body>
        {{server_dev_team}}
        <h2>Gamemode</h2>
        <ul>
            <li><b>ZONT's Metrostroi Scripts</b>: <a href="#" onclick="gmod.openUrl('https://steamcommunity.com/id/ZONT3/')">ZONT_</a></li>
            <li><b>Metrostroi Gamemode</b> (metrostroi_ur): <a href="#" onclick="gmod.openUrl('https://steamcommunity.com/id/ZONT3/')">ZONT_</a></li>
        </ul>
        <h2>Аддоны на сервере</h2>
        {{server_addons}}
    </body>
</html>
]]

ZMS.PauseMenu.RegisterHtmlTab("credits", "Разработчики", default_html)
