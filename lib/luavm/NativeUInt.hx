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

    public var isNull(get, never):Bool;
    inline function get_isNull() return toInt32() == 0;

    public function getBytes(count:Int):haxe.io.Bytes {
        var out = haxe.io.Bytes.alloc(count);
        var heapu8 = LuaNative.wasm.HEAPU8;
        for (i in 0...count) {
            out.set(i, heapu8[toInt32() + i]);
        }
        return out;
    }

    @:arrayAccess
    public function getUI8(pos:Int):Int {
        return LuaNative.wasm.HEAPU8[toInt32() + pos];
    }

    public function getUI16(pos:Int):Int {
        var heapu8 = LuaNative.wasm.HEAPU8;
        return
            ((heapu8[toInt32() + pos + 0])      ) |
            ((heapu8[toInt32() + pos + 1]) << 8 );
    }

    public function getI32(pos:Int):Int {
        var heapu8 = LuaNative.wasm.HEAPU8;
        return
            ((heapu8[toInt32() + pos + 0])      ) |
            ((heapu8[toInt32() + pos + 1]) << 8 ) |
            ((heapu8[toInt32() + pos + 2]) << 16) |
            ((heapu8[toInt32() + pos + 3]) << 24);
    }

    public function getF32(pos:Int):Float {
        var view = new js.lib.DataView(LuaNative.wasm.wasmMemory, toInt32()+pos, 4);
        return view.getFloat32(0, true);
    }

    public function getF64(pos:Int):Float {
        var view = new js.lib.DataView(LuaNative.wasm.wasmMemory, toInt32()+pos, 8);
        return view.getFloat64(0, true);
    }

    @:arrayAccess
    public function setUI8(pos:Int, value:Int) {
        LuaNative.wasm.HEAPU8[toInt32() + pos] = value;
    }

    public function setUI16(pos:Int, value:Int) {
        var heapu8 = LuaNative.wasm.HEAPU8;
        heapu8[toInt32() + pos + 0] = (value & 0xFF);
        heapu8[toInt32() + pos + 1] = ((value >> 8) & 0xFF);
    }

    public function setI32(pos:Int, value:Int) {
        var heapu8 = LuaNative.wasm.HEAPU8;
        heapu8[toInt32() + pos + 0] = (value & 0xFF);
        heapu8[toInt32() + pos + 1] = ((value >> 8) & 0xFF);
        heapu8[toInt32() + pos + 2] = ((value >> 16) & 0xFF);
        heapu8[toInt32() + pos + 3] = ((value >> 24) & 0xFF);
    }

    public function setF32(pos:Int, value:Float) {
        var view = new js.lib.DataView(LuaNative.wasm.wasmMemory, toInt32()+pos, 4);
        view.setFloat32(0, value, true);
    }

    public function setF64(pos:Int, value:Float) {
        var view = new js.lib.DataView(LuaNative.wasm.wasmMemory, toInt32()+pos, 8);
        view.setFloat64(0, value, true);
    }
}
#else
abstract NativeUInt(hl.Bytes) {
    @:from
    inline function new(v:hl.Bytes) {
        this = v;
    }

    public var isNull(get, never):Bool;
    function get_isNull() {
        var adr = this.address();
        return adr.low == 0 && adr.high == 0;
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

    public inline function getBytes(count:Int) return this.toBytes(count);

    @:arrayAccess
    public inline function getUI8(pos:Int) return this.getUI8(pos);
    public inline function getUI16(pos:Int) return this.getUI16(pos);
    public inline function getI32(pos:Int) return this.getI32(pos);
    public inline function getF32(pos:Int) return this.getF32(pos);
    public inline function getF64(pos:Int) return this.getF64(pos);

    @:arrayAccess
    public inline function setUI8(pos:Int, value:Int) return this.setUI8(pos, value);
    public inline function setUI16(pos:Int, value:Int) return this.setUI16(pos, value);
    public inline function setI32(pos:Int, value:Int) return this.setI32(pos, value);
    public inline function setF32(pos:Int, value:Single) return this.setF32(pos, value);
    public inline function setF64(pos:Int, value:Float) return this.setF64(pos, value);
}
#end