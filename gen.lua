local luah_path = "lua-5.4.8/src/lua.h"
local lualibh_path = "lua-5.4.8/src/lualib.h"
local lauxlibh_path = "lua-5.4.8/src/lauxlib.h"
local conf = require("conf")

local function tfind(t, q)
    for i, v in pairs(t) do
        if v == q then
            return i
        end
    end
    return nil
end

-- local function the_haxe_casing_thing(orig)
--     local upper = string.upper(orig)
--     local out = {string.lower(string.sub(orig, 1, 1))}
--     for i=2, string.len(orig) do
--         local ch = string.sub(orig, i, i)
--         if ch == string.sub(upper, i, i) then
--             table.insert(out, "_")
--         end
--         table.insert(out, string.lower(ch))
--     end
--     return table.concat(out)
-- end

---@class Stream
---@field popchar fun(self:Stream):integer Pops one character, returning its code.
---@field read fun(self:Stream, count:integer):string Read contents without moving the cursor.
---@field pop fun(self:Stream, count:integer):string Read contents and advance the cursor.
---@field eof fun(self:Stream):boolean
---@field skip fun(self:Stream, count:integer) Advance the cursor without reading contents.

local parse_file
do
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

    local function flush(tokens, tmpbuf)
        if tmpbuf[1] then
            table.insert(tokens, {
                type = "word",
                str = string.char(table.unpack(tmpbuf))
            })

            for i=1, #tmpbuf do
                tmpbuf[i] = nil
            end
        end
    end

    ---@param stream Stream
    local function tokenize_c_line(stream)
        local tokens = {}
        local tmpbuf = {}
        
        while not stream:eof() do
            if stream:read(1) == ";" then
                table.insert(tokens, { type = "symbol", str = ";" })
                stream:skip(1)
                break
            end

            local sym = identify_symbol(stream)

            if sym then
                flush(tokens, tmpbuf)

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
                    table.insert(tokens, { type = "symbol", str = sym })
                    stream:skip(string.len(sym))
                end
            else
                local char = stream:popchar()

                if tfind(whitespace, char) then
                    flush(tokens, tmpbuf)
                else
                    table.insert(tmpbuf, char)
                end
            end
        end
        ::loop_end::
        flush(tokens, tmpbuf)
        
        return tokens
    end

    local function token_check(tok, type, v)
        return tok.type == type and tok.str == v
    end

    local export_defines = {"LUA_API", "LUALIB_API", "LUAMOD_API"}

    ---@param stream Stream
    local function parse_c_funcdef(stream)
        local tokens = tokenize_c_line(stream)
        -- print("==BEGIN TOKENS==")
        -- for i, v in pairs(tokens) do
        --     print(i, ("%s \"%s\""):format(v.type, v.str))
        -- end
        -- print("==END TOKENS==")

        if tokens[1] == nil or not (tokens[1].type == "word" and tfind(export_defines, tokens[1].str)) then
            return nil
        end


        local output = {}
        local index = 2

        local function parse_type_name()
            assert(tokens[index].type == "word")
            local tmp = {tokens[index].str}
            index=index+1

            while true do
                local possible_modifer = tmp[#tmp]
                if possible_modifer == "const" or possible_modifer == "unsigned" then
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

            return table.concat(tmp)
        end

        output.ret = parse_type_name()
        -- print(output.ret)

        local func_name_in_paren = token_check(tokens[index], "symbol", "(")
        if func_name_in_paren then
            index=index+1
        end

        assert(tokens[index].type == "word")
        output.name = tokens[index].str
        print("processing " .. output.name)
        index=index+1

        if func_name_in_paren then
            assert(token_check(tokens[index], "symbol", ")"))
            index=index+1
        end

        assert(token_check(tokens[index], "symbol", "("))
        index=index+1
        output.args = {}

        if token_check(tokens[index], "word", "void") and token_check(tokens[index+1], "symbol", ")") then
            index=index+2
        else
            while not token_check(tokens[index], "symbol", ")") do
                local arg_type = parse_type_name()
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

        assert(token_check(tokens[index], "symbol", ";"))

        local override = conf.overrides[output.name]
        if override then
            output.ret = override.ret
            output.args = {}

            for i, arg_override in ipairs(override.args) do
                output.args[i] = { type = arg_override[1], name = arg_override[2] }
            end

            output.impl = override.impl
        end
        
        print("DONE!")

        return output

        -- for i=2, #tokens do
        --     local token = tokens[i]
        -- end
    end

    function parse_file(stream)
        -- local test_file <close> = assert(io.open("test.c", "w"))
        local funcs = {}
        while not stream:eof() do
            local v = parse_c_funcdef(stream)
            if v then
                table.insert(funcs, v)
            end
        end
        return funcs
    end
end

-- local v = parse_c_funcdef("LUA_API int   (lua_gettop) (lua_State *L);")
-- print("done")
-- if v then
--     print("RET", v.ret)
--     print("NAME", v.name)
--     print("=BEGIN ARGS=")
--     for _, arg in ipairs(v.args) do
--         print(("%s: %s"):format(arg.name, arg.type))
--     end
--     print("=END ARGS=")
-- end

---@class StringStream: Stream
---@field _str string
---@field _idx integer
local StringStream = {}
StringStream.__index = StringStream

function StringStream.new(str)
    local self = setmetatable({}, StringStream)
    self._str = str
    self._idx = 1

    return self
end

function StringStream:eof()
    return self._idx > string.len(self._str)
end

function StringStream:popchar()
    assert(not self:eof(), "eof!")
    local ch = string.byte(self._str, self._idx)
    self._idx = self._idx + 1
    return ch
end

---@param count integer
function StringStream:pop(count)
    assert(not self:eof(), "eof!")
    local ret = string.sub(self._str, self._idx, self._idx + count - 1)
    self._idx = self._idx + string.len(ret)
    return ret
end

---@param count integer
function StringStream:read(count)
    assert(not self:eof(), "eof!")
    return string.sub(self._str, self._idx, self._idx + count - 1)
end

function StringStream:skip(count)
    assert(not self:eof(), "eof!")
    self._idx = self._idx + count
end

do
    local function read_header(path)
        local line_list = {}
        local f <close> = io.open(path, "r")
        if not f then
            error("could not open " .. path)
        end
    
        local continuation = false
        for l in f:lines() do
            local start_idx = string.find(l, "%S")
            if start_idx then
                if continuation or string.sub(l, start_idx, start_idx) == "#" then
                    continuation = string.sub(l, -1) == "\\"
                else
                    table.insert(line_list, l)
                end
            end
        end

        return table.concat(line_list, "\n")
    end
    
    local funcs1 = parse_file(StringStream.new(read_header(luah_path) .. "\n" .. conf.extra_funcs.main))
    local funcs2 = parse_file(StringStream.new(read_header(lauxlibh_path) .. "\n" .. conf.extra_funcs.aux))
    local funcs3 = parse_file(StringStream.new(read_header(lualibh_path)))

    local output_c_file <close> = assert(io.open("export.c", "w"), "could not open export.c")
    local output_hx_bindings_file <close> = assert(io.open("lib/lua54/LuaNative.hx", "w"), "could not open lib/lua54/LuaNative.hx")

    output_c_file:write([[#define HL_NAME(n) luahl_##n

#include <hl.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#define _LSTATE _ABSTRACT(lua_State)

]])

    output_hx_bindings_file:write([[package lua54;
import haxe.Constraints.Function;
import lua54.GcOptions;
import lua54.LuaType;
import lua54.State;
import lua54.ThreadStatus;
import lua54.CString;

@:callable
private abstract Callable<T:Function>(T) to T {
	@:from static function fromT<T:Function>(f:T) {
		return cast hl.Api.noClosure(f);
	}
}

typedef CFunction = Callable<State->Int>;
typedef Reader = Callable<(State, hl.Bytes, hl.Ref<haxe.Int64>)->hl.Bytes>

extern class LuaNative {
]])

    local func_types = {"lua_CFunction"}

    local haxe_type_mappings = {
        ["void"] = {"_VOID", "Void"},
        ["void*"] = {"_BYTES", "hl.Bytes"},
        ["int"] = {"_I32", "Int"},
        ["unsigned int"] = {"_I32", "Int"},
        ["float"] = {"_F32", "Single"},
        ["double"] = {"_F64", "Float"},
        ["lua_Number"] = {"_F64", "Float"},
        ["lua_Integer"] = {"_I64", "haxe.Int64"},
        ["lua_State*"] = {"_LSTATE", "State"},
        ["const char*"] = {"_BYTES", "CString"},
        ["int*"] = {"_REF(_I32)", "hl.Ref<Int>"},
        ["size_t"] = {"_I64", "haxe.Int64"},

        ["lua_CFunction"] = {"_FUN(_I32,_LSTATE)", "CFunction"},
        ["lua_Reader"] = {"_FUN(_BYTES,_LSTATE _BYTES _REF(_I64))", "Reader"}
    }

    local haxe_trivial_types = {
        "Void", "Int", "Single", "Float", "State", "CString", "CFunction", "Reader"
    }

    local haxe_wrapper_content = {}

    local function proc_func_defs(funcdefs, haxe_func_prefix)
        -- assert(stream:eof())
        for _, def in ipairs(funcdefs) do
            local haxe_ret = haxe_type_mappings[def.ret]
            if not haxe_ret then
                goto skip_this_def
            end

            local hl_params = {}
            local haxe_params = {}
            local arg_names = {}
            local param_strs = {}
            local write_to_haxe_wrapper = tfind(haxe_trivial_types, haxe_ret[2]) ~= nil

            for _, arg in ipairs(def.args) do
                if arg.type == "..." then
                    print(("%s: does not support vararg"):format(def.name))
                    goto skip_this_def
                end

                local map = haxe_type_mappings[arg.type]
                if not map then
                    for _, arg in ipairs(def.args) do
                        if not haxe_type_mappings[arg.type] then
                            print(("%s: no haxe representation for %s"):format(def.name, arg.type))
                        end
                    end

                    goto skip_this_def
                end

                if tfind(func_types, arg.type) then
                    table.insert(arg_names, arg.name .. "->fun")
                    table.insert(param_strs, ("vclosure* %s"):format(arg.name))
                else
                    table.insert(arg_names, arg.name)
                    table.insert(param_strs, ("%s %s"):format(arg.type, arg.name))
                end

                local haxe_type = map[2]
                -- if haxe_type == "hl.Bytes" then
                --     haxe_type = "LuaString"
                -- end

                table.insert(hl_params, map[1])
                table.insert(haxe_params, arg.name .. ":" .. haxe_type)

                if not tfind(haxe_trivial_types, haxe_type) then
                    write_to_haxe_wrapper = false
                end
            end

            if param_strs[1] == nil then
                param_strs[1] = "void"
            end
            -- test_file:write(("%s %s(%s);\n"):format(def.ret, def.name, table.concat(arg_names, ", ")))

            -- local export_name = string.sub(def.name, string.find(def.name, "_", 1, true)+1, -1)
            local export_name = def.name
            if haxe_func_prefix then
                export_name = haxe_func_prefix .. export_name
            end

            output_c_file:write(("HL_PRIM %s HL_NAME(%s)(%s) {\n"):format(def.ret, export_name, table.concat(param_strs, ", ")))

            if def.impl then
                output_c_file:write(def.impl)
            else
                output_c_file:write("    ")
                if def.ret ~= "void" then
                    output_c_file:write("return ")
                end
                output_c_file:write(def.name)
                output_c_file:write("(")
                output_c_file:write(table.concat(arg_names, ", "))
                output_c_file:write(");\n")
            end

            output_c_file:write("}\n")

            output_c_file:write("DEFINE_PRIM(")
            output_c_file:write(haxe_ret[1])
            output_c_file:write(", ")
            output_c_file:write(export_name)
            output_c_file:write(", ")
            if param_strs[1] == "void" then
                output_c_file:write("_NO_ARG")
            else
                output_c_file:write(table.concat(hl_params, " "))
            end
            output_c_file:write(")\n\n")

            output_hx_bindings_file:write("    @:hlNative(\"lua54\", \"")
            output_hx_bindings_file:write(export_name)
            output_hx_bindings_file:write("\")\n")
            output_hx_bindings_file:write("    public static function ")
            output_hx_bindings_file:write(def.name)
            output_hx_bindings_file:write("(")
            output_hx_bindings_file:write(table.concat(haxe_params, ", "))
            output_hx_bindings_file:write("):")
            output_hx_bindings_file:write(haxe_ret[2])
            output_hx_bindings_file:write(";\n")

            if write_to_haxe_wrapper then
                local jfeowj = {}
                for _, arg in ipairs(def.args) do
                    table.insert(jfeowj, arg.name)
                end

                local name_prefix
                if string.find(def.name, "lua_", 1, true) == 1 then
                    name_prefix = ""
                elseif string.find(def.name, "luaL_", 1, true) == 1 then
                    name_prefix = "l_"
                elseif string.find(def.name, "luaopen_", 1, true) == 1 then
                    name_prefix = "open_"
                end
                local wrapper_name = name_prefix .. string.sub(def.name, string.find(def.name, "_", 1, true)+1, -1)

                table.insert(haxe_wrapper_content, "    public static inline function ")
                table.insert(haxe_wrapper_content, wrapper_name)
                table.insert(haxe_wrapper_content, "(")
                table.insert(haxe_wrapper_content, table.concat(haxe_params, ", "))
                table.insert(haxe_wrapper_content, ") return LuaNative.")
                table.insert(haxe_wrapper_content, def.name)
                table.insert(haxe_wrapper_content, "(")
                table.insert(haxe_wrapper_content, table.concat(jfeowj, ", "))
                table.insert(haxe_wrapper_content, ");\n")
            end

            ::skip_this_def::
        end
    end

    proc_func_defs(funcs1)
    proc_func_defs(funcs2)
    proc_func_defs(funcs3)

    if conf.raw_haxe then
        output_hx_bindings_file:write(conf.raw_haxe)
    end

    output_hx_bindings_file:write("}")

    local output_hx_wrapper_file <close> = assert(io.open("lib/lua54/Lua.hx", "w"), "could not open Lua.hx")
    local hx_wrapper_content = conf.hx_lua_wrapper:gsub("$<AUTOGEN>", table.concat(haxe_wrapper_content))
    output_hx_wrapper_file:write(hx_wrapper_content)
    -- local stream = StringStream.new("LUA_API void	       *(lua_touserdata) (lua_State *L, int idx);")

    
    -- while not stream:eof() do
        
    -- end
end