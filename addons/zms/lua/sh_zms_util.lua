if SERVER then
    zms_cv_debug = CreateConVar("zms_debug", "0", FCVAR_ARCHIVE, "Enable general ZMS addon debug (UNSAFE!)", 0, 1)
    cvars.AddChangeCallback("zms_debug", function()
        SetGlobalBool("ZMS.Debug", zms_cv_debug:GetBool())
    end)
    SetGlobalBool("ZMS.Debug", zms_cv_debug:GetBool())
end

function zms_msgc(module_name, color, msg, ...)
    MsgC(color, "[ ZMS Addons")
    if module_name then
        MsgC(color, " | ", Color(255, 255, 255), module_name)
    end
    MsgC(color, " ]: ")

    local args = {...}
    if #args > 0 then
        MsgC(Color(255, 255, 255), string.format(msg, ...), "\n")
    else
        MsgC(Color(255, 255, 255), msg, "\n")
    end
end

function zms_log(module_name, msg, ...)
    zms_msgc(module_name, Color(200, 200, 0), msg, ...)
end

function zms_err(module_name, msg, ...)
    zms_msgc(module_name, Color(180, 0, 0), msg, ...)
end

function ColorFromStr(color_str)
    local color = color_str or "#000000"
    if #color == 7 then
        color = string.sub(color, 2)
    end
    if #color ~= 6 then
        return 0, 0, 0
    end
    color = tonumber(color, 16)
    local r = bit.band(bit.rshift(color, 16), 0xFF)
    local g = bit.band(bit.rshift(color, 8), 0xFF)
    local b = bit.band(color, 0xFF)
    return r, g, b
end

ZMS = ZMS or {}

function ZMS.InitHook(hook_name, identifier, refresh, init_fnc)
    ZMS.InitHooks = ZMS.InitHooks or {}
    local hook_identifier = string.format("%s:%s", hook_name, identifier)
    if refresh then
        if ZMS.InitHooks[hook_identifier] then
            init_fnc()
        else
            ZMS.InitHooks[hook_identifier] = true
        end
    end
    hook.Add(hook_name, identifier, init_fnc)
end

function ZMS.GetServerConfig()
    local cfg = {}
    hook.Run("ZMS.ServerConfig", cfg)
    return cfg
end
