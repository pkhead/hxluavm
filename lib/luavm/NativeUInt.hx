package luavm;

/**
 * Unsigned integer of the Lua VM's native size.
 * hl: The system architecture's size.
 * js: 32 bits, as it uses wasm32.
 */
#if js
// typedef NativeUInt = Int;
abstract NativeUInt(Int) from Int to Int {
    public var low(get, set):Int;
    public var high(get, set):Int;

    inline function get_low() return this;
    inline function set_low(v:Int) return this = v;
    inline function get_high() return 0;
    inline function set_high(v:Int) return 0;

    @:from public static inline function ofInt(x:Int):NativeUInt {
        return x;
    }

    @:to public inline function toInt():Int {
        return this;
    }

    @:from static inline function fromInt64(v:haxe.Int64):NativeUInt {
        return v.low;
    }

    @:to inline function toInt64():haxe.Int64 {
        return haxe.Int64.make(0, this);
    }

    public static function make(high:Int, low:Int):NativeUInt {
        return low;
    }

    @:op(A+B) inline static function add(a:NativeUInt, b:NativeUInt):NativeUInt {
        return a.toInt() + b.toInt();
    }
}
#else
typedef NativeUInt = haxe.Int64;
// abstract NativeUInt(hl.Bytes) {
//     @:from
//     inline function new(v:hl.Bytes) {
//         this = v;
//     }

//     public var isNull(get, never):Bool;
//     function get_isNull() {
//         var adr = this.address();
//         return adr.low == 0 && adr.high == 0;
//     }

//     @:to inline function toBytes():hl.Bytes {
//         return this;
//     }

//     @:from public static inline function fromInt(v:Int) {
//         return new NativeUInt(hl.Bytes.fromAddress(v));
//     }

//     @:from public static inline function fromInt64(v:haxe.Int64) {
//         return new NativeUInt(hl.Bytes.fromAddress(v));
//     }
    
//     public inline function toInt32() {
//         return this.address().low;
//     }

//     public inline function toInt64() {
//         return this.address();
//     }

//     public inline function getBytes(count:Int) return this.toBytes(count);

//     @:arrayAccess
//     public inline function getUI8(pos:Int) return this.getUI8(pos);
//     public inline function getUI16(pos:Int) return this.getUI16(pos);
//     public inline function getI32(pos:Int) return this.getI32(pos);
//     public inline function getF32(pos:Int) return this.getF32(pos);
//     public inline function getF64(pos:Int) return this.getF64(pos);

//     @:arrayAccess
//     public inline function setUI8(pos:Int, value:Int) return this.setUI8(pos, value);
//     public inline function setUI16(pos:Int, value:Int) return this.setUI16(pos, value);
//     public inline function setI32(pos:Int, value:Int) return this.setI32(pos, value);
//     public inline function setF32(pos:Int, value:Single) return this.setF32(pos, value);
//     public inline function setF64(pos:Int, value:Float) return this.setF64(pos, value);
// }
#end