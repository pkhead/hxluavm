local cparser = {}
local conf = require("generator.conf")
local inspect = require("generator.inspect")

local tinsert = table.insert

-- local c_symbols = {"(", ")", ";", "*", ","}
-- local c_symbols = {string.byte("();*,", 1, -1)}
local c_symbols = {
    ";",
    "(", ")", "[", "]", "{", "}",
    "!", "%", "^", "&", "*", "-", "=", "+", "/", ";", "~", "<", ">", ",",
    "//", "/*", "*/",
}
table.sort(c_symbols, function(a, b)
    return string.len(a) > string.len(b)
end)

local whitespace = {string.byte(" \t\n", 1, -1)}
local preproc_symbol = string.byte("#")
local quote_symbol = string.byte("\"")

---@param stream Stream
local function identify_symbol(stream)
    for _, candidate in ipairs(c_symbols) do
        -- if string.sub(str, strindex, strindex + string.len(candidate) - 1) == candidate then
        if stream:read(string.len(candidate)) == candidate then
            return candidate
        end
    end
    return nil
end

local function make_token(type, str, pos)
    local line = -1
    local file = "?"
    if pos then
        line = pos.line
        file = pos.file
    end

    return {
        type = type,
        str = str,
        line = line,
        file = file
    }
end

---@param stream Stream
---@param pos {line:integer, file:string}
local function tokenize_c_line(stream, pos)
    local tokens = {}
    local tmpbuf = {}
    local depth = 0

    local function flush()
        if tmpbuf[1] then
            table.insert(tokens, make_token(
                "word",
                string.char(table.unpack(tmpbuf)),
                pos
            ))

            for i=1, #tmpbuf do
                tmpbuf[i] = nil
            end
        end
    end
    
    while not stream:eof() do
        while stream:readchar() == preproc_symbol do
            flush()
            stream:skip(2)

            local preproc_data = {}
            local is_in_str = false

            while true do
                local c = stream:popchar()
                if not is_in_str and (c == 10 or c == 32) then
                    tinsert(preproc_data, table.concat(tmpbuf))
                    tmpbuf = {}

                    if c == 10 then
                        break
                    end
                else
                    if c == quote_symbol then
                        is_in_str = not is_in_str
                    end

                    tinsert(tmpbuf, string.char(c))
                end
            end

            pos.line = tonumber(preproc_data[1]) --[[@as integer]]
            pos.file = string.sub(preproc_data[2], 2, -2)
        end

        if depth == 0 and stream:read(1) == ";" then
            flush()
            table.insert(tokens, make_token("symbol", ";", pos))
            stream:skip(1)
            break
        end

        local sym = identify_symbol(stream)

        if sym then
            flush()

            if sym == "//" then
                stream:skip(2)
                while stream:popchar() ~= 10 do end
            elseif sym == "/*" then
                stream:skip(2)

                while true do
                    if stream:eof() then
                        goto loop_end
                    end

                    local sym = identify_symbol(stream)
                    if sym then
                        stream:skip(string.len(sym))
                        if sym == "*/" then
                            break
                        end
                    else
                        stream:skip(1)
                    end
                end
            else
                table.insert(tokens, make_token("symbol", sym, pos))
                stream:skip(string.len(sym))

                if sym == "{" then
                    depth=depth+1
                elseif sym == "}" then
                    depth=depth-1
                end
            end
        else
            local char = stream:popchar()

            if table.find(whitespace, char) then
                flush()

                if char == 10 then
                    pos.line=pos.line+1
                end
            else
                table.insert(tmpbuf, char)
            end
        end
    end
    ::loop_end::
    flush()
    
    return tokens
end

local function token_check(tok, type, v)
    return tok.type == type and tok.str == v
end

local function tok_error(tok, msg)
    error(("%s:%i: %s"):format(tok.file, tok.line, msg), 2)
end

