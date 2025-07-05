package luavm.util;

import haxe.macro.Expr;

/**
 * Utility for creating Lua class wrappers over Haxe classes.
 * This requires FuncHelper to be already initialized for the Lua state.
 */
class ClassWrapper {
    public static macro function push(L:ExprOf<luavm.State>, v:Expr) {
        return ClassWrapperMacros.pushObjectWrapper(L, v);
    }

    public static macro function pushClass(L:ExprOf<luavm.State>, cl:Expr) {
        return ClassWrapperMacros.pushObjectClass(L, cl);
    }
}