import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class Macros {
    public static macro function getLuaSource():ExprOf<String> {
        var path = "code.lua";
        Context.registerModuleDependency("Macros", path);
        var str:String = sys.io.File.getContent(path);
        return macro $v{str};
    }
}