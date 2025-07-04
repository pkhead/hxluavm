package luavm;
import haxe.Constraints.Function;
import luavm.GcOptions;
import luavm.LuaType;
import luavm.State;
import luavm.ThreadStatus;
import luavm.CString;

@:callable
private abstract Callable<T:Function>(T) to T {
	@:from static function fromT<T:Function>(f:T) {
		return cast hl.Api.noClosure(f);
	}
}

typedef CFunction = Callable<State->Int>;
typedef Reader = Callable<(State, hl.Bytes, hl.Ref<haxe.Int64>)->hl.Bytes>

extern class LuaNative {
    @:hlNative("lua54", "lua_close")
    public static function lua_close(L:State):Void;
    @:hlNative("lua54", "lua_newthread")
    public static function lua_newthread(L:State):State;
    @:hlNative("lua54", "lua_closethread")
    public static function lua_closethread(L:State, from:State):Int;
    @:hlNative("lua54", "lua_resetthread")
    public static function lua_resetthread(L:State):Int;
    @:hlNative("lua54", "lua_atpanic")
    public static function lua_atpanic(L:State, panicf:CFunction):CFunction;
    @:hlNative("lua54", "lua_version")
    public static function lua_version(L:State):Float;
    @:hlNative("lua54", "lua_absindex")
    public static function lua_absindex(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_gettop")
    public static function lua_gettop(L:State):Int;
    @:hlNative("lua54", "lua_settop")
    public static function lua_settop(L:State, idx:Int):Void;
    @:hlNative("lua54", "lua_pushvalue")
    public static function lua_pushvalue(L:State, idx:Int):Void;
    @:hlNative("lua54", "lua_rotate")
    public static function lua_rotate(L:State, idx:Int, n:Int):Void;
    @:hlNative("lua54", "lua_copy")
    public static function lua_copy(L:State, fromidx:Int, toidx:Int):Void;
    @:hlNative("lua54", "lua_checkstack")
    public static function lua_checkstack(L:State, n:Int):Int;
    @:hlNative("lua54", "lua_xmove")
    public static function lua_xmove(from:State, to:State, n:Int):Void;
    @:hlNative("lua54", "lua_isnumber")
    public static function lua_isnumber(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_isstring")
    public static function lua_isstring(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_iscfunction")
    public static function lua_iscfunction(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_isinteger")
    public static function lua_isinteger(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_isuserdata")
    public static function lua_isuserdata(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_type")
    public static function lua_type(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_typename")
    public static function lua_typename(L:State, tp:Int):CString;
    @:hlNative("lua54", "lua_tonumberx")
    public static function lua_tonumberx(L:State, idx:Int, isnum:hl.Ref<Int>):Float;
    @:hlNative("lua54", "lua_tointegerx")
    public static function lua_tointegerx(L:State, idx:Int, isnum:hl.Ref<Int>):haxe.Int64;
    @:hlNative("lua54", "lua_toboolean")
    public static function lua_toboolean(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_tolstring")
    public static function lua_tolstring(L:State, idx:Int, len:hl.Ref<Int>):CString;
    @:hlNative("lua54", "lua_tocfunction")
    public static function lua_tocfunction(L:State, idx:Int):CFunction;
    @:hlNative("lua54", "lua_touserdata")
    public static function lua_touserdata(L:State, idx:Int):hl.Bytes;
    @:hlNative("lua54", "lua_tothread")
    public static function lua_tothread(L:State, idx:Int):State;
    @:hlNative("lua54", "lua_arith")
    public static function lua_arith(L:State, op:Int):Void;
    @:hlNative("lua54", "lua_rawequal")
    public static function lua_rawequal(L:State, idx1:Int, idx2:Int):Int;
    @:hlNative("lua54", "lua_compare")
    public static function lua_compare(L:State, idx1:Int, idx2:Int, op:Int):Int;
    @:hlNative("lua54", "lua_pushnil")
    public static function lua_pushnil(L:State):Void;
    @:hlNative("lua54", "lua_pushnumber")
    public static function lua_pushnumber(L:State, n:Float):Void;
    @:hlNative("lua54", "lua_pushinteger")
    public static function lua_pushinteger(L:State, n:haxe.Int64):Void;
    @:hlNative("lua54", "lua_pushlstring")
    public static function lua_pushlstring(L:State, s:CString, len:Int):CString;
    @:hlNative("lua54", "lua_pushstring")
    public static function lua_pushstring(L:State, s:CString):CString;
    @:hlNative("lua54", "lua_pushcclosure")
    public static function lua_pushcclosure(L:State, fn:CFunction, n:Int):Void;
    @:hlNative("lua54", "lua_pushboolean")
    public static function lua_pushboolean(L:State, b:Int):Void;
    @:hlNative("lua54", "lua_pushlightuserdata")
    public static function lua_pushlightuserdata(L:State, p:hl.Bytes):Void;
    @:hlNative("lua54", "lua_pushthread")
    public static function lua_pushthread(L:State):Int;
    @:hlNative("lua54", "lua_getglobal")
    public static function lua_getglobal(L:State, name:CString):Int;
    @:hlNative("lua54", "lua_gettable")
    public static function lua_gettable(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_getfield")
    public static function lua_getfield(L:State, idx:Int, k:CString):Int;
    @:hlNative("lua54", "lua_geti")
    public static function lua_geti(L:State, idx:Int, n:haxe.Int64):Int;
    @:hlNative("lua54", "lua_rawget")
    public static function lua_rawget(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_rawgeti")
    public static function lua_rawgeti(L:State, idx:Int, n:haxe.Int64):Int;
    @:hlNative("lua54", "lua_createtable")
    public static function lua_createtable(L:State, narr:Int, nrec:Int):Void;
    @:hlNative("lua54", "lua_newuserdatauv")
    public static function lua_newuserdatauv(L:State, sz:haxe.Int64, nuvalue:Int):hl.Bytes;
    @:hlNative("lua54", "lua_getmetatable")
    public static function lua_getmetatable(L:State, objindex:Int):Int;
    @:hlNative("lua54", "lua_getiuservalue")
    public static function lua_getiuservalue(L:State, idx:Int, n:Int):Int;
    @:hlNative("lua54", "lua_setglobal")
    public static function lua_setglobal(L:State, name:CString):Void;
    @:hlNative("lua54", "lua_settable")
    public static function lua_settable(L:State, idx:Int):Void;
    @:hlNative("lua54", "lua_setfield")
    public static function lua_setfield(L:State, idx:Int, k:CString):Void;
    @:hlNative("lua54", "lua_seti")
    public static function lua_seti(L:State, idx:Int, n:haxe.Int64):Void;
    @:hlNative("lua54", "lua_rawset")
    public static function lua_rawset(L:State, idx:Int):Void;
    @:hlNative("lua54", "lua_rawseti")
    public static function lua_rawseti(L:State, idx:Int, n:haxe.Int64):Void;
    @:hlNative("lua54", "lua_setmetatable")
    public static function lua_setmetatable(L:State, objindex:Int):Int;
    @:hlNative("lua54", "lua_setiuservalue")
    public static function lua_setiuservalue(L:State, idx:Int, n:Int):Int;
    @:hlNative("lua54", "lua_load")
    public static function lua_load(L:State, reader:Reader, dt:hl.Bytes, chunkname:CString, mode:CString):Int;
    @:hlNative("lua54", "lua_resume")
    public static function lua_resume(L:State, from:State, narg:Int, nres:hl.Ref<Int>):Int;
    @:hlNative("lua54", "lua_status")
    public static function lua_status(L:State):Int;
    @:hlNative("lua54", "lua_isyieldable")
    public static function lua_isyieldable(L:State):Int;
    @:hlNative("lua54", "lua_warning")
    public static function lua_warning(L:State, msg:CString, tocont:Int):Void;
    @:hlNative("lua54", "lua_error")
    public static function lua_error(L:State):Int;
    @:hlNative("lua54", "lua_next")
    public static function lua_next(L:State, idx:Int):Int;
    @:hlNative("lua54", "lua_concat")
    public static function lua_concat(L:State, n:Int):Void;
    @:hlNative("lua54", "lua_len")
    public static function lua_len(L:State, idx:Int):Void;
    @:hlNative("lua54", "lua_stringtonumber")
    public static function lua_stringtonumber(L:State, s:CString):haxe.Int64;
    @:hlNative("lua54", "lua_toclose")
    public static function lua_toclose(L:State, idx:Int):Void;
    @:hlNative("lua54", "lua_closeslot")
    public static function lua_closeslot(L:State, idx:Int):Void;
    @:hlNative("lua54", "lua_getupvalue")
    public static function lua_getupvalue(L:State, funcindex:Int, n:Int):CString;
    @:hlNative("lua54", "lua_setupvalue")
    public static function lua_setupvalue(L:State, funcindex:Int, n:Int):CString;
    @:hlNative("lua54", "lua_upvalueid")
    public static function lua_upvalueid(L:State, fidx:Int, n:Int):hl.Bytes;
    @:hlNative("lua54", "lua_upvaluejoin")
    public static function lua_upvaluejoin(L:State, fidx1:Int, n1:Int, fidx2:Int, n2:Int):Void;
    @:hlNative("lua54", "lua_gethookmask")
    public static function lua_gethookmask(L:State):Int;
    @:hlNative("lua54", "lua_gethookcount")
    public static function lua_gethookcount(L:State):Int;
    @:hlNative("lua54", "lua_setcstacklimit")
    public static function lua_setcstacklimit(L:State, limit:Int):Int;
    @:hlNative("lua54", "lua_call")
    public static function lua_call(L:State, nargs:Int, nresults:Int):Void;
    @:hlNative("lua54", "lua_pcall")
    public static function lua_pcall(L:State, nargs:Int, nresults:Int, errfunc:Int):Int;
    @:hlNative("lua54", "luaL_checkversion_")
    public static function luaL_checkversion_(L:State, ver:Float, sz:haxe.Int64):Void;
    @:hlNative("lua54", "luaL_getmetafield")
    public static function luaL_getmetafield(L:State, obj:Int, e:CString):Int;
    @:hlNative("lua54", "luaL_callmeta")
    public static function luaL_callmeta(L:State, obj:Int, e:CString):Int;
    @:hlNative("lua54", "luaL_argerror")
    public static function luaL_argerror(L:State, arg:Int, extramsg:CString):Int;
    @:hlNative("lua54", "luaL_typeerror")
    public static function luaL_typeerror(L:State, arg:Int, tname:CString):Int;
    @:hlNative("lua54", "luaL_checknumber")
    public static function luaL_checknumber(L:State, arg:Int):Float;
    @:hlNative("lua54", "luaL_optnumber")
    public static function luaL_optnumber(L:State, arg:Int, def:Float):Float;
    @:hlNative("lua54", "luaL_checkinteger")
    public static function luaL_checkinteger(L:State, arg:Int):haxe.Int64;
    @:hlNative("lua54", "luaL_optinteger")
    public static function luaL_optinteger(L:State, arg:Int, def:haxe.Int64):haxe.Int64;
    @:hlNative("lua54", "luaL_checkstack")
    public static function luaL_checkstack(L:State, sz:Int, msg:CString):Void;
    @:hlNative("lua54", "luaL_checktype")
    public static function luaL_checktype(L:State, arg:Int, t:Int):Void;
    @:hlNative("lua54", "luaL_checkany")
    public static function luaL_checkany(L:State, arg:Int):Void;
    @:hlNative("lua54", "luaL_newmetatable")
    public static function luaL_newmetatable(L:State, tname:CString):Int;
    @:hlNative("lua54", "luaL_setmetatable")
    public static function luaL_setmetatable(L:State, tname:CString):Void;
    @:hlNative("lua54", "luaL_testudata")
    public static function luaL_testudata(L:State, ud:Int, tname:CString):hl.Bytes;
    @:hlNative("lua54", "luaL_checkudata")
    public static function luaL_checkudata(L:State, ud:Int, tname:CString):hl.Bytes;
    @:hlNative("lua54", "luaL_where")
    public static function luaL_where(L:State, lvl:Int):Void;
    @:hlNative("lua54", "luaL_fileresult")
    public static function luaL_fileresult(L:State, stat:Int, fname:CString):Int;
    @:hlNative("lua54", "luaL_execresult")
    public static function luaL_execresult(L:State, stat:Int):Int;
    @:hlNative("lua54", "luaL_ref")
    public static function luaL_ref(L:State, t:Int):Int;
    @:hlNative("lua54", "luaL_unref")
    public static function luaL_unref(L:State, t:Int, ref:Int):Void;
    @:hlNative("lua54", "luaL_loadfilex")
    public static function luaL_loadfilex(L:State, filename:CString, mode:CString):Int;
    @:hlNative("lua54", "luaL_loadbufferx")
    public static function luaL_loadbufferx(L:State, buff:CString, sz:haxe.Int64, name:CString, mode:CString):Int;
    @:hlNative("lua54", "luaL_loadstring")
    public static function luaL_loadstring(L:State, s:CString):Int;
    @:hlNative("lua54", "luaL_newstate")
    public static function luaL_newstate():State;
    @:hlNative("lua54", "luaL_len")
    public static function luaL_len(L:State, idx:Int):haxe.Int64;
    @:hlNative("lua54", "luaL_gsub")
    public static function luaL_gsub(L:State, s:CString, p:CString, r:CString):CString;
    @:hlNative("lua54", "luaL_getsubtable")
    public static function luaL_getsubtable(L:State, idx:Int, fname:CString):Int;
    @:hlNative("lua54", "luaL_traceback")
    public static function luaL_traceback(L:State, L1:State, msg:CString, level:Int):Void;
    @:hlNative("lua54", "luaL_requiref")
    public static function luaL_requiref(L:State, modname:CString, openf:CFunction, glb:Int):Void;
    @:hlNative("lua54", "luaopen_base")
    public static function luaopen_base(L:State):Int;
    @:hlNative("lua54", "luaopen_coroutine")
    public static function luaopen_coroutine(L:State):Int;
    @:hlNative("lua54", "luaopen_table")
    public static function luaopen_table(L:State):Int;
    @:hlNative("lua54", "luaopen_io")
    public static function luaopen_io(L:State):Int;
    @:hlNative("lua54", "luaopen_os")
    public static function luaopen_os(L:State):Int;
    @:hlNative("lua54", "luaopen_string")
    public static function luaopen_string(L:State):Int;
    @:hlNative("lua54", "luaopen_utf8")
    public static function luaopen_utf8(L:State):Int;
    @:hlNative("lua54", "luaopen_math")
    public static function luaopen_math(L:State):Int;
    @:hlNative("lua54", "luaopen_debug")
    public static function luaopen_debug(L:State):Int;
    @:hlNative("lua54", "luaopen_package")
    public static function luaopen_package(L:State):Int;
    @:hlNative("lua54", "luaL_openlibs")
    public static function luaL_openlibs(L:State):Void;
}