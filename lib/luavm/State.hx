package luavm;

#if js
abstract State(NativeUInt) {}
#else
abstract State(hl.Abstract<"lua_State">) {}
#end