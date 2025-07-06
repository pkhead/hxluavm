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
local inspect = require("generator.inspect")

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
    cparser.parse_file(funcs, structs, StringStream.new(cparser.read_headers(CC, luah_path, lauxlibh_path, lualibh_path)))

    if conf.c_header_extra then
        print("processing c_header_extra")
        cparser.parse_file(funcs, structs, StringStream.new(conf.c_header_extra))
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

    local func_types = {"lua_CFunction", "lua_KFunction", "lua_Hook", "lua_Reader", "lua_Writer"}

    -- 1: hl.h type
    -- 2: haxe hl type
    -- 3: haxe js/wasm type
    local haxe_type_mappings = conf.haxe_type_mappings

    local haxe_trivial_types = {
        "Void", "Int", "Single", "Float", "State", "CString",
        "DebugPtr"
    }

    for _, t in ipairs({"CFunction", "KFunction", "Hook", "Reader", "Writer"}) do
        tinsert(haxe_trivial_types, ("Callable<%s>"):format(t))
        tinsert(haxe_trivial_types, ("FuncPtr<%s>"):format(t))
    end

    local hx_js_bindings_source = {}
    local hx_hl_bindings_source = {}

    local hx_js_wrapper_content = {}
    local hx_hl_wrapper_content = {}

    local function write_c_func_def(out, def, arg_names)
        if def.impl then
            out:write(def.impl)
        else
            out:write("    ")
            if def.ret ~= "void" then
                out:write("return ")
            end

            if conf.size_t then
                if def.ret == "size_t" then
                    out:write("(")
                    out:write(conf.size_t)
                    out:write(")")
                elseif def.ret == "const size_t" then
                    out:write("(const ")
                    out:write(conf.size_t)
                    out:write(")")
                end
            end

            out:write(def.name)
            out:write("(")
            out:write(table.concat(arg_names, ", "))
            out:write(");\n")
        end
    end

    local function type_substitution(arg_type)
        if arg_type == "size_t" then
            arg_type = conf.size_t
        elseif arg_type == "const size_t" then
            arg_type = "const " .. conf.size_t
        end
        return arg_type
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
            local def_ret = type_substitution(def.ret)
            local haxe_ret = haxe_type_mappings[def_ret]
            if not haxe_ret then
                print(("%s: no haxe representation for return %s"):format(def.name, def_ret))
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

                local arg_type = type_substitution(arg.type)
                local map = haxe_type_mappings[arg_type]
                if not map then
                    for _, arg in ipairs(def.args) do
                        local arg_type = type_substitution(arg.type)
                        if not haxe_type_mappings[arg_type] then
                            print(("%s: no haxe representation for %s"):format(def.name, arg_type))
                        end
                    end

                    goto skip_this_def
                end

                -- use actual arg type here, so that it can cast it to size_t
                if target == "hl" and table.find(func_types, arg.type) then
                    table.insert(arg_names, ("(%s == NULL ? NULL : %s->fun)"):format(arg.name, arg.name))
                    table.insert(param_strs, ("vclosure* %s"):format(arg.name))
                elseif target == "hl" and arg.type == "size_t" then
                    table.insert(arg_names, "(size_t)" .. arg.name)
                    table.insert(param_strs, ("%s %s"):format(conf.size_t, arg.name))
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
                tinsert(hx_bindings_source, "NativePtr")
            else
                tinsert(hx_bindings_source, haxe_ret[target_index])
            end

            if target == "js" then
                tinsert(hx_bindings_source, " {\n")

                local param_names = {}
                local post_call = {}
                for _, arg in ipairs(def.args) do
                    local arg_type = type_substitution(arg.type)

                    local haxe_type = haxe_type_mappings[arg_type][target_index]

                    if haxe_type == "CString" then
                        tinsert(hx_bindings_source, "        var _")
                        tinsert(hx_bindings_source, arg.name)
                        tinsert(hx_bindings_source, (" = %s == null ? null : allocString("):format(arg.name))
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

    local function proc_struct_defs(structdefs, target)
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

        local function template_sub(template, member, indentation)
            indentation = indentation or 0
            local prefix = string.rep("    ", indentation)

            local lines = stringx.split(template, "\n")
            local count = string.find(lines[1], "%S")
            if count then
                for i, v in ipairs(lines) do
                    lines[i] = prefix .. string.sub(v, count)
                end
            end

            if not string.find(lines[#lines], "%S") then
                lines[#lines] = "\n"
            end

            return table.concat(lines, "\n"):gsub("$name", member.name):gsub("$offset", member.offset):gsub("$size", member.size)
        end

        for _, def in ipairs(structdefs) do
            local native_size
            if target == "js" then
                native_size = 4
            else
                native_size = 8
            end

            local struct = cparser.parse_struct(def, native_size)
            local struct_conf = conf.exposed_structs[struct.name]
            local hx_name = struct_conf.hx_name

            tinsert(hx_bindings_source, ("abstract %s(NativePtr) from NativePtr to NativePtr {\n"):format(hx_name))
            tinsert(hx_bindings_source, ("    public static function alloc():%s {\n"):format(hx_name))
            tinsert(hx_bindings_source, ("        var data = haxe.io.Bytes.alloc(%i);\n"):format(struct.size))
            tinsert(hx_bindings_source, ("        data.fill(0, %i, 0);\n"):format(struct.size))
            tinsert(hx_bindings_source,  "        return NativePtr.fromBytes(data);\n")
            tinsert(hx_bindings_source,  "    }\n\n")

            if target == "js" then
                tinsert(hx_bindings_source,  "    public inline function free() {\n        LuaNative.wasm._free(this); this = 0;\n    }\n")
            else
                tinsert(hx_bindings_source,  "    public inline function free() {}\n")
            end

            for _, member in ipairs(struct.members) do
                if not table.find(struct_conf.private_members, member.name) then
                    if member.base_type == "char" and member.count > 1 then
                        local template = [[
                            public var $name(get, set):String;
                            function get_$name():String {
                                var strlen = CString.strLen(this, $offset);
                                return this.offset($offset).toBytes(strlen).toString();
                            }

                            function set_$name(v:String) {
                                var bytes = haxe.io.Bytes.ofString(v);
                                var l = bytes.length;
                                if (l > $size-1) {
                                    l = $size-1;
                                }
                                for (i in 0...l) {
                                    this[$offset+i] = bytes.get(i);
                                }
                                this[l] = 0;
                                return v;
                            }           
                        ]]
                        
                        local s = template_sub(template, member, 1)
                        tinsert(hx_bindings_source, s)
                    elseif member.type == "const char*" then
                        tinsert(hx_bindings_source, ("    public var %s(get,never):String;\n"):format(member.name))

                        local template
                        if target == "js" then
                            template = [[
                                function get_$name():String {
                                    var cstr = NativePtr.fromAddress(LuaNative.wasm.HEAPU32[(this.address() + $offset)>>2]);
                                    var strlen = CString.strLen(cstr, 0);
                                    return cstr.toBytes(strlen).toString();
                                }
                            ]]
                        else
                            template = [[
                                function get_$name():String {
                                    var addrLow = 0;
                                    var addrHigh = 0;
                                    LuaNative.luaX_sizet_get(this.offset($offset), new hl.Ref<Int>(addrLow), new hl.Ref<Int>(addrHigh));

                                    var cstr = NativePtr.fromAddress(NativeUInt.make(addrHigh, addrLow));
                                    var strlen = CString.strLen(cstr, 0);
                                    return cstr.toBytes(strlen).toString();
                                }
                            ]]
                        end
                        
                        local s = template_sub(template, member, 1)
                        tinsert(hx_bindings_source, s)
                        -- local map = haxe_type_mappings[member.type]
                        -- if map == nil then
                        --     print(("%s: no haxe representation for %s"):format(struct.name, member.type))
                        --     goto skip_this_mem
                        -- end

                        -- tinsert(hx_bindings_source, ("    public var %s(get, set):String;\n"):format(member.name))
                    elseif member.base_type == "float" or member.base_type == "double" then
                        print(("%s: float or double type not yet implemented"):format(member.name))
                    elseif member.base_type == "char" then
                        local template = [[
                            public var $name(get, set):Int;
                            function get_$name() return this[$offset];
                            function set_$name(v:Int) return this[$offset] = v;
                        ]]
                        local s = template_sub(template, member, 1)
                        tinsert(hx_bindings_source, s)
                    elseif member.base_type == "short" then
                        local template = [[
                            public var $name(get, set):Int;
                            function get_$name() return this.getUI16($offset);
                            function set_$name(v:Int) {
                                this.setUI16($offset, v);
                                return v;
                            }
                        ]]
                        local s = template_sub(template, member, 1)
                        tinsert(hx_bindings_source, s)
                    elseif member.base_type == "int" or (member.base_type == "size_t" and target == "js") then
                        local template = [[
                            public var $name(get, set):Int;
                            function get_$name() return this.getI32($offset);
                            function set_$name(v:Int) {
                                this.setI32($offset, v);
                                return v;
                            }
                        ]]
                        local s = template_sub(template, member, 1)
                        tinsert(hx_bindings_source, s)
                    elseif member.base_type == "size_t" then
                        local template = [[
                            public var $name(get, set):haxe.Int64;
                            function get_$name() {
                                var low = 0;
                                var high = 0;
                                LuaNative.luaX_sizet_get(this.offset($offset), new hl.Ref<Int>(low), new hl.Ref<Int>(high));
                                return haxe.Int64.make(high, low);
                            }
                            
                            function set_$name(v:haxe.Int64) {
                                LuaNative.luaX_sizet_set(this.offset($offset), v.low, v.high);
                                return v;
                            }
                        ]]
                        local s = template_sub(template, member, 1)
                        tinsert(hx_bindings_source, s)
                    else
                        print(("%s: unsupported/unimplemented member type %s"):format(struct.name, member.type))
                    end
                end

                ::skip_this_mem::
            end
            tinsert(hx_bindings_source,  "}\n")
        end
    end

    proc_struct_defs(structs, "hl")
    proc_struct_defs(structs, "js")

    tinsert(hx_js_bindings_source , [[class LuaNative {
    public static var wasm:Dynamic;

    public static function init(cb:()->Void) {
        js.Syntax.code("LuaVM({}).then((wasm) => { {0} = wasm; cb(); })", wasm);
    }

    public static function allocString(str:CString):NativeUInt {
        var bytes = str.toBytes();
        var ptr = wasm._malloc(bytes.length + 1);
        for (i in 0...bytes.length) {
            wasm.HEAPU8[ptr+i] = bytes.get(i);
        }
        wasm.HEAPU8[ptr + bytes.length] = 0;
        return ptr;
    }
    
    static inline function _freeString(ptr:NativeUInt) {
        if (ptr != null) wasm._free(ptr);
    }

    public static function allocFuncPtr<T:Function>(func:T, funcType:FunctionType):FuncPtr<T> {
        return cast wasm.addFunction(func, switch (funcType) {
            case CFunction: "ip";
            case KFunction: "ipip";
            case Hook: "vpp";
            case Reader: "pppp";
            case Writer: "ipppp";
        });
    }
]]
    )

    tinsert(hx_hl_bindings_source,
        "extern class LuaNative {\n"
    )

    proc_func_defs(funcs, "hl")
    proc_func_defs(funcs, "js")

    tinsert(hx_hl_bindings_source, "}\n")
    tinsert(hx_js_bindings_source, "}\n")

    local hx_bindings_content = conf.hx_lua_bindings
        :gsub("$<JS>", table.concat(hx_js_bindings_source))
        :gsub("$<HL>", table.concat(hx_hl_bindings_source))
    
    output_hx_bindings_file:write(hx_bindings_content)

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