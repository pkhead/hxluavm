package luavm;

#if js
abstract CString(haxe.io.Bytes) {
    public inline function new(bytes:haxe.io.Bytes) {
        this = bytes;
    }

    @:from static inline function fromString(s:String) {
        return new CString(haxe.io.Bytes.ofString(s));
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

    private static function readCStr(bytes:hl.Bytes):haxe.io.Bytes {
        var len = 0;
        while (bytes[len] != 0) len++;
        return bytes.toBytes(len);
    }

    @:from static inline function fromString(s:String) {
        return new CString(hl.Bytes.fromBytes(haxe.io.Bytes.ofString(s)));
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