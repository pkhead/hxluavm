local conf = {}

conf.extra_funcs = {
    main = "",
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
    if (len == NULL) return lua_tolstring(L, idx, NULL);
    
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

conf.hx_lua_wrapper = [[package luavm;
import luavm.GcOptions;
import luavm.LuaType;
import luavm.State;
import luavm.ThreadStatus;
import luavm.LuaNative;
import luavm.CString;

class Lua {
#if js
$<JS>
    public static inline function init(cb:()->Void) LuaNative.init(cb);
    
    public static function toBytes(L:State, idx:Int):haxe.io.Bytes {
        var tmpAlloc:Int = LuaNative.vm._malloc(4);
        var ptr = LuaNative.lua_tolstring(L, idx, tmpAlloc);
        var len:Int = LuaNative.vm.HEAPU32[tmpAlloc>>2]; // assumes alignment
        LuaNative.vm._free(tmpAlloc);

        var bytes = haxe.io.Bytes.alloc(len);
        for (i in 0...len) {
            bytes.set(i, LuaNative.vm.HEAPU8[ptr.toInt32()+i]);
        }
        
        return bytes;
    }

    public static inline function tostring(L:State, idx:Int):String {
        return toBytes(L, idx).toString();
    }

    public static function pushBytes(L:State, bytes:haxe.io.Bytes):NativeUInt {
        return LuaNative.lua_pushlstring(L, new CString(bytes), bytes.length);
    }

    // public static inline function pushstring(L:State, s:String):NativeUInt {
    //     return pushBytes(L, idx, haxe.io.Bytes.ofString(s));
    // }
    
    public static function loadBytes(L:State, bytes:haxe.io.Bytes, name:CString, mode:CString):Int {
        return LuaNative.luaL_loadbufferx(L, new CString(bytes), bytes.length, name, mode);
    }
#else
$<HL>

    public static inline function init(cb:()->Void) cb();
    
    public static function toBytes(L:State, idx:Int):haxe.io.Bytes {
        var len = 0;
        var ptr = LuaNative.lua_tolstring(L, idx, new hl.Ref<Int>(len));
        return ptr.hlBytes.toBytes(len);
    }

    public static function pushBytes(L:State, bytes:haxe.io.Bytes):CString {
        return LuaNative.lua_pushlstring(L, hl.Bytes.fromBytes(bytes), bytes.length);
    }

    public static inline function tostring(L:State, idx:Int):String {
        return LuaNative.lua_tolstring(L, idx, null);
    }

    public static function loadBytes(L:State, bytes:haxe.io.Bytes, name:CString, mode:CString):Int {
        return LuaNative.luaL_loadbufferx(L, hl.Bytes.fromBytes(bytes), NativeUInt.fromInt(bytes.length), name, mode);
    }

    // public static inline function pushcfunction(L:State, fn:LuaNative.CFunction):Void {
    //     return LuaNative.lua_pushcclosure(L, fn, 0);
    // }
#end

    public static inline function pcall(L:State, nargs:Int, nresults:Int, errfunc:Int):Int {
        return LuaNative.lua_pcallk(L, nargs, nresults, errfunc, null, null);
    }

    public static inline function call(L:State, nargs:Int, nresults:Int):Void {
        LuaNative.lua_callk(L, nargs, nresults, null, null);
    }

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
}
]]

return conf