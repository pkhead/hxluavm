package testpkg;

@:generic
abstract LuaArray<T>(Array<T>) {
    public inline function new() {
        this = [];
    }

    @:luaHide
    public var array(get, never):Array<T>;
    inline function get_array() return this;
    
    public var length(get, never):Int;
    inline function get_length() return this.length;

    public function push(v:T):Int {
        return this.push(v);
    }
}