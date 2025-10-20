timer.Simple(1, function()
    function Metrostroi.GetPhrase(phrase)
        if not Metrostroi.CurrentLanguageTable then
            MsgC(Color(255, 0, 0), "No Language Table!")
            return
        end

        local orig_phrase = phrase
        if not Metrostroi.CurrentLanguageTable[phrase] then
            local path = string.Split(phrase, ".")
            if #path > 2 and path[1] == "Entities" then
                table.remove(path, 1)
                path[1] = "Common"
                phrase = table.concat(path, ".")
            end
        end

        if not Metrostroi.CurrentLanguageTable[phrase] then
            MsgC(Color(255, 0, 0), "No phrase:", Color(0, 255, 0), orig_phrase, "\n")
            return orig_phrase
        end
        return Metrostroi.CurrentLanguageTable[phrase]
    end
end)
