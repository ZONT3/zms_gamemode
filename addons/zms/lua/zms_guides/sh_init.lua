zguides = zguides or {}
zguides.repo = zguides.repo or {}
zguides.repo.trains = {}
zguides.repo.trains.order = {}
zguides.repo.global = {}
zguides.repo.global.order = {}

zguides.labels = zguides.labels or {}
zguides.labels.maps = zguides.labels.maps or {}
zguides.labels.trains = zguides.labels.trains or {}

zguides.cache = zguides.cache or {}
zguides.cache.idx2lb = zguides.cache.idx2lb or nil
zguides.cache.lb2idx = zguides.cache.lb2idx or nil
zguides.next_cache_upd = 0


--[[
    TEMPLATES
]]

function zguides.FncTHeader(lvl)
    return function(arg1, arg2)
        local text
        if not lvl then
            lvl = arg1
            text = arg2
        else
            text = arg1
        end
        return string.format("<h%d>%s</h%d>", lvl, text, lvl)
    end
end

zguides.THeader = zguides.FncTHeader()
zguides.THeader1 = zguides.FncTHeader(1)
zguides.THeader2 = zguides.FncTHeader(2)
zguides.THeader3 = zguides.FncTHeader(3)
zguides.THeader4 = zguides.FncTHeader(4)

function zguides.TOrderedList(prefix, entries)
    prefix = prefix or ""
    local digits = #tostring(#entries)
    local fmt = string.format("<b>%%s%%0%dd.</b> %%s", digits)
    for idx, entry in ipairs(entries) do
        entries[idx] = string.format(fmt, prefix, idx, entry)
    end
    return table.concat(entries, "<br>")
end

function zguides.TPicture(path, prefix_text)
    return string.format("%s<img class=\"figure\" src=\"asset://%s\">", prefix_text and (prefix_text .. "<br>") or "", path)
end

