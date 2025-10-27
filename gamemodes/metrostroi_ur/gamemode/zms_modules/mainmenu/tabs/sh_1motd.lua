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
            }

            a:hover {
                color: #ffbb00;
            }

            code {
                background-color: #0005;
                border: 1px solid #fff3;
                border-radius: 6px;
                font-family: 'Courier New', Courier, monospace;
                font-size: 12pt;
                padding: 2px 4px 2px 4px;
            }

            code.bk {
                background-color: rgb(133, 163, 0, 0.67);
            }
            code.kl3 {
                background-color: rgb(32, 163, 0, 0.67);
            }
            code.kl2 {
                background-color: rgb(0, 163, 78, 0.67);
            }
            code.kl1 {
                background-color: rgb(0, 163, 141, 0.67);
            }
            code.mod {
                background-color: rgb(133, 163, 0, 0.67);
            }
            code.io {
                background-color: rgb(118, 74, 168, 0.67);
            }
            code.instr {
                background-color: rgb(124, 0, 173, 0.67);
            }

            .logo {
                height: 6em;
                padding: 1.5em;
                will-change: filter;
                transition: filter .3s;
                animation: logo-spin infinite 10s linear;
            }

            .logo:hover {
                filter: drop-shadow(0 0 2em #440EE6AA);
            }

            @keyframes logo-spin {
                0% {
                    transform: rotate(0)
                }

                to {
                    transform: rotate(360deg)
                }
            }
        </style>
    </head>
    <body>
        <div class="header-large">
            <a href="#" onclick="gmod.openUrl('https://pivo.rgsv.ru/')">
                <img class="logo" alt="Pivo logo" src="https://pivo.rgsv.ru/PIVO_logo_512px.png">
            </a>
            <h1>Metrostroi PIVO</h1>
        </div>

        <h2>О сервере</h2>
        <p>Просто пиво. Редактируйте файл <code>garrysmod/data/zms_motd/motd.txt</code> для написания этой страницы.</p>
        <p>Для создания новой страницы, примеры можно найти в <code>gamemodes/metrostroi_ur/gamemode/zms_modules/mainmenu/tabs</code> <a href="#" onclick="gmod.openUrl('https://steamcommunity.com/sharedfiles/filedetails/?id=3590738674')">этого</a> аддона.</p>
        <p>Ниже приведены примеры оформления</p>
        
        <p>
            Вот <a href="#" onclick="gmod.openUrl('https://steamcommunity.com/sharedfiles/filedetails/?id=3122071743')">коллекция сервера</a>.
            Подпишись на нее, чтобы точно не было Error-ов и других проблем.
        </p>
        
        <p>
            If you don't know nor understand the rules, it won't save you from getting banned. Use Google Translate if you REALLY want to stay at the server for whatever reason.
            <br>
            Незнание правил не освобождает от их соблюдений. Хороший способ не быть забаненым - прочитать правила.
        </p>
        <p>Если ты новичок в игре - обязательно ознакомься с обучающими видео в интернете.</p>

        <h2>Правила</h2>
        <u><b>TL;DR</b> Не мешать другим игрокам, не гадить на линии, станциях, станционных и парковых путях, слушать диспетчера и инструкторов, избегать конфликтов.</u>

        <h3>Основные правила сервера в игре</h3>
        <ol>
            <li>Не нарушать правила передвижения подвижного состава</li>
            <li>Не мешать играть другим игрокам</li>
            <li>заполните меня...</li>
        </ol>

        <h3>Правила сообщества (чат, войс, дискорд)</h3>
        <ol>
            <li>Не переходить на личности</li>
            <li>Соблюдать основные правила Discord-сообществ</li>
            <li>Запрещено обсуждать (гео-)политику, оскорблять по расовому/гражданскому/политическому признаку, осуждать взгляды, навязывать взгляды</li>
            <li>Запрещено использовать оскорбительные ники, особенно пересекающиеся с предыдущим пунктом</li>
        </ol>
    </body>
</html>
]]

ZMS.PauseMenu.RegisterHtmlTab("motd", "О Сервере (MOTD)", default_html)
