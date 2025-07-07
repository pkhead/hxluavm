package testpkg;

@:luaExpose
class TestClass {
    public var array:Array<String>;
    public var number:Float = 3.0;

    public function new(arr:Array<String>) {
        this.array = arr;
    }
}