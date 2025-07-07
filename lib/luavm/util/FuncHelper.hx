package luavm.util;

import luavm.LuaNative;

/**
 * Utility class for pushing Haxe functions.
 * 
 * There are limitations/qualms with regards to pushing Haxe functions onto the Lua stack.
 * - hl: Functions cannot reference a closure.
 * - js: You must manually allocate a function pointer for every function you want to push.
 * 
 * This class provides a good workaround for this issue.
 */
class FuncHelper {
    private static var funcMap:Map<Int, State->Int> = [];
    private static var nextId = 1;
    private static var HX_CLOSURE_MT = "HaxeFunction";

    #if js
    static var callCallbackHandle:FuncPtr<CFunction>;
    #else
    static var callCallbackHandle:CFunction;
    #end

    static function isNullPtr(ptr:NativePtr) {
        if (ptr == null) return true;
        var adr = ptr.address();
        return adr.low == 0 && adr.high == 0;
    }

    static function gcCallback(L:luavm.State) {
        var ptr = Lua.l_checkudata(L, 1, HX_CLOSURE_MT);
        if (!isNullPtr(ptr)) {
            var id = ptr.getI32(0);
            funcMap.remove(id);
        }

        return 0;
    }

    static function callCallback(L:luavm.State) {
        var ptr = Lua.l_checkudata(L, Lua.upvalueindex(1), HX_CLOSURE_MT);
        if (!isNullPtr(ptr)) {
            var id = ptr.getI32(0);
            var f = funcMap[id];
            if (f != null) {
                return f(L);
            }
        }

        return 0;
    }

    /**
     * Initialize the uility.
     * @param L The main Lua state.
     */
    public static function init(L:luavm.State) {
        #if js
        var gcFuncHandle = LuaNative.allocFuncPtr(gcCallback, CFunction);
        callCallbackHandle = LuaNative.allocFuncPtr(callCallback, CFunction);
        #else
        var gcFuncHandle = gcCallback;
        callCallbackHandle = callCallback;
        #end

        Lua.l_newmetatable(L, HX_CLOSURE_MT);
        LuaNative.lua_pushcclosure(L, gcFuncHandle, 0);
        Lua.setfield(L, -2, "__gc");
        Lua.pop(L, 1);
    }

    /**
     * Push a Haxe function onto the Lua stack.
     * 
     * Note: when the given function is being called, the first upvalue will exist
     * and will refer to internal data.
     * @param L The Lua state.
     * @param func The CFunction to push.
     */
    public static function push(L:luavm.State, func:luavm.State->Int) {
        var ptr = LuaNative.lua_newuserdatauv(L, 4, 1);
        ptr.setI32(0, nextId);
        funcMap[nextId] = func;
        nextId++;

        Lua.l_getmetatable(L, HX_CLOSURE_MT);
        Lua.setmetatable(L, -2);

        LuaNative.lua_pushcclosure(L, callCallbackHandle, 1);
    }

    /**
     * Push a closure of a Haxe function onto the Lua stack with upvalues.
     * Refer to [the Lua manual](https://www.lua.org/manual/5.4/manual.html#lua_pushcclosure)
     * 
     * Note: The second upvalue index is the first user-defined upvalue. The first
     * upvalue will exist to internal data.
     * @param L The Lua state.
     * @param func The CFunction to push.
     */
    public static function pushClosure(L:luavm.State, upvalues:Int, func:luavm.State->Int) {
        var ptr = LuaNative.lua_newuserdatauv(L, 4, 1);
        ptr.setI32(0, nextId);
        funcMap[nextId] = func;
        nextId++;

        Lua.l_getmetatable(L, HX_CLOSURE_MT);
        Lua.setmetatable(L, -2);

        Lua.insert(L, -upvalues - 1);

        LuaNative.lua_pushcclosure(L, callCallbackHandle, upvalues + 1);
    }
}