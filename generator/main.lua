local native_lib_name, lua_src_path, CC = ...

if not native_lib_name then
    error("native lib name (first argument) must be specified!")
end

if not lua_src_path then
    error("lua include path (second argument) must be specified!")
end

if not CC then
    error("path to gcc/clang (third argument) must be specified!")
end

local luah_path = lua_src_path .. "/lua.h"
local lualibh_path = lua_src_path .. "/lualib.h"
local lauxlibh_path = lua_src_path .. "/lauxlib.h"

require("generator.util")
local conf = require("generator.conf")
local StringStream = require("generator.sstream")
local cparser = require("generator.cparser")

local tinsert = table.insert

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

do
    local funcs = {}
    local structs = {}
    
    -- print("processing " .. luah_path)
    parse_file(funcs, structs, StringStream.new(cparser.read_headers(CC, luah_path, lauxlibh_path, lualibh_path)))

    if conf.c_header_extra then
        print("processing c_header_extra")
        parse_file(funcs, structs, StringStream.new(conf.c_header_extra))
    end

    local output_hlc_file <close> = assert(io.open("hlexport.c", "w"), "could not open hlexport.c")
    local output_wasmc_file <close> = assert(io.open("wasmexport.c", "w"), "could not open wasmexport.c")
    local output_hx_bindings_file <close> = assert(io.open("lib/luavm/LuaNative.hx", "w"), "could not open lib/luavm/LuaNative.hx")

    output_hlc_file:write([[#define HL_NAME(n) luahl_##n

#include <hl.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#define _LSTATE _ABSTRACT(lua_State)
#define _NUINT _ABSTRACT(_BYTES)

]])

    output_wasmc_file:write([[#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <emscripten.h>

]])

    output_hx_bindings_file:write([[package luavm;
import haxe.Constraints.Function;
import luavm.GcOptions;
import luavm.LuaType;
import luavm.State;
import luavm.ThreadStatus;
import luavm.CString;

#if js
typedef CFunction = State->Int;
typedef KFunction = (State,Int,NativeUInt)->Int;
// typedef Reader = Callable<(State, hl.Bytes, hl.Ref<haxe.Int64>)->hl.Bytes>

enum FunctionType {
    CFunction;
    KFunction;
}

abstract FuncPtr<T:Function>(Int) from Int to Int {}

#else
@:callable
private abstract Callable<T:Function>(T) to T {
	@:from static function fromT<T:Function>(f:T) {
		return cast hl.Api.noClosure(f);
	}
}

typedef CFunction = Callable<State->Int>;
typedef KFunction = Callable<(State,Int,NativeUInt)->Int>;
// typedef Reader = Callable<(State, hl.Bytes, hl.Ref<haxe.Int64>)->hl.Bytes>
#end
]])

    local func_types = {"lua_CFunction"}

    -- 1: hl.h type
    -- 2: haxe hl type
    -- 3: haxe js/wasm type
    local haxe_type_mappings = conf.haxe_type_mappings

    local haxe_trivial_types = {
        "Void", "Int", "Single", "Float", "State", "CString", "CFunction", "KFunction"
    }

    local hx_js_bindings_source = {[[class LuaNative {
    public static var wasm:Dynamic;

    public static function init(cb:()->Void) {
        js.Syntax.code("LuaVM({}).then((wasm) => { {0} = wasm; cb(); })", wasm);
    }

    public static function vmAllocString(str:CString):NativeUInt {
        var bytes = str.toBytes();
        var ptr = wasm._malloc(bytes.length + 1);
        for (i in 0...bytes.length) {
            wasm.HEAPU8[ptr+i] = bytes.get(i);
        }
        wasm.HEAPU8[ptr + bytes.length] = 0;
        return ptr;
    }
    
    static inline function _freeString(ptr:NativeUInt) {
        wasm._free(ptr);
    }

    public static function vmAllocFuncPtr<T:Function>(func:T, funcType:FunctionType):FuncPtr<T> {
        return cast wasm.addFunction(func, switch (funcType) {
            case CFunction: "ip";
            case KFunction: "ipip";
        });
    }
]]
    }
    local hx_js_wrapper_content = {}

    local hx_hl_bindings_source = {
        "extern class LuaNative {\n",
    }
    local hx_hl_wrapper_content = {}

    local function write_c_func_def(out, def, arg_names)
        if def.impl then
            out:write(def.impl)
        else
            out:write("    ")
            if def.ret ~= "void" then
                out:write("return ")
            end
            out:write(def.name)
            out:write("(")
            out:write(table.concat(arg_names, ", "))
            out:write(");\n")
        end
    end

    local function proc_func_defs(funcdefs, target)
        local hx_bindings_source, hx_wrapper_content, target_index

        if target == "js" then
            target_index = 3
            hx_bindings_source = hx_js_bindings_source
            hx_wrapper_content = hx_js_wrapper_content
        
        elseif target == "hl" then
            target_index = 2
            hx_bindings_source = hx_hl_bindings_source
            hx_wrapper_content = hx_hl_wrapper_content

        else
            error("invalid target " .. target)
        end

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
            local write_to_haxe_wrapper = table.find(haxe_trivial_types, haxe_ret[target_index]) ~= nil
            local write_to_c_source = true

            if def.name:sub(1, 5) == "luaX_" then
                write_to_haxe_wrapper = false
            end

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

                if target == "hl" and table.find(func_types, arg.type) then
                    table.insert(arg_names, arg.name .. "->fun")
                    table.insert(param_strs, ("vclosure* %s"):format(arg.name))
                else
                    table.insert(arg_names, arg.name)
                    table.insert(param_strs, ("%s %s"):format(arg.type, arg.name))
                end

                local haxe_type = map[target_index]
                -- if haxe_type == "hl.Bytes" then
                --     haxe_type = "LuaString"
                -- end

                table.insert(hl_params, map[1])
                table.insert(haxe_params, arg.name .. ":" .. haxe_type)

                if not table.find(haxe_trivial_types, haxe_type) then
                    write_to_haxe_wrapper = false
                end
            end

            if param_strs[1] == nil then
                param_strs[1] = "void"
            end
            -- test_file:write(("%s %s(%s);\n"):format(def.ret, def.name, table.concat(arg_names, ", ")))

            -- local export_name = string.sub(def.name, string.find(def.name, "_", 1, true)+1, -1)
            local export_name = def.name

            if write_to_c_source then
                -- writing to hl_export.c
                if target == "hl" then
                    output_hlc_file:write(("HL_PRIM %s HL_NAME(%s)(%s) {\n"):format(def.ret, export_name, table.concat(param_strs, ", ")))
                    write_c_func_def(output_hlc_file, def, arg_names)
                    output_hlc_file:write("}\n")

                    output_hlc_file:write("DEFINE_PRIM(")
                    output_hlc_file:write(haxe_ret[1])
                    output_hlc_file:write(", ")
                    output_hlc_file:write(export_name)
                    output_hlc_file:write(", ")
                    if param_strs[1] == "void" then
                        output_hlc_file:write("_NO_ARG")
                    else
                        output_hlc_file:write(table.concat(hl_params, " "))
                    end
                    output_hlc_file:write(")\n\n")

                -- writing to wasmexport.c
                elseif target == "js" then
                    output_wasmc_file:write("EMSCRIPTEN_KEEPALIVE\n__attribute__((export_name(\"")
                    output_wasmc_file:write(export_name)
                    output_wasmc_file:write("\")))\n")
                    output_wasmc_file:write(("%s export_%s(%s) {\n"):format(def.ret, export_name, table.concat(param_strs, ", ")))
                    write_c_func_def(output_wasmc_file, def, arg_names)
                    output_wasmc_file:write("}\n")
                end

                -- %s export_"))
            end

            if target == "hl" then
                tinsert(hx_bindings_source, ("    @:hlNative(\"%s\", \""):format(native_lib_name))
                tinsert(hx_bindings_source, export_name)
                tinsert(hx_bindings_source, "\")\n")
            end

            tinsert(hx_bindings_source, "    public static function ")
            tinsert(hx_bindings_source, def.name)
            tinsert(hx_bindings_source, "(")
            tinsert(hx_bindings_source, table.concat(haxe_params, ", "))
            tinsert(hx_bindings_source, "):")

            if target == "js" and haxe_ret[target_index] == "CString" then
                tinsert(hx_bindings_source, "NativeUInt")
            else
                tinsert(hx_bindings_source, haxe_ret[target_index])
            end

            if target == "js" then
                tinsert(hx_bindings_source, " {\n")

                local param_names = {}
                local post_call = {}
                for _, arg in ipairs(def.args) do
                    local haxe_type = haxe_type_mappings[arg.type][target_index]

                    if haxe_type == "CString" then
                        tinsert(hx_bindings_source, "        var _")
                        tinsert(hx_bindings_source, arg.name)
                        tinsert(hx_bindings_source, " = vmAllocString(")
                        tinsert(hx_bindings_source, arg.name)
                        tinsert(hx_bindings_source, ");\n")

                        tinsert(param_names, "_" .. arg.name)

                        tinsert(post_call, "        _freeString(_")
                        tinsert(post_call, arg.name)
                        tinsert(post_call, ");\n")
                    elseif haxe_type == "CFunction" or haxe_type == "KFunction" then
                        tinsert(hx_bindings_source, "        var _")
                        tinsert(hx_bindings_source, arg.name)
                        tinsert(hx_bindings_source, " = _allocFunction(")
                        tinsert(hx_bindings_source, arg.name)
                        tinsert(hx_bindings_source, ", ")

                        if haxe_type == "CFunction" then
                            tinsert(hx_bindings_source, "\"ip\"")
                        elseif haxe_type == "KFunction" then
                            tinsert(hx_bindings_source, "\"ipip\"")
                        else
                            error("invalid/unsupported function type " .. haxe_type)
                            end

                        tinsert(hx_bindings_source, ");\n")

                        tinsert(param_names, "_" .. arg.name)
                    elseif haxe_type == "haxe.Int64" then
                        tinsert(param_names, ("js.Syntax.code(\"(BigInt({0}.low) | (BigInt({0}.high) << 32n))\", %s)"):format(arg.name))
                    else
                        tinsert(param_names, arg.name)
                    end
                end

                tinsert(hx_bindings_source, "        ")
                if def.ret ~= "void" then
                    tinsert(hx_bindings_source, "var _res_ = ")
                end
                tinsert(hx_bindings_source, "wasm._")
                tinsert(hx_bindings_source, def.name)
                tinsert(hx_bindings_source, "(")
                tinsert(hx_bindings_source, table.concat(param_names, ", "))
                tinsert(hx_bindings_source, ");\n")
                tinsert(hx_bindings_source, table.concat(post_call))
                if def.ret ~= "void" then
                    tinsert(hx_bindings_source, "        return ")

                    if haxe_ret[target_index] == "haxe.Int64" then
                        tinsert(hx_bindings_source, "haxe.Int64.make(js.Syntax.code(\"Number({0} >> 32n)\", _res_), js.Syntax.code(\"Number({0})\", _res_))")
                    else
                        tinsert(hx_bindings_source, "_res_")
                    end

                    tinsert(hx_bindings_source, ";\n")
                end
                tinsert(hx_bindings_source, "    }\n")
            else
                tinsert(hx_bindings_source, ";\n")
            end

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
                elseif string.find(def.name, "luaX_", 1, true) == 1 then
                    name_prefix = "x_"
                end
                local wrapper_name = name_prefix .. string.sub(def.name, string.find(def.name, "_", 1, true)+1, -1)

                table.insert(hx_wrapper_content, "    public static inline function ")
                table.insert(hx_wrapper_content, wrapper_name)
                table.insert(hx_wrapper_content, "(")
                table.insert(hx_wrapper_content, table.concat(haxe_params, ", "))
                table.insert(hx_wrapper_content, ") return LuaNative.")
                table.insert(hx_wrapper_content, def.name)
                table.insert(hx_wrapper_content, "(")
                table.insert(hx_wrapper_content, table.concat(jfeowj, ", "))
                table.insert(hx_wrapper_content, ");\n")
            end

            ::skip_this_def::
        end

        return hx_bindings_source, hx_wrapper_content
    end

    proc_func_defs(funcs, "hl")
    proc_func_defs(funcs, "js")

    output_hx_bindings_file:write("\n#if js\n")
    output_hx_bindings_file:write(table.concat(hx_js_bindings_source))
    output_hx_bindings_file:write("}\n#else\n")
    output_hx_bindings_file:write(table.concat(hx_hl_bindings_source))
    output_hx_bindings_file:write("}\n#end\n")

    -- if conf.raw_haxe then
    --     output_hx_bindings_file:write(conf.raw_haxe)
    -- end

    local output_hx_wrapper_file <close> = assert(io.open("lib/luavm/Lua.hx", "w"), "could not open Lua.hx")
    local hx_wrapper_content = conf.hx_lua_wrapper
        :gsub("$<JS>", table.concat(hx_js_wrapper_content))
        :gsub("$<HL>", table.concat(hx_hl_wrapper_content))
    
    output_hx_wrapper_file:write(hx_wrapper_content)
    -- local stream = StringStream.new("LUA_API void	       *(lua_touserdata) (lua_State *L, int idx);")

    
    -- while not stream:eof() do
        
    -- end
end