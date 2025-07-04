// import luavm.Lua;
import luavm.LuaNative;
import luavm.Lua;
import luavm.State;
import luavm.ThreadStatus;
import luavm.FuncHelper;

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

    public static function main() {
        Lua.init(() -> {
            trace("initialization done");
            
            var L = Lua.l_newstate();
            Lua.l_openlibs(L);
            FuncHelper.init(L);

            FuncHelper.push(L, (L) -> {
                var a = Lua.l_checknumber(L, 1);
                var b = Lua.l_checknumber(L, 2);

                Lua.pushnumber(L, a + b);
                return 1;
            });
            Lua.setglobal(L, "add");

            #if js
            FuncHelper.push(L, (L) -> {
                var count = Lua.gettop(L);
                var strs = [];
                for (i in 0...count) {
                    strs.push(Lua.tostring(L, 1 + i));
                }

                js.html.Console.log(strs.join("  "));

                return 0;
            });
            Lua.setglobal(L, "print");

            FuncHelper.push(L, (L) -> {
                var count = Lua.gettop(L);
                var strs = [];
                for (i in 0...count) {
                    strs.push(Lua.tostring(L, 1 + i));
                }

                js.html.Console.warn(strs.join("  "));

                return 0;
            });
            Lua.setglobal(L, "warn");
            #end

            #if sys
            var str = sys.io.File.getContent("code.lua");
            #else
            var str = Macros.getLuaSource();
            #end
            if (Lua.l_loadstring(L, str) != cast ThreadStatus.Ok) {
                trace("parse error!");
                trace(Lua.tostring(L, -1));
            } else if (Lua.pcall(L, 0, 0, 0) != cast ThreadStatus.Ok) {
                trace("runtime error!");
                trace(Lua.tostring(L, -1));
            }

            Lua.close(L);
        });
    }
}