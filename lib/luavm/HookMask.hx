package luavm;

enum abstract HookMask(Int) from Int to Int {
    var MaskCall = (1 << 0);
    var MaskRet = (1 << 1);
    var MaskLine = (1 << 2);
    var MaskCount = (1 << 3);

    @:to inline function toInt():Int {
        return this;
    }
    // (1 << 5);

    @:op(A | B) static inline function or(a:HookMask, b:HookMask):HookMask {
        //return a | b;
        return cast (a.toInt() | b.toInt());
    }
}