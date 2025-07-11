-- configuration for lua 5.4
local conf = {}

conf.size_t = "unsigned int"

-- 1: hl.h type
-- 2: haxe hl type
-- 3: haxe js/wasm type
conf.haxe_type_mappings = {
    ["void"] = {"_VOID", "Void", "Void"},
    ["void*"] = {"_BYTES", "NativePtr", "NativePtr"},
    ["const void*"] = {"_BYTES", "NativePtr", "NativePtr"},
    ["char"] = {"_I8", "hl.UI8", "Int"},
    ["unsigned char"] = {"_I8", "Int", "Int"},
    ["short"] = {"_I16", "Int", "Int"},
    ["unsigned short"] = {"_I16", "Int", "Int"},
    ["int"] = {"_I32", "Int", "Int"},
    ["unsigned int"] = {"_I32", "Int", "Int"},
    ["float"] = {"_F32", "Single", "Single"},
    ["double"] = {"_F64", "Float", "Float"},
    ["lua_Number"] = {"_F64", "Float", "Float"},
    ["lua_Integer"] = {"_I64", "haxe.Int64", "haxe.Int64"},
    ["lua_State*"] = {"_LSTATE", "State", "State"},
    ["const char*"] = {"_BYTES", "CString", "CString"},
    ["int*"] = {"_REF(_I32)", "hl.Ref<Int>", "NativePtr"},
    ["unsigned int*"] = {"_REF(_I32)", "hl.Ref<Int>", "NativePtr"},
    -- ["size_t"] = {"_BYTES", "NativeUInt", "NativeUInt"},
    ["size_t*"] = {"_BYTES", "NativePtr", "NativePtr"},

    ["lua_CFunction"] = {"_FUN(_I32,_LSTATE)", "Callable<CFunction>", "FuncPtr<CFunction>"},
    ["lua_KFunction"] = {"_FUN(_I32,_LSTATE _I32 _BYTES)", "Callable<KFunction>", "FuncPtr<KFunction>"},
    ["lua_KContext"] = {"_BYTES", "NativePtr", "NativePtr"},
    ["lua_Reader"] = {"_FUN(_BYTES,_LSTATE _BYTES _BYTES)", "Callable<Reader>", "FuncPtr<Reader>"},
    -- ["lua_Writer"] = {"_FUN(_I32,_LSTATE _BYTES _BYTES _BYTES)", "Callable<Writer>", "FuncPtr<Writer>"},

    ["lua_Hook"] = {"_FUN(_VOID,_LSTATE _BYTES)", "Callable<Hook>", "FuncPtr<Hook>"},
    ["lua_Debug*"] = {"_BYTES", "DebugPtr", "DebugPtr"},
    ["const lua_Debug*"] = {"_BYTES", "DebugPtr", "DebugPtr"}
    -- ["lua_Reader"] = {"_FUN(_BYTES,_LSTATE _BYTES _REF(_I64))", "Reader"}
}

conf.c_header_extra = [[
extern int luaX_getregistryindex(void);
extern void luaX_sizet_get(size_t *addr, int *low, int *high);
extern void luaX_sizet_set(size_t *addr, unsigned int low, unsigned int high);
]]

