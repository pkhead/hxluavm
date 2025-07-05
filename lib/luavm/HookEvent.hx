package luavm;

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