function GradientColor(x, ...)
    local colors = {...}
    if #colors == 1 then
        return colors[1]
    elseif #colors < 1 then
        return nil
    end

    x = math.Clamp(x, 0, 1)
    x = x * (#colors - 1)
    local i = math.floor(x) + 1
    if i >= #colors then
        i = i - 1
    end

    x = x - i + 1
    local lhs_color = colors[i]
    local rhs_color = colors[i + 1]
    return {
        Lerp(x, lhs_color[1], rhs_color[1]),
        Lerp(x, lhs_color[2], rhs_color[2]),
        Lerp(x, lhs_color[3], rhs_color[3]),
    }
end

function GradientGYR(x)
    return unpack(GradientColor(x, {0, 255, 0}, {255, 255, 0}, {255, 0, 0}))
end
