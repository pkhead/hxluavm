function table.find(t, q)
    for i, v in pairs(t) do
        if v == q then
            return i
        end
    end
    return nil
end

_G.stringx = {}

function stringx.split_space(str)
    local t = {}
    for w in str:gmatch("%S+") do
        table.insert(t, w)
    end
    return t
end

---@param str string
---@param delim string
---@param plain boolean?
---@return string[]
function stringx.split(str, delim, plain)
    if plain == nil then
        plain = true
    end

    local t = {}
    local i = 1
    while true do
        local s, e = string.find(str, delim, i, plain)
        if not s then
            t[#t+1] = string.sub(str, i)
            break
        end

        t[#t+1] = string.sub(str, i, s-1)
        i=e+1
    end

    return t
end