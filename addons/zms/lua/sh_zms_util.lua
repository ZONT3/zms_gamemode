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
