local html_head = [[
<html>
    <head>
        <style>
            body {
                padding: 0 16px 0 16px;
                margin: 0;
                height: 100%;
                font-family: {{style.fonts.regular.family}};
                font-size: 10pt;
                font-weight: normal;
                color: #e0e0e0;
                background-color: #121212;
            }
            p {
                margin-left: 8px;
                margin-top: 4px;
            }
            h1 {
                font-family: {{style.fonts.server_name.family}};
                font-size: 24pt;
                font-weight: {{style.fonts.server_name.weight}};
                margin-bottom: 2px;
            }
            h2 {
                font-family: {{style.fonts.section_title.family}};
                font-size: 20pt;
                font-weight: {{style.fonts.section_title.weight}};
                margin-bottom: 2px;
            }
            h3 {
                font-family: {{style.fonts.subtitle.family}};
                font-size: 16pt;
                font-weight: {{style.fonts.subtitle.weight}};
                margin-bottom: 0;
            }
            h4 {
                font-family: {{style.fonts.regular.family}};
                font-size: 10pt;
                font-weight: bold;
                margin-bottom: 0;
                margin-left: 8px;
            }
            .figure {
                max-width: 85%;
                max-height: 650px;
            }
            .box {
                position: relative;
                border: 2px solid #2196F3;
                border-radius: 15px;
                padding: 0 8px 0 18px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                margin-top: 20px;
            }
            .box.active {
                border: 2px solid #4CAF50;
            }
            .box > p {
                margin-top: 20px;
            }
            .labels {
                position: absolute;
                top: -12px;
                left: 10px;
                display: flex;
                gap: 5px;
            }
            .label {
                background-color: #2196F3;
                color: white;
                padding: 4px 10px;
                border-radius: 14px;
                font-size: 8pt;
                font-weight: bold;
                white-space: nowrap;
            }
            .label.active {
                background-color: #4CAF50;
            }
        </style>
    </head>
    <body>
]]

local html_tail = [[
    </body>
</html>
]]

local function escape(str)
    return (str:gsub("<", "&lt;"):gsub(">", "&gt;"))
end


local PANEL = {}

function PANEL:Init()
    self.html = vgui.Create("DHTML", self)
    self.html:Dock(FILL)
    self.html:SetVisible(false)

    self.html_head = string.gsub(html_head, "{{(.-)}}", function(a)
        local _, value = ULib.findVar(a, ulx.motdSettings)
        return escape(value or "")
    end)
    self.html_tail = html_tail
    self.hide_other = true
end

function PANEL:SetGuide(guide_id)
    local guide_data = zguides.repo.global[guide_id]
    if not guide_data then guide_data = zguides.repo.trains[guide_id] end
    local guide_name, _, guide = unpack(guide_data or {nil, nil, nil})
    if not guide_name or not guide then
        ErrorNoHalt(string.format("No such guide found: %s\n", guide_id))
        self.html:SetVisible(false)
        return
    end

    local html_body = {""}
    for _, p in ipairs(guide) do
        local text
        if type(p) == "table" then
            local condition, true_text, false_text = unpack(p)
            if type(condition) == "table" then
                local active_labels, other_labels = LocalPlayer():GetActiveTrainLabels(condition, true)
                if self.hide_other and #active_labels == 0 then
                    text = nil
                else
                    text = zguides.TBox(true_text, active_labels, other_labels)
                end
            elseif condition() then
                text = true_text
            else
                text = false_text
            end
        elseif (
            not string.StartsWith(p, "<h") and
            not string.StartsWith(p, "<img") and
            not string.StartsWith(string.TrimLeft(p), "<div")
        ) then
            text = string.format("<p>%s</p>", p)
        else
            text = p
        end
        if text ~= nil then
            table.insert(html_body, text)
        end
    end
    self.html_body = table.concat(html_body, "\n        ")
    self.html:SetHTML(string.format("%s%s%s", self.html_head, self.html_body, self.html_tail))
    self.html:SetVisible(true)
    self.guide_id = guide_id
end

function PANEL:UpdatePage()
    if self.guide_id then
        self:SetGuide(self.guide_id)
    end
end

vgui.Register("ZMS.GuidePanel", PANEL, "Panel")


local MENU = {}

function MENU:Init()
    self:SetTitle("Гайды сервера Metrostroi PIVO")
    self:SetSize(math.min(ScrW() - 100, 1200), ScrH() - 80)
    self:SetVisible(true)
    self:SetDraggable(true)
    self:MakePopup()
    self:Center()

    self.sheet = self:Add("DPropertySheet")
    self.sheet:Dock(FILL)

    local guide_panels = {}
    local guides = LocalPlayer():GetZMSGuides()
    for _, guide in ipairs(guides) do
        local pnl = vgui.Create("ZMS.GuidePanel", self.sheet)
        self.sheet:AddSheet(guide.name, pnl)
        pnl:SetGuide(guide.id)
        table.insert(guide_panels, pnl)
    end

    self.bottom = self:Add("DPanel")
    self.bottom:SetPaintBackground(false)
    self.bottom:SetTall(16)
    self.bottom:Dock(BOTTOM)
    self.bottom_spacer = self:Add("DPanel")
    self.bottom_spacer:SetPaintBackground(false)
    self.bottom_spacer:SetTall(4)
    self.bottom_spacer:Dock(BOTTOM)

    self.hide_other = self.bottom:Add("DCheckBoxLabel")
    self.hide_other:SetText("Скрыть доп. инфу")
    self.hide_other:SetValue(true)
    self.hide_other:Dock(RIGHT)
    self.hide_other:SizeToContents()
    function self.hide_other:OnChange(val)
        for _, pnl in ipairs(guide_panels) do
            pnl.hide_other = val
            pnl:UpdatePage()
        end
    end
end

function MENU:OnScreenSizeChanged()
    self:SetSize(math.min(ScrW() - 100, 1200), ScrH() - 80)
end

vgui.Register("ZMS.GuideMenu", MENU, "DFrame")


concommand.Add("zms_labels", function()
    local ply = LocalPlayer()
    local idx2lb = zguides.GetTrainLabelTable()
    local data_chunks = math.ceil(#idx2lb / 32)
    local integer_values = {}
    for ch_idx = 1, data_chunks do
        table.insert(integer_values, ply:GetNW2Int("ZMS.TrainLabels." .. ch_idx, "nil"))
    end
    PrintTable({
        ["Integers"] = integer_values,
        ["Labels present"] = ply:GetAllTrainLabels(),
        ["Train class"] = ply:GetNW2String("ZMS.TrainClass", "nil"),
    })
end)
