package testpkg;

@:luaExpose
class TestClass {
    public var a:Null<Int> = 2;
    public var notNull:Int = 9;
    public var b:String = "Hi";

    // @:luaHide
    public var inst:TestClass2;

    @:luaFunc
    function someFunc(L:luavm.State) {
        luavm.Lua.pushstring(L, "TESTTESTTEST");
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
    public var a:Int = 2;
    public var b:String = "Hi";

    public function someFunc() {
        
    }

    public function new(a:Int, b:String) {
        this.a = a;
        this.b = b;
    }
}