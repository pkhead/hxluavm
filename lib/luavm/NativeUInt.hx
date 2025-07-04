package luavm;

/**
 * Unsigned integer of the Lua VM's native size.
 * hl: The system architecture's size.
 * js: 32 bits, as it uses wasm32.
 */
#if js
abstract NativeUInt(Int) {
    @:from public static inline function fromInt(v:Int) {
        return cast v;
    }

    @:from public static inline function fromInt64(v:haxe.Int64) {
        return cast v.low;
    }
    
    public inline function toInt32() {
        return this;
    }

    public inline function toInt64() {
        return haxe.Int64.ofInt(this);
    }
}
#else
abstract NativeUInt(hl.Bytes) {
    inline function new(v:hl.Bytes) {
        this = v;
    }

    @:to inline function toBytes():hl.Bytes {
        return this;
    }

    @:from public static inline function fromInt(v:Int) {
        return new NativeUInt(hl.Bytes.fromAddress(v));
    }

    @:from public static inline function fromInt64(v:haxe.Int64) {
        return new NativeUInt(hl.Bytes.fromAddress(v));
    }
    
    public inline function toInt32() {
        return this.address().low;
    }

    public inline function toInt64() {
        return this.address();
    }
}
#end