package luavm.util;

import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class ClassWrapperMacros {
    #if macro
    static var typeWrappers:Map<String, TypeDefinition> = [];

    static function luaIndexClassField(field:ClassField, cases:Array<Case>) {
        if (field.meta.has(":luaHide")) return;

        switch (field.kind) {
            case FVar(AccNormal|AccCall, _):
                var nm = field.name;
                var caseValue = macro $v{field.name};
                var fieldExpr = macro self.$nm;
                
                var caseExpr = switch (field.type) {
                    case TAbstract(atr, []):
                        switch (atr.toString()) {
                            case "Int": macro luavm.Lua.pushinteger(L, $e{fieldExpr});
                            case "Float": macro luavm.Lua.pushnumber(L, $e{fieldExpr});
                            case "Single": macro luavm.Lua.pushnumber(L, $e{fieldExpr});
                            default: Context.fatalError('ClassWrapper does not support $atr type for a class field.', Context.currentPos());
                        }
                    
                    case TInst(tr, params):
                        switch (tr.toString()) {
                            case "String": macro luavm.Lua.pushstring(L, $e{fieldExpr});
                            default: macro luavm.util.ClassWrapper.push(L, $e{fieldExpr});
                            // default: Context.fatalError('LuaClassWrapper does not support $tr type for a class field.', Context.currentPos());
                        }

                    default: Context.fatalError('ClassWrapper does not support ${field.type} type for a class field.', Context.currentPos());
                };

                cases.push({
                    values: [caseValue],
                    expr: caseExpr
                });

            default:
        }
    }

    static function getTypeWrapper(t:ComplexType) {
        var fullName = ComplexTypeTools.toString(t);

        var typeWrapper = typeWrappers[fullName];
        var typeWrapperClassName = "LuaClassWrapper__" + StringTools.replace(fullName, ".", "_");
        if (typeWrapper == null) {
            var mtName = "hxwrap_" + fullName;

            var indexSwitch = macro switch (key) {
                default: return luavm.Lua.l_error(L, "unknown field " + key);
            };

            switch (indexSwitch.expr) {
                case ESwitch(e, cases, edef):
                    var tResolv = Context.resolveType(t, Context.currentPos());
                    switch (tResolv) {
                        case TInst(ctr, _):
                            var ct = ctr.get();
                            if (!ct.meta.has(":luaExpose"))
                                Context.error('Cannot wrap type $fullName, as it does not have the @:luaExpose metadata.', Context.currentPos());

                            for (field in ct.fields.get()) {
                                luaIndexClassField(field, cases);
                            }

                        default: Context.fatalError("Cannot wrap type " + fullName, Context.currentPos());
                    }

                default:
            }

            // trace(tResolv);
            
            typeWrapper = macro class $typeWrapperClassName {
                static var wrapped:Map<Int, $t> = [];
                static var nextId = 1;
                static final MT_NAME = $v{mtName};

                static function luaGc(L:luavm.State):Int {
                    var udPtr = luavm.Lua.l_checkudata(L, 1, MT_NAME);
                    var id = udPtr.getI32(0);
                    wrapped.remove(id);
                    return 0;
                }

                static function luaIndex(L:luavm.State):Int {
                    var udPtr = luavm.Lua.l_checkudata(L, 1, MT_NAME);
                    var id = udPtr.getI32(0);
                    var self = wrapped[id];
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{indexSwitch};

                    return 1;
                }

                static function luaNewIndex(L:luavm.State):Int {
                    var udPtr = luavm.Lua.l_checkudata(L, 1, MT_NAME);
                    var id = udPtr.getI32(0);
                    var self = wrapped[id];
                    
                    return 0;
                }

                static function init(L:luavm.State) {
                    luavm.Lua.l_newmetatable(L, MT_NAME);

                    luavm.FuncHelper.push(L, luaGc);
                    luavm.Lua.setfield(L, -2, "__gc");

                    luavm.FuncHelper.push(L, luaIndex);
                    luavm.Lua.setfield(L, -2, "__index");

                    luavm.FuncHelper.push(L, luaNewIndex);
                    luavm.Lua.setfield(L, -2, "__newindex");
                }

                public static function push(L:luavm.State, v:$t) {
                    var udPtr = luavm.LuaNative.lua_newuserdatauv(L, 4, 1);
                    udPtr.setI32(0, nextId);
                    wrapped[nextId] = v;
                    nextId++;

                    if (luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, MT_NAME) == cast luavm.LuaType.TNil)
                        init(L);
                    
                    luavm.Lua.setmetatable(L, -2);
                }
            }

            Context.onTypeNotFound((s) -> {
                if (typeWrapperClassName == s) {
                    return typeWrapper;
                }

                return null;
            });

            typeWrappers[fullName] = typeWrapper;
        }

        return typeWrapperClassName;


        // switch (Context.getType("LuaClassWrapper")) {
        //     case TInst(t, params):
        //         var typeName = t.toString();
        //         var classWrapperT = t.get();
        //         var fields = classWrapperT.fields.get();

        //         var t = macro class {
        //             static function testFunc() {
        //                 trace("a");
        //             }
        //         }
        //         trace(t);

        //         haxe.macro.Report

        //         fields.push(t.fields[0]);

        //         // for (f in fields) {
        //         //     if (f.name == "init") {
        //         //         switch (f.expr().expr) {
        //         //             case TFunction({args:_, t:_, expr: {expr:TBlock(el), pos:_, t:_}}):
        //         //                 el.push(Context.typeExpr(macro trace("test")));
        //         //                 trace("Push!!");
        //         //                 trace(el);
        //         //                 // trace();
        //         //                 // trace(el.length);

        //         //             default: Context.fatalError("switch not satisfied", Context.currentPos());
        //         //         }
        //         //         // switch (f.expr().expr) {

        //         //         //     default:
        //         //         // }
        //         //     }
        //         // }

        //         // fields.push({
        //         //     name: "_name_" + t.toString(),
        //         //     type: Context.getType("String"),
        //         //     kind: FVar(AccNormal, AccNormal),

        //         //     isPublic: false,
        //         //     isExtern: false,
        //         //     isAbstract: false,
        //         //     isFinal: false,
        //         //     params: [],
        //         //     meta: null,

        //         //     overloads: null,
        //         //     doc: null,
        //         //     // expr: 
                    
        //         //     pos: classWrapperT.pos,
        //         // });

        //     default: Context.fatalError("could not find class LuaClassWrapper?", Context.currentPos());
        // }
    }

    public static function pushObjectWrapper(L:Expr, v:Expr):Expr {
        var argType = Context.follow(Context.typeof(v));
        var wrapper:String = getTypeWrapper(TypeTools.toComplexType(argType));
        return macro $i{wrapper}.push($L, $v);
    }
    #end

    // public static macro function initLuaClassWrappers():Void {
    //     Context.onAfterTyping((types) -> {
    //         trace("AAA");
    //         for (v in types) trace(v);
    //     });
    // }
}