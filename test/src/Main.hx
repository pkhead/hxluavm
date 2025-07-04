import lua54.Lua;
import lua54.LuaNative;
import lua54.State;
import lua54.ThreadStatus;

class Main {
    static function addFunc(L:State) {
        var a = Lua.tonumber(L, 1);
        var b = Lua.tonumber(L, 2);
        Lua.pushnumber(L, a + b);
        return 1;
    }

    static function luaLoadFile(L:State, path:String) {
        var fileContents = sys.io.File.getBytes(path);
        // var res = LuaNative.lua_load(L, readerFunc, null, path, "bt");
        return Lua.loadBytes(L, fileContents, path, "bt");
    }

    public static function main() {
        var state = Lua.l_newstate();
        Lua.l_openlibs(state);

        Lua.pushcfunction(state, (L:State) -> {
            var c = 1.0;
            var a = Lua.tonumber(L, 1);
            var b = Lua.tonumber(L, 2);
            Lua.pushnumber(L, a + b + c);
            return 1;
        });
        Lua.setglobal(state, "add");

        // Lua.l_loadfilex(state, "code.lua", "t");
        luaLoadFile(state, "code.lua");
        // LuaNative.lua_getglobal(state, haxe.io.Bytes.ofString("print"));
        // trace(Lua.typename(state, cast Lua.type(state, -1)));
        if (Lua.pcall(state, 0, 0, 0) != cast ThreadStatus.Ok) {
            trace("lua error!");
            var str = Lua.tostring(state, -1);
            trace(str);
        } else {
            // Lua.getglobal(state, "test_func");
            // Lua.pushstring(state, "Hip Hip horray!");
            // if (Lua.pcall(state, 1, 0, 0) != cast ThreadStatus.Ok) {
            //     trace(Lua.tostring(state, -1));
            // }
        }
        Lua.close(state);
    }
}