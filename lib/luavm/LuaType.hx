package luavm;

enum abstract LuaType(Int) from Int to Int {
	var TNone = -1;
	var TNil = 0;
	var TBoolean = 1;
	var TLightUserData = 2;
	var TNumber = 3;
	var TString = 4;
	var TTable = 5;
	var TFunction = 6;
	var TUserdata = 7;
	var TThread = 8;

	@:to inline function toInt():Int {
        return this;
    }
}