package luavm;

#if js
abstract CString(haxe.io.Bytes) {
    @:from public inline function new(bytes:haxe.io.Bytes) {
        this = bytes;
    }

    public static function strLen(bytes:NativePtr, pos:Int):Int {
        var len = 0;
        while (bytes[len+pos] != 0) len++;
        return len;
    }

    @:from static inline function fromString(s:String) {
        return s == null ? null : new CString(haxe.io.Bytes.ofString(s));
    }

    @:to public inline function toBytes():haxe.io.Bytes {
        return this;
    }

    @:to public inline function toString():String {
        return this.toString();
    }
}
#else
abstract CString(hl.Bytes) from hl.Bytes to hl.Bytes {
    inline function new(ptr:hl.Bytes) {
        this = ptr;
    }

    public static function strLen(bytes:hl.Bytes, pos:Int):Int {
        var len = 0;
        while (bytes[len+pos] != 0) len++;
        return len;
    }

    private static inline function readCStr(bytes:hl.Bytes):haxe.io.Bytes {
        return bytes.toBytes(strLen(bytes, 0));
    }

    @:from static inline function fromString(s:String) {
        return s == null ? null : new CString(hl.Bytes.fromBytes(haxe.io.Bytes.ofString(s)));
    }

    @:from static inline function fromBytes(b:haxe.io.Bytes) {
        return b == null ? null : new CString(hl.Bytes.fromBytes(b));
    }

    @:to public inline function toBytes():haxe.io.Bytes {
        return readCStr(this);
    }

    @:to public inline function toString():String {
        return readCStr(this).toString();
    }

    public var hlBytes(get, never):hl.Bytes;
    inline function get_hlBytes() return this;
}
#end