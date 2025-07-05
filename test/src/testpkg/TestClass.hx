package testpkg;

@:luaExpose
class TestClass {
    public var a:Int = 2;
    public var b:String = "Hi";

    @:luaHide
    public var inst:TestClass2;

    public function someFunc() {
        
    }

    public function new(a:Int, b:String) {
        this.a = a;
        this.b = b;
        this.inst = null;
    }
}

// @:luaExpose
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