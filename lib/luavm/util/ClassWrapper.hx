package luavm.util;

import haxe.macro.Expr;

/**
 * Utility for creating Lua class wrappers over Haxe classes.
 * This requires FuncHelper to be already initialized for the Lua state.
 */
class ClassWrapper {
    public static macro function push(L:ExprOf<State>, v:Expr) {
        // trace("try push");
        return ClassWrapperMacros.pushObjectWrapper(L, v);
    }

    public static macro function pushClass(L:ExprOf<State>, cl:Expr) {
        return ClassWrapperMacros.pushObjectClass(L, cl);
    }

    // public static macro function checkType(L:ExprOf<State>, idx:ExprOf<Int>, cl:Expr) {
    //     var wrapper = ClassWrapperMacros.getTypeWrapper(ClassWrapperMacros.parseClassType(cl));
    //     return macro $i{wrapper}.getObject($L, $idx);
    // }
}