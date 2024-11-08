local json = require("json")
local http = require("socket.http")
local url = require("socket.url")
http.TIMEOUT = 0.5

function get_translation(text, language)
    local no_translate = {}
    local count = 0

    -- Ajustes de capitalización específicos en `text`
    text = string.gsub(text, "Sir ", "sir ")
    text = string.gsub(text, "Chieftainness ", "chieftainness ")
    
    -- Crear una copia temporal `temp_text` para ciertos ajustes de capitalización y reemplazos temporales
    local temp_text = text

    -- Ajustes de capitalización específicos solo en `temp_text`
    temp_text = string.gsub(temp_text, "The ", "the ")
    temp_text = string.gsub(temp_text, "Our ", "our ")
    temp_text = string.gsub(temp_text, "And ", "and ")
    temp_text = string.gsub(temp_text, "Your ", "your ")
    

    -- Buscar y reemplazar patrones específicos en `text`, uno por uno

    -- 1. Palabras con el patrón "@XXXX@RESET"
    for word in string.gmatch(text, "@%u%u%u%u(.-)@R3S3T") do
        word = string.gsub(word, "%+", "%%+")
        word = string.gsub(word, "%-", "%%-")
        word = string.gsub(word, "%.", "%%.")
        count = count + 1
        table.insert(no_translate, word)
        text = string.gsub(text, word, "@PLACEHOLDER" .. count)
    end

    -- 2. Patrón para "Nombre Apellido" (por ejemplo, "John Smith")
    for word in string.gmatch(temp_text, "%u%l+ %u%l+") do
        count = count + 1
        table.insert(no_translate, word)
        text = string.gsub(text, word, "@PLACEHOLDER" .. count)
    end

    -- 3. Patrón para posesivos como "John's House"
    for word in string.gmatch(text, "%u%l+'s %u%l+") do
        count = count + 1
        table.insert(no_translate, word)
        text = string.gsub(text, word, "@PLACEHOLDER" .. count)
    end

    -- 4. Patrón específico para la palabra "Louverance"
    for word in string.gmatch(text, "Louverance") do
        count = count + 1
        table.insert(no_translate, word)
        text = string.gsub(text, word, "@PLACEHOLDER" .. count)
    end

    -- Codificación del texto para la URL
    local str = url.escape(text)

    -- Petición HTTP para la traducción
    local translated_str = http.request('http://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=' .. language .. '&dt=t&q=' .. str)
    if not translated_str then
        return "Error: No se pudo obtener la traducción."
    end

    -- Decodificar la respuesta JSON
    local data = json.decode(translated_str)
    if not data then
        return "Error: No se pudo decodificar la respuesta de traducción."
    end

    -- Construcción de la cadena traducida
    local output_table = {}
    for _, v in ipairs(data[1]) do
        table.insert(output_table, v[1])
    end
    local output = table.concat(output_table)

    -- Reemplazar placeholders con las palabras originales
    for k = 1, #no_translate do
       output = string.gsub(output, "@PLACEHOLDER" .. k, no_translate[k])
    end

    return output
end