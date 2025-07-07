// import luavm.Lua;
import testpkg.LuaStringArray;
import luavm.LuaNative;
import luavm.Lua;
import luavm.State;
import luavm.util.FuncHelper;
import luavm.util.ClassWrapper;

// import testpkg.LuaFloatArray;

// class TestClass {
//     static var wrapCache:Map<testpkg.LuaStringArray, Int> = [];
// }

class Main {
    // static function addFunc(L:State) {
    //     var a = Lua.tonumber(L, 1);
    //     var b = Lua.tonumber(L, 2);
    //     Lua.pushnumber(L, a + b);
    //     return 1;
    // }

    // static function luaLoadFile(L:State, path:String) {
    //     var fileContents = sys.io.File.getBytes(path);
    //     // var res = LuaNative.lua_load(L, readerFunc, null, path, "bt");
    //     return Lua.loadBytes(L, fileContents, path, "bt");
    // }

    // public static function main() {
    //     var state = Lua.l_newstate();
    //     Lua.l_openlibs(state);

    //     Lua.pushcfunction(state, (L:State) -> {
    //         var c = 1.0;
    //         var a = Lua.tonumber(L, 1);
    //         var b = Lua.tonumber(L, 2);
    //         Lua.pushnumber(L, a + b + c);
    //         return 1;
    //     });
    //     Lua.setglobal(state, "add");

    //     // Lua.l_loadfilex(state, "code.lua", "t");
    //     luaLoadFile(state, "code.lua");
    //     // LuaNative.lua_getglobal(state, haxe.io.Bytes.ofString("print"));
    //     // trace(Lua.typename(state, cast Lua.type(state, -1)));
    //     if (Lua.pcall(state, 0, 0, 0) != cast ThreadStatus.Ok) {
    //         trace("lua error!");
    //         var str = Lua.tostring(state, -1);
    //         trace(str);
    //     } else {
    //         // Lua.getglobal(state, "test_func");
    //         // Lua.pushstring(state, "Hip Hip horray!");
    //         // if (Lua.pcall(state, 1, 0, 0) != cast ThreadStatus.Ok) {
    //         //     trace(Lua.tostring(state, -1));
    //         // }
    //     }
    //     Lua.close(state);
    // }

    static function luaHook(L:luavm.State, ar:DebugPtr) {
        trace("hook activated", ar.event);
    }

    // static function tests1(L:luavm.State) {
    //     FuncHelper.push(L, (L) -> {
    //         var a = Lua.l_checknumber(L, 1);
    //         var b = Lua.l_checknumber(L, 2);

    //         Lua.pushnumber(L, a + b);
    //         return 1;
    //     });
    //     Lua.setglobal(L, "add");

    //     #if js
    //     FuncHelper.push(L, (L) -> {
    //         var count = Lua.gettop(L);
    //         var strs = [];
    //         for (i in 0...count) {
    //             strs.push(Lua.tostring(L, 1 + i));
    //         }

    //         js.html.Console.log(strs.join("  "));

    //         return 0;
    //     });
    //     Lua.setglobal(L, "print");

    //     FuncHelper.push(L, (L) -> {
    //         var count = Lua.gettop(L);
    //         var strs = [];
    //         for (i in 0...count) {
    //             strs.push(Lua.tostring(L, 1 + i));
    //         }

    //         js.html.Console.warn(strs.join("  "));

    //         return 0;
    //     });
    //     Lua.setglobal(L, "warn");
    //     #end

    //     // ClassWrapper.push(L, new TestClass(4, "hi"));
    //     ClassWrapper.pushClass(L, TestClass);
    //     Lua.setglobal(L, "TestClass");

    //     ClassWrapper.pushClass(L, LuaFloatArray);
    //     Lua.setglobal(L, "FloatArray");

    //     #if js
    //     var f = LuaNative.allocFuncPtr(luaHook, Hook);
    //     #else
    //     var f = luaHook;
    //     #end

    //     Lua.sethook(L, f, HookMask.MaskLine, 0);
    // }

    static function tests2(L:luavm.State) {
        ClassWrapper.pushMetatable(L, LuaStringArray);

        // override __index
        Lua.getfield(L, -1, "__index");
        FuncHelper.pushClosure(L, 1, (L:luavm.State) -> {
            if (Lua.isnumber(L, 2) != 0) {
                var obj = ClassWrapper.checkObject(L, 1, LuaStringArray);
                var idx = Lua.tointeger(L, 2) - 1;

                if (idx < 0 || idx >= obj.array.length) {
                    return Lua.l_error(L, "index is out of bounds of the array");
                }

                Lua.pushstring(L, obj.array[idx]);
                return 1;
            } else {
                Lua.pushvalue(L, Lua.upvalueindex(2));
                Lua.pushvalue(L, 1);
                Lua.pushvalue(L, 2);
                Lua.call(L, 2, 1);
                return 1;
            }
        });
        Lua.setfield(L, -2, "__index");

        // override __newindex
        Lua.getfield(L, -1, "__newindex");
        FuncHelper.pushClosure(L, 1, (L:luavm.State) -> {
            if (Lua.isnumber(L, 2) != 0) {
                var obj = ClassWrapper.checkObject(L, 1, LuaStringArray);
                var idx = Lua.tointeger(L, 2) - 1;
                var value = Lua.l_checkstring(L, 3);

                if (idx == obj.array.length) {
                    obj.array.push(value);
                } else if (idx < 0 || idx >= obj.array.length) {
                    return Lua.l_error(L, "index is out of bounds of the array");
                } else {
                    obj.array[idx] = value;
                }

            } else {
                Lua.pushvalue(L, Lua.upvalueindex(2));
                Lua.pushvalue(L, 1);
                Lua.pushvalue(L, 2);
                Lua.pushvalue(L, 3);
                Lua.call(L, 3, 1);
            }

            return 0;
        });
        Lua.setfield(L, -2, "__newindex");

        FuncHelper.push(L, (L:luavm.State) -> {
            var obj = ClassWrapper.checkObject(L, 1, LuaStringArray);
            Lua.pushinteger(L, obj.length);
            return 1;
        });
        Lua.setfield(L, -2, "__len");

        Lua.pop(L, 1);

        ClassWrapper.pushClass(L, testpkg.LuaStringArray);
        Lua.setglobal(L, "StringArray");
    }

    // static function test3(L:luavm.State) {
    //     ClassWrapper.pushMetatable(L, LuaArray<String>);
    // }

    public static function main1() {
        Lua.init(() -> {            
            var L = Lua.l_newstate();
            Lua.l_openlibs(L);
            FuncHelper.init(L);

            tests2(L);

            #if sys
            var str = sys.io.File.getContent("code.lua");
            #else
            var str = Macros.getLuaSource();
            #end
            
            trace("SOURCE:\n\n" + str);

            FuncHelper.push(L, (L) -> {
                var err = Lua.tostring(L, 1);
                Lua.l_traceback(L, L, err, 0);
                trace(Lua.tostring(L, -1));

                return 0;
            });

            if (Lua.l_loadstring(L, str) != cast ThreadStatus.Ok) {
                trace("parse error!");
                trace(Lua.tostring(L, -1));
            } else {
                if (Lua.pcall(L, 0, 0, -2) != cast ThreadStatus.Ok) {
                    trace("runtime error!");
                    // trace(Lua.tostring(L, -1));
                }
            }

            Lua.close(L);
        });
    }

    public static function main2() {

    }

    public static function main() {
        main1();
    }
}