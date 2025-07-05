package testpkg;

import luavm.Lua;
import luavm.util.ClassWrapper;

@:luaExpose
class TestClass {
    public static final CONST = 3;
    public var a:Null<Int> = 2;
    public var notNull:Int = 9;

    var b:String = "Hi";

    // @:luaHide
    @:luaName("inst_var")
    public var inst:TestClass2;

    @:luaFunc
    function someFunc(L:luavm.State) {
        luavm.Lua.pushstring(L, "TESTTESTTEST");
        return 1;
    }

    @:luaFunc @:luaName("new")
    static function luaCtor(L:luavm.State):Int {
        var a = Lua.tointeger(L, 1);
        var b = Lua.tostring(L, 2);
        ClassWrapper.push(L, new TestClass(a, b));
        return 1;
    }

    public function new(a:Int, b:String) {
        this.a = a;
        this.b = b;
        this.inst = null;
    }
}

@:luaExpose
class TestClass2 {
    public static final CONST2 = "HIDSA";

    public var a:Int = 2;
    public var b:String = "Hi";

    public function someFunc() {
        
    }

    public function new(a:Int, b:String) {
        this.a = a;
        this.b = b;
    }
}