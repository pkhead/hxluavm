local conf = {}

conf.extra_funcs = {
    main = [[
        LUA_API void lua_call(lua_State *L, int nargs, int nresults);
        LUA_API int lua_pcall(lua_State *L, int nargs, int nresults, int errfunc);
    ]],

    aux = ""
}

-- conf.raw_haxe = [[    public static inline function tostring(L:State, i:Int):CString { return tolstring(L, i, null); }
--     public static inline function tonumber(L:State, idx:Int):Float { return tonumberx(L, idx, null); }

--     public static inline function hxToBytes(L:State, i:Int):CString { return tolstring(L, i, null); }
-- ]]

conf.overrides = {
    lua_tolstring = {
        ret = "const char*",
        args = {
            { "lua_State*", "L" },
            { "int", "idx" },
            { "int*", "len" }
        },
        impl =
        [[
    size_t tmp = (size_t)len;
    const char *res = lua_tolstring(L, idx, &tmp);
    *len = (int)tmp;
    return res;
]]
    },

    lua_pushlstring = {
        ret = "const char*",
        args = {
            { "lua_State*", "L" },
            { "const char*", "s" },
            { "int", "len" }
        },
        impl =
        [[
    return lua_pushlstring(L, s, (size_t)len);
]]
    }
}

conf.hx_lua_wrapper = [[package lua54;
import lua54.GcOptions;
import lua54.LuaType;
import lua54.State;
import lua54.ThreadStatus;
import lua54.LuaNative;
import lua54.CString;

class Lua {
$<AUTOGEN>

    public static inline function tonumber(L:State, idx:Int):Float {
        return LuaNative.lua_tonumberx(L, idx, null);
    }

    public static inline function tointeger64(L:State, idx:Int):haxe.Int64 {
        return LuaNative.lua_tointegerx(L, idx, null);
    }

    public static inline function tointeger(L:State, idx:Int):Int {
        return LuaNative.lua_tointegerx(L, idx, null).low;
    }

    public static inline function pushinteger(L:State, n:Int):Void {
        return LuaNative.lua_pushinteger(L, haxe.Int64.ofInt(n));
    }

    public static inline function geti(L:State, idx:Int, n:Int):Int {
        return LuaNative.lua_geti(L, idx, haxe.Int64.ofInt(n));
    }

    public static inline function rawgeti(L:State, idx:Int, n:Int):Int {
        return LuaNative.lua_rawgeti(L, idx, haxe.Int64.ofInt(n));
    }
    
    public static inline function seti(L:State, idx:Int, n:Int):Void {
        return LuaNative.lua_seti(L, idx, haxe.Int64.ofInt(n));
    }

    public static inline function rawseti(L:State, idx:Int, n:Int):Void {
        return LuaNative.lua_rawseti(L, idx, haxe.Int64.ofInt(n));
    }

    private static function readCStr(bytes:hl.Bytes):String {
        var len = 0;
        while (bytes[len] != 0) len++;
        return bytes.toBytes(len).toString();
    }
    
    public static function toBytes(L:State, idx:Int):haxe.io.Bytes {
        var len = 0;
        var ptr = LuaNative.lua_tolstring(L, idx, new hl.Ref<Int>(len));
        return ptr.bytes.toBytes(len);
    }

    public static function pushBytes(L:State, bytes:haxe.io.Bytes):CString {
        return LuaNative.lua_pushlstring(L, hl.Bytes.fromBytes(bytes), bytes.length);
    }

    public static inline function tostring(L:State, idx:Int):CString {
        return LuaNative.lua_tolstring(L, idx, null);
    }

    public static inline function pushcfunction(L:State, fn:LuaNative.CFunction):Void {
        return LuaNative.lua_pushcclosure(L, fn, 0);
    }
    
    public static function loadBytes(L:State, bytes:haxe.io.Bytes, name:CString, mode:CString):Int {
        return LuaNative.luaL_loadbufferx(L, hl.Bytes.fromBytes(bytes), bytes.length, name, mode);
    }
}
]]

return conf