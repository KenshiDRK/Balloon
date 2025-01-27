local json = require("json")
local https = require("ssl.https")
local url = require("socket.url")
local glossary = require("glossary")
local res = require("resources")
local plurals_list = res.items_grammar
https.TIMEOUT = 0.5

local inverted_glossary = {}
for original, replacement in pairs(glossary) do
    inverted_glossary[replacement] = original
end

local plurals_dict = {}
for _, item in pairs(plurals_list) do
    plurals_dict[item.plural] = true
end

local function escape_special_characters(phrase)
    local special_characters = "%%%^%$%(%)%.%[%]%*%+%-%?%'"
    return (phrase:gsub("([" .. special_characters .. "])", "%%%1"))
end

local function apply_glossary(text, glossary)
    for phrase, replacement in pairs(glossary) do
        local escaped_phrase = escape_special_characters(phrase)
        text = text:gsub(escaped_phrase, replacement)
    end
    return text
end

local function restore_glossary(text, inverted_glossary)
    for replacement, original in pairs(inverted_glossary) do
        local escaped_replacement = escape_special_characters(replacement)
        text = string.gsub(text, escaped_replacement, original)
    end
    return text
end

local no_translate = {}
local function apply_colored_text(text)
    local count = 0
    local modified_text = text
    for word in string.gmatch(text, "@%d%d%d%d(.-)@93537") do
        count = count + 1
        local escaped_word = escape_special_characters(word)
        table.insert(no_translate, word)
        modified_text = string.gsub(modified_text, escaped_word, " " .. count .. " ", 1)
    end
    return modified_text
end

local function restore_colored_text(text)
    for k = 1, #no_translate do
        text = string.gsub(text, " " .. k .. " %.?%s*", no_translate[k])
    end
    no_translate = {}
    return text
end

local function adjust_articles_for_plurals(text, language)
    if language then
        local singular_articles = language.singular
        local plural_articles = language.plural
        for plural in pairs(plurals_dict) do
            local escaped_plural = escape_special_characters(plural)
            text = text:gsub(" " .. singular_articles.masc .. "%s+(@%d%d%d%d" .. escaped_plural .. "@93537)", " " .. plural_articles.masc .. " %1")
            text = text:gsub(" " .. singular_articles.fem .. "%s+(@%d%d%d%d" .. escaped_plural .. "@93537)", " " .. plural_articles.fem .. " %1")
        end
    end
    return text
end

local function make_url(text, language)
    local modified_text = apply_colored_text(text)
    modified_text = apply_glossary(modified_text, glossary)
    return 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl='.. language ..'&dt=t&q='.. url.escape(modified_text)
end

function get_translation(text, language)
    local url = make_url(text, language.code)
    local response_body = {}
    local success, status_code, headers, status_text = https.request{
        url = url,
        sink = ltn12.sink.table(response_body)
    }

    if not success or status_code ~= 200 then
        return nil
    end

    local reply = table.concat(response_body)
    
    if not reply then
        return nil
    end
    
    local data, decode_err = json.decode(reply)

    if not data or decode_err then
        return nil
    end

    local output_table = {}
    for _, v in ipairs(data[1] or {}) do
        if not v[8][1][2] then --make sure to use the online model
            table.insert(output_table, v[1])
        else
            return nil
        end
    end

    local final_text = restore_glossary(table.concat(output_table), inverted_glossary)
    final_text = restore_colored_text(final_text)
    final_text = adjust_articles_for_plurals(final_text, language.articles)

    return final_text
end