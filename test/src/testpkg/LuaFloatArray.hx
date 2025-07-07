package testpkg;

import luavm.Lua;
import luavm.util.ClassWrapper;

@:luaExpose
class LuaFloatArray {
    var array:Array<Float>;

    public var length(get, never):Int;
    inline function get_length() return array.length;

    @:luaFunc @:luaName("get")
    function luaGet(L:luavm.State):Int {
        var i = Lua.l_checkinteger(L, 2);
        Lua.pushnumber(L, array[i-1]);
        return 1;
    }

    @:luaFunc @:luaName("set")
    function luaSet(L:luavm.State):Int {
        var i = Lua.l_checkinteger(L, 2);
        var v = Lua.l_checknumber(L, 3);
        array[i-1] = v;
        return 0;
    }

    @:luaFunc @:luaName("push")
    function luaPush(L:luavm.State):Int {
        var v = Lua.l_checknumber(L, 2);
        array.push(v);
        return 0;
    }

    @:luaFunc @:luaName("new")
    static function luaNew(L:luavm.State):Int {
        ClassWrapper.push(L, new LuaFloatArray());
        return 1;
    }

    public function new() {
        array = [];
    }
}

// @:luaExpose
// class TestClass {
//     public static final CONST = 3;

//     @:luaName("int_field")
//     public var intField:Int;

//     @:luaName("string_field")
//     public var stringField:String;

//     @:luaName("array_field")
//     public var arrayField:LuaFloatArray;

//     @:luaFunc @:luaName("new")
//     static function luaCtor(L:luavm.State):Int {
//         var int = Lua.l_checkinteger(L, 1);
//         var str = Lua.l_checkstring(L, 2);
//         var arr = ClassWrapper.checkType(L, 3, LuaFloatArray);
//         ClassWrapper.push(L, new TestClass(int, str, arr));
//         return 1;
//     }

//     public function new(int:Int, str:String, arr:LuaFloatArray) {
//         intField = int;
//         stringField = str;
//         arrayField = arr;
//     }
// }