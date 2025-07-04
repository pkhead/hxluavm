import haxe.macro.Context;

class Macros {
    public static macro function getLuaSource():Expr<String> {
        var path = "code.lua";
        Context.registerModuleDependency("Macros", path);
        var str:String = sys.io.File.getContent(path);
        return macro $v{str};
    }
}