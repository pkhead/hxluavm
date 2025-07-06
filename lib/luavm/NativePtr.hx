package luavm;

#if js
abstract NativePtr(NativeUInt) from NativeUInt to NativeUInt {
    @:from public static inline function fromInt(v:Int) {
        return cast v;
    }

    @:from public static inline function fromInt64(v:haxe.Int64) {
        return cast v.low;
    }
    
    @:to public inline function toInt32():Int {
        return this;
    }

    public inline function toInt64() {
        return haxe.Int64.ofInt(this);
    }

    public var isNull(get, never):Bool;
    inline function get_isNull() return toInt32() == 0;

    public function toBytes(count:Int):haxe.io.Bytes {
        var out = haxe.io.Bytes.alloc(count);
        var heapu8 = LuaNative.wasm.HEAPU8;
        for (i in 0...count) {
            out.set(i, heapu8[toInt32() + i]);
        }
        return out;
    }

    public static function fromBytes(bytes:haxe.io.Bytes):NativePtr {
        var alloc = LuaNative.wasm._malloc(bytes.length);
        for (i in 0...bytes.length) {
            LuaNative.wasm.HEAPU8[alloc+i] = bytes.get(i);
        }
        return alloc;
    }

    public function free() {
        LuaNative.wasm._free(this);
    }

    public static inline function fromAddress(addr:NativeUInt):NativePtr {
        return addr;
    }

    @:arrayAccess
    public inline function getUI8(pos:Int):Int {
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
    public inline function setUI8(pos:Int, value:Int) {
        return LuaNative.wasm.HEAPU8[toInt32() + pos] = value;
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

    public function offset(delta:Int):NativePtr {
        return address() + NativeUInt.ofInt(delta);
    }

    public inline function address():NativeUInt return this;
}
#else
typedef NativePtr = hl.Bytes;
#end