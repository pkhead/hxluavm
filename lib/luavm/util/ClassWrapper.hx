package luavm.util;

import haxe.macro.Expr;

/**
 * Utility for creating Lua class wrappers over Haxe classes.
 * This requires FuncHelper to be already initialized for the Lua state.
 */
class ClassWrapper {
    /**
     * Push the wrapper of a Haxe object onto the Lua stack.
     * @param L The Lua state.
     * @param v The class or abstract instance to push.
     */
    public static macro function pushObject(L:ExprOf<State>, v:Expr) {
        return ClassWrapperMacros.pushObjectWrapper(L, v);
    }

    /**
     * Push the wrapper of a Haxe class onto the Lua stack. This is a table
     * which contains static/instance functions and also the class's static fields.
     * @param L The Lua state.
     * @param cl The class or abstract to push.
     */
    public static macro function pushClass(L:ExprOf<State>, cl:Expr) {
        return ClassWrapperMacros.pushClassWrapper(L, cl);
    }

    /**
     * Push the metatable for the Haxe object wrapper of the given type.
     * @param L The Lua state.
     * @param cl The class or abstract to push.
     */
    public static macro function pushMetatable(L:ExprOf<State>, cl:Expr) {
        return ClassWrapperMacros.pushMetatable(L, cl);
    }

    /**
     * Return the value at the index as a given Haxe type, throwing an error
     * if the type does not match.
     * @param L The Lua state.
     * @param idx The index of the Lua stack to fetch.
     * @param cl The expected class or abstract type.
     */
    public static macro function checkObject(L:ExprOf<State>, idx:ExprOf<Int>, cl:Expr) {
        var wrapper = ClassWrapperMacros.getTypeWrapper(ClassWrapperMacros.parseClassType(cl));
        return macro $i{wrapper}.getObject($L, $idx);
    }

    #if macro
    /**
     * Substitute one type to another when parsing the fields of types or parameters.
     * 
     * This must be called from an initialization macro. The replacement type also
     * must satisfy these requirements, lest it throw an error:
     * 1. It must be an abstract over the source type.
     * 2. Implicit conversions to/from the types must be possible.
     * @param srcType The type that will be substituted.
     * @param dstType The type that will be the substitute.
     */
    public static function registerTypeSubstitute(srcType:String, dstType:String) {
        ClassWrapperMacros.registerSubstitute(srcType, dstType);
    }
    #end
}