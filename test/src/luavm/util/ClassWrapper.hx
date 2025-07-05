package luavm.util;

import haxe.macro.Expr;

class ClassWrapper {
    public static macro function push(L:ExprOf<luavm.State>, v:Expr) {
        return Macros.pushObjectWrapper(L, v);
    }
}