local function assert_type(tok, type, msg)
    if tok.type ~= type then
        error(("%s:%i: %s"):format(tok.file, tok.line, msg or ("expected " .. type)), 2)
    end
end

local function assert_token_check(tok, type, str, msg)
    if not token_check(tok, type, str) then
        error(("%s:%i: %s"):format(tok.file, tok.line, msg or ("expected %s \"%s\""):format(type, str)), 2)
    end
end

local export_defines = {"LUA_API", "LUALIB_API", "LUAMOD_API"}

local function parse_type_name(tokens, index)
    assert_type(tokens[index], "word")
    local tmp = {tokens[index].str}
    index=index+1

    while true do
        local possible_modifer = tmp[#tmp]
        if possible_modifer == "const" or possible_modifer == "unsigned" or possible_modifer == "struct" then
            table.insert(tmp, " ")
            table.insert(tmp, tokens[index].str)
        elseif token_check(tokens[index], "symbol", "*") or token_check(tokens[index], "symbol", "[") or token_check(tokens[index], "symbol", "]") then
            table.insert(tmp, "*")
        else
            -- index=index+1
            break
        end

        index=index+1
    end

    return table.concat(tmp), index
end

local function parse_c_funcdef(tokens)
    if tokens[1] == nil or not token_check(tokens[1], "word", "extern") then
        return nil
    end
    
    local output = {}
    local index = 2

    output.ret, index = parse_type_name(tokens, index)
    -- print(output.ret)

    local func_name_in_paren = token_check(tokens[index], "symbol", "(")
    if func_name_in_paren then
        index=index+1
    end

    assert_type(tokens[index], "word")
    output.name = tokens[index].str
    index=index+1

    if func_name_in_paren then
        assert_token_check(tokens[index], "symbol", ")")
        index=index+1
    end

    if string.sub(output.name, 1, 3) ~= "lua" then
        return nil
    end

    if not token_check(tokens[index], "symbol", "(") then
        return nil
    end

    index=index+1
    output.args = {}

    if token_check(tokens[index], "word", "void") and token_check(tokens[index+1], "symbol", ")") then
        index=index+2
    else
        while not token_check(tokens[index], "symbol", ")") do
            local arg_type
            arg_type, index = parse_type_name(tokens, index)

            if arg_type == "..." then
                table.insert(output.args, { type = "...", name = "" })
            else
                local arg_name
                if tokens[index].type == "word" then
                    arg_name = tokens[index].str
                    index=index+1
                else
                    arg_name = "arg" .. (#output.args + 1)
                end

                table.insert(output.args, { type = arg_type, name = arg_name })
            end

            if token_check(tokens[index], "symbol", ",") then
                index=index+1
            end
        end
        index=index+1
    end

    assert_token_check(tokens[index], "symbol", ";")

    local override = conf.overrides[output.name]
    if override then
        output.ret = override.ret
        output.args = {}

        for i, arg_override in ipairs(override.args) do
            output.args[i] = { type = arg_override[1], name = arg_override[2] }
        end

        output.impl = override.impl
    end
    
    --print("DONE!")

    return output

    -- for i=2, #tokens do
    --     local token = tokens[i]
    -- end
end

local function parse_c_structdef(tokens)
    if tokens[1] == nil then
        return nil
    end
    
    if not token_check(tokens[1], "word", "struct") then
        return nil
    end
    
    assert_type(tokens[2], "word", "expected struct name")
    local struct_name = tokens[2].str

    if not conf.exposed_structs[struct_name] then
        return nil
    end
    
    assert_token_check(tokens[3], "symbol", "{", "expected open paren after struct name")

    local struct_data = {
        name = struct_name,
        members = {}
    }

    local tok_idx = 4
    while not token_check(tokens[tok_idx], "symbol", "}") do
        local mem_type
        mem_type, tok_idx = parse_type_name(tokens, tok_idx)
        
        assert_type(tokens[tok_idx], "word", "expected identifier after type")
        local mem_name = tokens[tok_idx].str
        tok_idx=tok_idx+1

        local arr_size = 1
        if token_check(tokens[tok_idx], "symbol", "[") then
            tok_idx=tok_idx+1

            assert_type(tokens[tok_idx], "word", "expected integer")
            arr_size = tonumber(tokens[tok_idx].str)
            if arr_size == nil then
                tok_error(tokens[tok_idx], "could not parse array size")
            end
            tok_idx=tok_idx+1

            assert_token_check(tokens[tok_idx], "symbol", "]")
            tok_idx=tok_idx+1
        end

        assert_token_check(tokens[tok_idx], "symbol", ";", "expected semicolon")
        tok_idx=tok_idx+1

        tinsert(struct_data.members, {
            type = mem_type,
            name = mem_name,
            count = arr_size
        })
    end

    tok_idx=tok_idx+1

    return struct_data
end

function cparser.parse_struct(structdef, native_size)
    local struct = {
        name = structdef.name,
        members = {},
        size = 0
    }

    local cur_offset = 0
    for _, v in pairs(structdef.members) do
        local type_info = stringx.split_space(v.type)

        -- remove "unsigned" and "const", as they do not affect member size
        for i=#type_info, 1, -1 do
            local v = type_info[i]
            if v == "unsigned" or v == "const" then
                table.remove(type_info, i)
            end
        end

        local prim = table.concat(type_info, " ")

        local member_size
        local member_align
        if string.sub(prim, -1) == "*" then
            member_size = native_size
            member_align = native_size
        elseif prim == "int" then
            member_size = 4
            member_align = 4
        elseif prim == "char" then
            member_size = 1
            member_align = 1
        elseif prim == "short" then
            member_size = 2
            member_align = 2
        elseif prim == "size_t" then
            member_size = native_size
            member_align = native_size
        elseif prim == "long" then
            member_size = 8
            member_align = 8
        else
            error("unsupported member type " .. prim)
        end

        cur_offset = math.ceil(cur_offset / member_align) * member_align
        member_size = member_size * v.count

        tinsert(struct.members, {
            type = v.type,
            base_type = prim,
            name = v.name,
            count = v.count,
            size = member_size,
            alignment = member_align,
            offset = cur_offset
        })

        -- print(type_info[#type_info], v.name)
        cur_offset = cur_offset + member_size
    end

    struct.size = cur_offset

    return struct
end

local function parse_file(funcs, structs, stream)
    -- local test_file <close> = assert(io.open("test.c", "w"))
    local pos = {
        line = -1,
        file = "?"
    }

    while not stream:eof() do
        local tokens = tokenize_c_line(stream, pos)
        
        local func = parse_c_funcdef(tokens)
        if func then
            table.insert(funcs, func)
        else
            local struct = parse_c_structdef(tokens)
            if struct then
                table.insert(structs, struct)
            end
        end
    end
end

cparser.parse_file = parse_file
cparser.parse_c_structdef = parse_c_structdef
cparser.parse_c_funcdef = parse_c_funcdef
cparser.tokenize_c_line = tokenize_c_line

---invoke a C compiler to read and preprocess headers
---@param cc string C compiler command
---@param paths string paths to headers
---@return string
function cparser.read_headers(cc, ...)
    local tmpout = os.tmpname()

    -- invoke C preprocessor
    local cmd = ("\"%s\" -E - > \"%s\""):format(cc, tmpout)
    local cpp = assert(io.popen(cmd, "w"), ("could not run \"%s\""):format(cmd))
    for _, p in ipairs({...}) do
        cpp:write("#include \"")
        cpp:write(p)
        cpp:write("\"\n")
    end
    cpp:flush()
    cpp:close()

    local f <close> = assert(io.open(tmpout, "r"), "could not open " .. tmpout)
    local out = f:read("a")
    os.remove(tmpout)

    return out
end

return cparser