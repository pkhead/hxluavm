package testpkg;

// @:luaExpose
// abstract LuaStringArray(Array<String>) {
//     public var length(get, never):Int;
//     inline function get_length() return this.length;

//     public inline function new() {
//         this = [];
//     }

//     public function lengthTimesTwo() {
//         return this.length * 2;
//     }
// }

@:luaExpose
abstract LuaStringArray(Array<String>) from Array<String> to Array<String> {
    public inline function new() {
        this = [];
    }

    @:luaHide
    public var array(get, never):Array<String>;
    inline function get_array() return this;
    
    public var length(get, never):Int;
    inline function get_length() return this.length;

    public function push(v:String):Int {
        return this.push(v);
    }
}
// @:luaExpose
// class LuaStringArray {
//     public static final JIM = 3;
//     private var _array:Array<String>;

//     public function new() {
//         _array = [];
//     }

//     public var length(get, set):Int;
//     inline function get_length() return _array.length;
//     inline function set_length(v) return v;

//     public inline function push(v:String) {
//         return _array.push(v);
//     }

//     public function getLengthTimesThisNumber(num:Int) {
//         return length * num;
//     }

//     public static function staticFunction(a:Int, ?b:Float, ?c:String) {
//         return "HI";
//     }

//     public var firstValue(get, set):String;
//     inline function get_firstValue() return _array[0];
//     inline function set_firstValue(v) return _array[0] = v;
// }