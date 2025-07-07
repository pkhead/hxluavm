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

    public static macro function test() {
        var type = Context.getType("testpkg.LuaStringArray");
        trace(type);
        switch (type) {
            case TAbstract(tRef, params):
                var abst = tRef.get();

                for (f in abst.impl.get().statics.get()) {
                    trace("\t" + f.name);
                    // trace(f);
                    var expr = f.expr();
                    if (expr != null) {
                        // trace(expr);
                        switch (expr.t) {
                            case TFun(args, ret):
                                trace(args);

                            default:
                        }
                    }
                }
                // trace(abst.impl.get().statics.get());

            default:
        }

        return macro null;
    }
}