conf.overrides = {
    luaX_sizet_get = {
        ret = "void",
        args = {
            { "size_t*", "addr" },
            { "int*", "low" },
            { "int*", "high" },
        },
        impl = [[
            size_t v = *addr;
            *low = (int)(v & 0xFFFFFFFF);
            *high = (int)((v >> 32) & 0xFFFFFFFF);
        ]]
    },

    luaX_sizet_set = {
        ret = "void",
        args = {
            { "size_t*", "addr" },
            { "unsigned int", "low" },
            { "unsigned int", "high" }
        },
        impl = [[
            size_t v = (size_t)(low) | ((size_t)(high) << 32);
            *addr = v;
        ]]
    },

    luaX_getregistryindex = {
        ret = "int",
        args = {},
        impl = "return LUA_REGISTRYINDEX;\n"
    },

    lua_tolstring = {
        ret = "const char*",
        args = {
            { "lua_State*", "L" },
            { "int", "idx" },
            { "unsigned int*", "len" }
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

    luaL_checklstring = {
        ret = "const char*",
        args = {
            { "lua_State*", "L" },
            { "int", "idx" },
            { "unsigned int*", "len" }
        },
        impl =
        [[
    if (len == NULL) return luaL_checklstring(L, idx, NULL);
    
    size_t tmp = (size_t)len;
    const char *res = luaL_checklstring(L, idx, &tmp);
    *len = (int)tmp;
    return res;
]]
    },

    luaL_tolstring = {
        ret = "const char*",
        args = {
            { "lua_State*", "L" },
            { "int", "idx" },
            { "unsigned int*", "len" }
        },
        impl =
        [[
    if (len == NULL) return luaL_tolstring(L, idx, NULL);
    
    size_t tmp = (size_t)len;
    const char *res = luaL_tolstring(L, idx, &tmp);
    *len = (int)tmp;
    return res;
]]
    },

    luaL_optlstring = {
        ret = "const char*",
        args = {
            { "lua_State*", "L" },
            { "int", "arg" },
            { "const char*", "def" },
            { "unsigned int*", "l" }
        },
        impl =
        [[
    if (l == NULL) return luaL_optlstring(L, arg, def, NULL);
    
    size_t tmp = (size_t)l;
    const char *res = luaL_optlstring(L, arg, def, &tmp);
    *l = (int)tmp;
    return res;
]]
    },

    luaL_error = {
        ret = "int",
        args = {
            { "lua_State*", "L" },
            { "const char*", "msg" }
        },
        impl =
        [[
return luaL_error(L, msg);
]]
    },

    lua_gc = {
        ret = "int",
        args = {
            { "lua_State*", "L" },
            { "int", "what" },
            { "int", "a" },
            { "int", "b" },
            { "int", "c" },
        },
        impl =
        [[
    if (what == LUA_GCINC) return lua_gc(L, what, a, b, c);
    if (what == LUA_GCGEN) return lua_gc(L, what, a, b);
    if (what == LUA_GCSTEP) return lua_gc(L, what, a);
    return lua_gc(L, what);
]]
    },
}

conf.exposed_structs = {
    lua_Debug = {
        hx_name = "DebugPtr",
        private_members = {"i_ci"}
    }
}

conf.hx_lua_bindings = [[package luavm;
import haxe.Constraints.Function;
import luavm.State;
import luavm.CString;
import luavm.Lua;

enum FunctionType {
    CFunction;
    KFunction;
    Hook;
    Reader;
    Writer;
}

#if js
abstract FuncPtr<T:Function>(Int) from Int to Int {}

#else
@:callable
abstract Callable<T:Function>(T) from T to T {
	@:from static function ofFunc<T:Function>(f:T) {
		return cast hl.Api.noClosure(f);
	}
}

// typedef CFunction = Callable<State->Int>;
// typedef KFunction = Callable<(State,Int,NativeUInt)->Int>;
// typedef Reader = Callable<(State, hl.Bytes, hl.Ref<haxe.Int64>)->hl.Bytes>
#end

#if js
$<JS>
#else
$<HL>
#end
]]

conf.bool_returns = {
    "lua_isnumber",
    "lua_isstring",
    "lua_iscfunction",
    "lua_isinteger",
    "lua_isuserdata",
    "lua_isyieldable",
    "lua_toboolean"
}

conf.wrapper_ignore = {
    "lua_pushboolean"
}

conf.hx_lua_wrapper = [[package luavm;
import luavm.State;
import luavm.LuaNative;
import luavm.CString;

enum abstract ThreadStatus(Int) {
	var Something = -1;
	var Ok = 0;
	var Yield;
	var ErrRun;
	var ErrSyntax;
	var ErrMem;
	var ErrErr;
}

enum abstract GcOptions(Int) from Int to Int {
	var GcStop = 0;
	var GCRestart = 1;
	var GcCollect = 2;
	var GcCount = 3;
	var GcCountB = 4;
	var GcStep = 5;
	var GcSetPause = 6;
	var GcSetStepMul = 7;
	var GcIsRunning = 9;

	@:to inline function toInt():Int {
        return this;
    }
}

enum abstract HookEvent(Int) from Int to Int {
    var HookCall = 0;
    var HookRet = 1;
    var HookLine = 2;
    var HookCount = 3;
    var HookTailCall = 4;

    @:to inline function toInt():Int {
        return this;
    }
}

enum abstract LuaType(Int) from Int to Int {
	var TNone = -1;
	var TNil = 0;
	var TBoolean = 1;
	var TLightUserData = 2;
	var TNumber = 3;
	var TString = 4;
	var TTable = 5;
	var TFunction = 6;
	var TUserdata = 7;
	var TThread = 8;

	@:to inline function toInt():Int {
        return this;
    }
}

enum abstract HookMask(Int) from Int to Int {
    var HookCall = 0;
    var HookRet = 1;
    var HookLine = 2;
    var HookCount = 3;
    var HookTailCall = 4;

    @:to inline function toInt():Int {
        return this;
    }
}

typedef CFunction = State->Int;
typedef KFunction = (State,Int,NativePtr)->Int;
typedef Hook = (State,DebugPtr)->Void;
typedef Reader = (State,NativePtr,NativePtr)->NativePtr;
// typedef Writer = (State,NativePtr,NativeUInt,NativePtr)->Int;

class Lua {
    private static var _registryIndex:Int;
    public static var REGISTRYINDEX(get, never):Int;
    inline static function get_REGISTRYINDEX() return _registryIndex;

    public static final MULTRET:Int = -1;
    
#if js
$<JS>
    public static function init(cb:()->Void) {
        LuaNative.init(() -> {
            _registryIndex = LuaNative.luaX_getregistryindex();
            cb();
        });
    }
    
    public static function toBytes(L:State, idx:Int):haxe.io.Bytes {
        var tmpAlloc:Int = LuaNative.wasm._malloc(4);
        var ptr = LuaNative.lua_tolstring(L, idx, tmpAlloc);
        var len:Int = LuaNative.wasm.HEAPU32[tmpAlloc>>2]; // assumes alignment
        LuaNative.wasm._free(tmpAlloc);

        var bytes = haxe.io.Bytes.alloc(len);
        for (i in 0...len) {
            bytes.set(i, LuaNative.wasm.HEAPU8[ptr.toInt32()+i]);
        }
        
        return bytes;
    }

    public static inline function tostring(L:State, idx:Int):String {
        return toBytes(L, idx).toString();
    }

    public static function pushBytes(L:State, bytes:haxe.io.Bytes):NativePtr {
        return LuaNative.lua_pushlstring(L, new CString(bytes), bytes.length);
    }
    
    public static function loadBytes(L:State, bytes:haxe.io.Bytes, name:CString, mode:CString):Int {
        return LuaNative.luaL_loadbufferx(L, new CString(bytes), bytes.length, name, mode);
    }
#else
$<HL>

    public static function init(cb:()->Void) {
        _registryIndex = LuaNative.luaX_getregistryindex();
        cb();
    }
    
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
        return LuaNative.luaL_loadbufferx(L, hl.Bytes.fromBytes(bytes), bytes.length, name, mode);
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

    public static inline function l_tostring(L:State, idx:Int):String {
        return LuaNative.luaL_tolstring(L, idx, null)?.toString();
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

    public static function pop(L:State, n:Int):Void {
        LuaNative.lua_settop(L, -(n)-1);
    }

    // #define lua_pushglobaltable(L) ((void)lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS))
    public static function pushglobaltable(L:State) {
        return LuaNative.lua_rawgeti(L, REGISTRYINDEX, 2);
    }
    
    // #define lua_insert(L,idx)	lua_rotate(L, (idx), 1)
    public static function insert(L:State, idx:Int) {
        LuaNative.lua_rotate(L, idx, 1);
    }

    // #define lua_remove(L,idx)	(lua_rotate(L, (idx), -1), lua_pop(L, 1))
    public static function remove(L:State, idx:Int) {
        LuaNative.lua_rotate(L, idx, -1);
        pop(L, 1);
    }
    
    // #define lua_replace(L,idx)	(lua_copy(L, -1, (idx)), lua_pop(L, 1))
    public static function replace(L:State, idx:Int) {
        LuaNative.lua_copy(L, -1, idx);
        pop(L, 1);
    }
    
    public static inline function l_getmetatable(L:State, tname:String) {
        return LuaNative.lua_getfield(L, REGISTRYINDEX, tname);
    }

    public static inline function l_checkudata(L:State, ud:Int, tname:String):NativePtr {
        return LuaNative.luaL_checkudata(L, ud, tname);
    }
    
    public static function l_checkstring(L:State, idx:Int):String {
        #if js
        var tmpAlloc:NativePtr = LuaNative.wasm._malloc(4);
        var ptr = LuaNative.luaL_checklstring(L, idx, tmpAlloc);
        var str = ptr.toBytes(tmpAlloc.getI32(0)).toString();
        LuaNative.wasm._free(tmpAlloc);
        return str;
        #else
        var len = 0;
        var ptr = LuaNative.luaL_checklstring(L, idx, new hl.Ref<Int>(len));
        return ptr.hlBytes.toBytes(len).toString();
        #end
    }
    
    public static inline function l_checkinteger(L:State, idx:Int):Int {
        return LuaNative.luaL_checkinteger(L, idx).low;
    }

    public static inline function l_checkinteger64(L:State, idx:Int):haxe.Int64 {
        return LuaNative.luaL_checkinteger(L, idx);
    }

    public static inline function upvalueindex(i:Int) {
        return REGISTRYINDEX - i;
    }

    public static inline function pushboolean(L:State, b:Bool):Void {
        LuaNative.lua_pushboolean(L, b ? 1 : 0);
    }
    
    public static inline function newuserdata(L:State, size:Int) {
        return LuaNative.lua_newuserdatauv(L, size, 1);
    }

    public static inline function getuservalue(L:State, index:Int) {
        return LuaNative.lua_getiuservalue(L, index, 1);
    }

    public static inline function setuservalue(L:State, index:Int) {
        return LuaNative.lua_setiuservalue(L, index, 1);
    }

    public static inline function isfunction(L:State, idx:Int) return LuaNative.lua_type(L, idx) == cast LuaType.TFunction;
    public static inline function istable(L:State, idx:Int) return LuaNative.lua_type(L, idx) == cast LuaType.TTable;
    public static inline function islightuserdata(L:State, idx:Int) return LuaNative.lua_type(L, idx) == cast LuaType.TLightUserData;
    public static inline function isnil(L:State, idx:Int) return LuaNative.lua_type(L, idx) == cast LuaType.TNil;
    public static inline function isboolean(L:State, idx:Int) return LuaNative.lua_type(L, idx) == cast LuaType.TBoolean;
    public static inline function isthread(L:State, idx:Int) return LuaNative.lua_type(L, idx) == cast LuaType.TThread;
    public static inline function isnone(L:State, idx:Int) return LuaNative.lua_type(L, idx) == cast LuaType.TNone;
    public static inline function isnoneornil(L:State, idx:Int) return LuaNative.lua_type(L, idx) <= 0;
}
]]

return conf