package testpkg;

enum TestEnum {
    EnumFoo;
    EnumBar;
    EnumBaz;
}

@:luaExpose
class TestClass {
    public var array:Array<String>;
    public var number:Float = 3.0;
    public var enumVar:TestEnum = EnumFoo;

    public function multiply(num:Float) {
        number *= num;
        return enumVar;
    }

    public function new(arr:Array<String>, e:TestEnum) {
        this.array = arr;
        this.enumVar = e;
    }
}