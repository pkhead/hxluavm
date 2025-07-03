import Lua;

class Main {
    public static function main() {
        var state = Lua.newstate();
        trace(state);
        Lua.close(state);
    }
}