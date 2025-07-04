package luavm;
import luavm.GcOptions;
import luavm.LuaType;
import luavm.State;
import luavm.ThreadStatus;
import luavm.LuaNative;
import luavm.CString;

class Lua {
    public static inline function close(L:State) return LuaNative.lua_close(L);
    public static inline function newthread(L:State) return LuaNative.lua_newthread(L);
    public static inline function closethread(L:State, from:State) return LuaNative.lua_closethread(L, from);
    public static inline function resetthread(L:State) return LuaNative.lua_resetthread(L);
    public static inline function atpanic(L:State, panicf:CFunction) return LuaNative.lua_atpanic(L, panicf);
    public static inline function version(L:State) return LuaNative.lua_version(L);
    public static inline function absindex(L:State, idx:Int) return LuaNative.lua_absindex(L, idx);
    public static inline function gettop(L:State) return LuaNative.lua_gettop(L);
    public static inline function settop(L:State, idx:Int) return LuaNative.lua_settop(L, idx);
    public static inline function pushvalue(L:State, idx:Int) return LuaNative.lua_pushvalue(L, idx);
    public static inline function rotate(L:State, idx:Int, n:Int) return LuaNative.lua_rotate(L, idx, n);
    public static inline function copy(L:State, fromidx:Int, toidx:Int) return LuaNative.lua_copy(L, fromidx, toidx);
    public static inline function checkstack(L:State, n:Int) return LuaNative.lua_checkstack(L, n);
    public static inline function xmove(from:State, to:State, n:Int) return LuaNative.lua_xmove(from, to, n);
    public static inline function isnumber(L:State, idx:Int) return LuaNative.lua_isnumber(L, idx);
    public static inline function isstring(L:State, idx:Int) return LuaNative.lua_isstring(L, idx);
    public static inline function iscfunction(L:State, idx:Int) return LuaNative.lua_iscfunction(L, idx);
    public static inline function isinteger(L:State, idx:Int) return LuaNative.lua_isinteger(L, idx);
    public static inline function isuserdata(L:State, idx:Int) return LuaNative.lua_isuserdata(L, idx);
    public static inline function type(L:State, idx:Int) return LuaNative.lua_type(L, idx);
    public static inline function typename(L:State, tp:Int) return LuaNative.lua_typename(L, tp);
    public static inline function toboolean(L:State, idx:Int) return LuaNative.lua_toboolean(L, idx);
    public static inline function tocfunction(L:State, idx:Int) return LuaNative.lua_tocfunction(L, idx);
    public static inline function tothread(L:State, idx:Int) return LuaNative.lua_tothread(L, idx);
    public static inline function arith(L:State, op:Int) return LuaNative.lua_arith(L, op);
    public static inline function rawequal(L:State, idx1:Int, idx2:Int) return LuaNative.lua_rawequal(L, idx1, idx2);
    public static inline function compare(L:State, idx1:Int, idx2:Int, op:Int) return LuaNative.lua_compare(L, idx1, idx2, op);
    public static inline function pushnil(L:State) return LuaNative.lua_pushnil(L);
    public static inline function pushnumber(L:State, n:Float) return LuaNative.lua_pushnumber(L, n);
    public static inline function pushlstring(L:State, s:CString, len:Int) return LuaNative.lua_pushlstring(L, s, len);
    public static inline function pushstring(L:State, s:CString) return LuaNative.lua_pushstring(L, s);
    public static inline function pushcclosure(L:State, fn:CFunction, n:Int) return LuaNative.lua_pushcclosure(L, fn, n);
    public static inline function pushboolean(L:State, b:Int) return LuaNative.lua_pushboolean(L, b);
    public static inline function pushthread(L:State) return LuaNative.lua_pushthread(L);
    public static inline function getglobal(L:State, name:CString) return LuaNative.lua_getglobal(L, name);
    public static inline function gettable(L:State, idx:Int) return LuaNative.lua_gettable(L, idx);
    public static inline function getfield(L:State, idx:Int, k:CString) return LuaNative.lua_getfield(L, idx, k);
    public static inline function rawget(L:State, idx:Int) return LuaNative.lua_rawget(L, idx);
    public static inline function createtable(L:State, narr:Int, nrec:Int) return LuaNative.lua_createtable(L, narr, nrec);
    public static inline function getmetatable(L:State, objindex:Int) return LuaNative.lua_getmetatable(L, objindex);
    public static inline function getiuservalue(L:State, idx:Int, n:Int) return LuaNative.lua_getiuservalue(L, idx, n);
    public static inline function setglobal(L:State, name:CString) return LuaNative.lua_setglobal(L, name);
    public static inline function settable(L:State, idx:Int) return LuaNative.lua_settable(L, idx);
    public static inline function setfield(L:State, idx:Int, k:CString) return LuaNative.lua_setfield(L, idx, k);
    public static inline function rawset(L:State, idx:Int) return LuaNative.lua_rawset(L, idx);
    public static inline function setmetatable(L:State, objindex:Int) return LuaNative.lua_setmetatable(L, objindex);
    public static inline function setiuservalue(L:State, idx:Int, n:Int) return LuaNative.lua_setiuservalue(L, idx, n);
    public static inline function status(L:State) return LuaNative.lua_status(L);
    public static inline function isyieldable(L:State) return LuaNative.lua_isyieldable(L);
    public static inline function warning(L:State, msg:CString, tocont:Int) return LuaNative.lua_warning(L, msg, tocont);
    public static inline function error(L:State) return LuaNative.lua_error(L);
    public static inline function next(L:State, idx:Int) return LuaNative.lua_next(L, idx);
    public static inline function concat(L:State, n:Int) return LuaNative.lua_concat(L, n);
    public static inline function len(L:State, idx:Int) return LuaNative.lua_len(L, idx);
    public static inline function toclose(L:State, idx:Int) return LuaNative.lua_toclose(L, idx);
    public static inline function closeslot(L:State, idx:Int) return LuaNative.lua_closeslot(L, idx);
    public static inline function getupvalue(L:State, funcindex:Int, n:Int) return LuaNative.lua_getupvalue(L, funcindex, n);
    public static inline function setupvalue(L:State, funcindex:Int, n:Int) return LuaNative.lua_setupvalue(L, funcindex, n);
    public static inline function upvaluejoin(L:State, fidx1:Int, n1:Int, fidx2:Int, n2:Int) return LuaNative.lua_upvaluejoin(L, fidx1, n1, fidx2, n2);
    public static inline function gethookmask(L:State) return LuaNative.lua_gethookmask(L);
    public static inline function gethookcount(L:State) return LuaNative.lua_gethookcount(L);
    public static inline function setcstacklimit(L:State, limit:Int) return LuaNative.lua_setcstacklimit(L, limit);
    public static inline function call(L:State, nargs:Int, nresults:Int) return LuaNative.lua_call(L, nargs, nresults);
    public static inline function pcall(L:State, nargs:Int, nresults:Int, errfunc:Int) return LuaNative.lua_pcall(L, nargs, nresults, errfunc);
    public static inline function l_getmetafield(L:State, obj:Int, e:CString) return LuaNative.luaL_getmetafield(L, obj, e);
    public static inline function l_callmeta(L:State, obj:Int, e:CString) return LuaNative.luaL_callmeta(L, obj, e);
    public static inline function l_argerror(L:State, arg:Int, extramsg:CString) return LuaNative.luaL_argerror(L, arg, extramsg);
    public static inline function l_typeerror(L:State, arg:Int, tname:CString) return LuaNative.luaL_typeerror(L, arg, tname);
    public static inline function l_checknumber(L:State, arg:Int) return LuaNative.luaL_checknumber(L, arg);
    public static inline function l_optnumber(L:State, arg:Int, def:Float) return LuaNative.luaL_optnumber(L, arg, def);
    public static inline function l_checkstack(L:State, sz:Int, msg:CString) return LuaNative.luaL_checkstack(L, sz, msg);
    public static inline function l_checktype(L:State, arg:Int, t:Int) return LuaNative.luaL_checktype(L, arg, t);
    public static inline function l_checkany(L:State, arg:Int) return LuaNative.luaL_checkany(L, arg);
    public static inline function l_newmetatable(L:State, tname:CString) return LuaNative.luaL_newmetatable(L, tname);
    public static inline function l_setmetatable(L:State, tname:CString) return LuaNative.luaL_setmetatable(L, tname);
    public static inline function l_where(L:State, lvl:Int) return LuaNative.luaL_where(L, lvl);
    public static inline function l_fileresult(L:State, stat:Int, fname:CString) return LuaNative.luaL_fileresult(L, stat, fname);
    public static inline function l_execresult(L:State, stat:Int) return LuaNative.luaL_execresult(L, stat);
    public static inline function l_ref(L:State, t:Int) return LuaNative.luaL_ref(L, t);
    public static inline function l_unref(L:State, t:Int, ref:Int) return LuaNative.luaL_unref(L, t, ref);
    public static inline function l_loadfilex(L:State, filename:CString, mode:CString) return LuaNative.luaL_loadfilex(L, filename, mode);
    public static inline function l_loadstring(L:State, s:CString) return LuaNative.luaL_loadstring(L, s);
    public static inline function l_newstate() return LuaNative.luaL_newstate();
    public static inline function l_gsub(L:State, s:CString, p:CString, r:CString) return LuaNative.luaL_gsub(L, s, p, r);
    public static inline function l_getsubtable(L:State, idx:Int, fname:CString) return LuaNative.luaL_getsubtable(L, idx, fname);
    public static inline function l_traceback(L:State, L1:State, msg:CString, level:Int) return LuaNative.luaL_traceback(L, L1, msg, level);
    public static inline function l_requiref(L:State, modname:CString, openf:CFunction, glb:Int) return LuaNative.luaL_requiref(L, modname, openf, glb);
    public static inline function open_base(L:State) return LuaNative.luaopen_base(L);
    public static inline function open_coroutine(L:State) return LuaNative.luaopen_coroutine(L);
    public static inline function open_table(L:State) return LuaNative.luaopen_table(L);
    public static inline function open_io(L:State) return LuaNative.luaopen_io(L);
    public static inline function open_os(L:State) return LuaNative.luaopen_os(L);
    public static inline function open_string(L:State) return LuaNative.luaopen_string(L);
    public static inline function open_utf8(L:State) return LuaNative.luaopen_utf8(L);
    public static inline function open_math(L:State) return LuaNative.luaopen_math(L);
    public static inline function open_debug(L:State) return LuaNative.luaopen_debug(L);
    public static inline function open_package(L:State) return LuaNative.luaopen_package(L);
    public static inline function l_openlibs(L:State) return LuaNative.luaL_openlibs(L);


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
