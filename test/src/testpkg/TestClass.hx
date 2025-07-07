package testpkg;

@:luaExpose
class TestClass {
    public var array:Array<String>;

    public function new(arr:Array<String>) {
        this.array = arr;
    }
}