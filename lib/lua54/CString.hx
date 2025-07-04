package lua54;

abstract CString(hl.Bytes) from hl.Bytes to hl.Bytes {
    inline function new(ptr:hl.Bytes) {
        this = ptr;
    }

    private inline static function readCStr(bytes:hl.Bytes):haxe.io.Bytes {
        var len = 0;
        while (bytes[len] != 0) len++;
        return bytes.toBytes(len);
    }

    @:from static inline function fromString(s:String) {
        return new CString(hl.Bytes.fromBytes(haxe.io.Bytes.ofString(s)));
    }

    @:to function toString():String {
        return readCStr(this).toString();
    }

    public var bytes(get, never):hl.Bytes;
    inline function get_bytes() return this;
}