function zguides.TBox(text, active_labels, other_labels)
    local labels = {}
    for _, l in ipairs(active_labels or {}) do
        table.insert(labels, string.format("<span class=\"label active\">%s</span>", l))
    end
    for _, l in ipairs(other_labels or {}) do
        table.insert(labels, string.format("<span class=\"label\">%s</span>", l))
    end
    labels = table.concat(labels, "            \n")
    return string.format([[
    <div class="box%s">
        <div class="labels">
            %s
        </div>
        <p>%s</p>
    </div>
]], (active_labels and #active_labels > 0) and " active" or "", labels, text)
end

function zguides.TConditional(condition, true_text, false_text)
    return {condition, true_text, false_text}
end

-- labels..., text
function zguides.TTrainLabels(...)
    local labels = {...}
    local text = table.remove(labels, #labels)
    return {labels, text}
end

--[[
    LOGIC
]]

function zguides.FncMapCondition(...)
    local maps = {...}
    return function()
        local cur_map = game.GetMap()
        for _, value in ipairs(maps) do
            if string.match(cur_map, value) then
                return true
            end
        end
        return false
    end
end

function zguides.FncTrainCondition(true_train, ...)
    local false_patterns = {...}
    return function(train_class, train_ent, train_setup)
        if not string.match(train_class, true_train) then
            return false
        end
        for _, value in ipairs(false_patterns) do
            if string.match(train_class, value) then
                return false
            end
        end
        return true
    end
end

function zguides.FncTrainConditionAny(...)
    local true_patterns = {...}
    return function(train_class, train_ent, train_setup)
        for _, value in ipairs(true_patterns) do
            if string.match(train_class, value) then
                return true
            end
        end
        return false
    end
end

local function fnc_train_setup(any, values)
    return function(train_class, train_ent, train_setup)
        for _, value in ipairs(values) do
            local cond
            if istable(value) then
                local v, t = unpack(value)
                local setup_val = train_setup and train_setup[v] or nil
                if isfunction(t) then
                    cond = function() return t(setup_val) end
                else
                    cond = function() return setup_val == t end
                end
            else
                cond = function() return train_setup and train_setup[value] or false end
            end

            if not cond() and not any then
                return false
            elseif cond() and any then
                return true
            end
        end
        return not any
    end
end

function zguides.FncTrainSetupValues(...)
    local values = {...}
    return fnc_train_setup(false, values)
end

function zguides.FncTrainSetupValuesAny(...)
    local values = {...}
    return fnc_train_setup(true, values)
end

function zguides.FncMapLabel(...)
    local labels = {...}
    return function()
        for _, l in ipairs(labels) do
            local label_data = zguides.labels.maps[l]
            if label_data and label_data.condition and label_data.condition(game.GetMap()) then
                return true
            end
        end
        return false
    end
end

function zguides.FncTrainLabel(...)
    local labels = {...}
    return function(ply)
        if not ply and SERVER then return false end
        ply = ply or LocalPlayer()
        for _, l in ipairs(labels) do
            if ply:HasTrainLabel(l) then
                return true
            end
        end
        return false
    end
end

function zguides.FncOr(...)
    local conditions = {...}
    return function(...)
        for _, cond in ipairs(conditions) do
            if cond(...) then
                return true
            end
        end
        return false
    end
end

function zguides.FncAnd(...)
    local conditions = {...}
    return function(...)
        for _, cond in ipairs(conditions) do
            if not cond(...) then
                return false
            end
        end
        return true
    end
end

function zguides.FncNone(...)
    local conditions = {...}
    return function(...)
        for _, cond in ipairs(conditions) do
            if cond(...) then
                return false
            end
        end
        return true
    end
end

function zguides.RegisterMapLabel(label_id, display_name, condition)
    zguides.labels.maps[label_id] = {
        display_name = display_name,
        condition = condition
    }
end

function zguides.RegisterTrainLabel(label_id, display_name, condition)
    zguides.labels.trains[label_id] = {
        display_name = display_name,
        condition = condition
    }
end

function zguides.RegisterGlobalGuide(id_name, displ_name, condition, guide_tbl)
    -- if condition and not condition() then
    --     return
    -- end

    zguides.repo.global[id_name] = {
        displ_name, condition, guide_tbl
    }
    table.insert(zguides.repo.global.order, id_name)
end

function zguides.RegisterTrainGuide(id_name, displ_name, condition, guide_tbl)
    zguides.repo.trains[id_name] = {
        displ_name, condition, guide_tbl
    }
    table.insert(zguides.repo.trains.order, id_name)
end

function zguides.GetTrainLabelTable()
    if zguides.cache.idx2lb and zguides.cache.lb2idx and CurTime() < zguides.next_cache_upd then
        return zguides.cache.idx2lb, zguides.cache.lb2idx
    end

    local idx2lb = {}
    for label, _ in pairs(zguides.labels.trains) do
        table.insert(idx2lb, label)
    end
    table.sort(idx2lb)
    local lb2idx = {}
    for key, value in ipairs(idx2lb) do
        lb2idx[value] = key
    end
    zguides.next_cache_upd = CurTime() + 2.0
    zguides.cache.idx2lb = idx2lb
    zguides.cache.lb2idx = lb2idx
    return idx2lb, lb2idx
end


local ply_meta = FindMetaTable("Player")

function ply_meta:HasTrainLabel(label)
    local idx2lb, lb2idx = zguides.GetTrainLabelTable()
    local idx = lb2idx[label]
    if idx == nil then return false end

    local data_chunks = math.ceil(#idx2lb / 32)
    for ch_idx = 1, data_chunks do
        local bit_idx = idx - ((ch_idx - 1) * 32) - 1
        if bit_idx < 0 then return false end
        if bit_idx < 32 then
            local value = self:GetNW2Int("ZMS.TrainLabels." .. ch_idx, nil)
            if not value then return false end
            local bit_value = bit.band(bit.rshift(value, bit_idx), 1)
            return bit_value == 1
        end
    end
    return false
end

function ply_meta:GetAllTrainLabels()
    local idx2lb = zguides.GetTrainLabelTable()
    local result = {}
    for _, lb in ipairs(idx2lb) do
        result[lb] = self:HasTrainLabel(lb)
    end
    return result
end

function ply_meta:GetActiveTrainLabels(labels, display_names)
    local active = {}
    local other = {}
    for _, label in ipairs(labels) do
        local displ
        if display_names then
            displ = zguides.labels.trains[label]
            displ = displ and displ.display_name or label
        else
            displ = label
        end
        table.insert(self:HasTrainLabel(label) and active or other, displ)
    end
    return active, other
end

function ply_meta:GetZMSGuides()
    local guides = {}
    for _, repo in ipairs({zguides.repo.global, zguides.repo.trains}) do
        for _, id in ipairs(repo.order) do
            local guide_data = repo[id]
            if guide_data then
                local name, cond, tbl = unpack(guide_data)
                if tbl and (not cond or cond(self)) then
                    table.insert(guides, {
                        id = id,
                        name = name,
                        guide = tbl,
                    })
                end
            end
        end
    end
    return guides
end


local function guide_fnc(ply)
    ULib.clientRPC(ply, "ulx.ZMS.ShowMenu")
end

timer.Create("ZMS.Guides.ULXIntegration.Init", 4, 0, function()
    if not ulx or not ulx.command or not ULib then return end
    local com = ulx.command("ZMS Guides", "ulx guide", guide_fnc, "!guide" )
    com:defaultAccess(ULib.ACCESS_ALL)
    com:help("Открыть меню гайдов")

    if not SERVER then
        ulx.ZMS = ulx.ZMS or {}
        function ulx.ZMS.ShowMenu()
            vgui.Create("ZMS.GuideMenu")
        end
    end

    timer.Remove("ZMS.Guides.ULXIntegration.Init")
end)
