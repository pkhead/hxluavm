package luavm.util;

import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class ClassWrapperMacros {
    #if macro
    static var typeWrappers:Map<String, TypeDefinition> = [];

    static function typeErr(typeName:String):Dynamic {
        return Context.fatalError('ClassWrapper does not support $typeName type for a class field.', Context.currentPos());
    }

    static function fieldGetPrim(fieldExpr:Expr, atrStr:String):Expr {
        return switch (atrStr) {
            case "Int": macro luavm.Lua.pushinteger(L, $e{fieldExpr});
            case "Float": macro luavm.Lua.pushnumber(L, $e{fieldExpr});
            case "Single": macro luavm.Lua.pushnumber(L, $e{fieldExpr});
            case "Bool": macro luavm.Lua.pushboolean(L, $e{fieldExpr} ? 1 : 0);
            default: typeErr(atrStr);
        }
    }

    static function fieldSetPrim(fieldExpr:Expr, atrStr:String):Expr {
        return switch (atrStr) {
            case "Int": macro $e{fieldExpr} = luavm.Lua.l_checkinteger(L, 3);
            case "Float" | "Single": macro $e{fieldExpr} = luavm.Lua.l_checknumber(L, 3);
            case "Bool": macro $e{fieldExpr} = luavm.Lua.l_toboolean(L, 3) != 0;
            default: typeErr(atrStr);
        }
    }

    static function luaIndexClassField(field:ClassField, cases:Array<Case>, regName:String, initExprs:Array<Expr>) {
        if (field.meta.has(":luaHide")) return;
        var fieldName = field.name;
        var caseValue = macro $v{fieldName};

        switch (field.kind) {
            case FVar(AccNormal|AccCall, _):
                var fieldExpr = macro self.$fieldName;

                var caseExpr = switch (field.type) {
                    case TAbstract(atr, params):
                        var atrStr = atr.toString();

                        if (atrStr == "Null" && params.length == 1) {
                            macro if ($e{fieldExpr} == null) {
                                luavm.Lua.pushnil(L);
                            } else {
                                $e{fieldGetPrim(fieldExpr, TypeTools.toString(params[0]))};
                            }
                        }
                        #if target.static
                        else if (params.length == 0) {
                            fieldGetPrim(fieldExpr, atrStr);
                        } else {
                            typeErr(atrStr);
                        }
                        #else
                        else if (params.length == 0) {
                            macro if ($e{fieldExpr} == null) {
                                luavm.Lua.pushnil(L);
                            } else {
                                $e{fieldGetPrim(fieldExpr, atrStr)};
                            }
                        } else {
                            typeErr(atrStr);
                        }
                        #end
                        // macro luavm.Lua.pushnil(L);
                    
                    case TInst(tr, params):
                        macro {
                            if ($e{fieldExpr} == null) {
                                luavm.Lua.pushnil(L);
                            } else {
                                $e{switch (tr.toString()) {
                                    case "String": macro luavm.Lua.pushstring(L, $e{fieldExpr});
                                    default: macro luavm.util.ClassWrapper.push(L, $e{fieldExpr});
                                    // default: Context.fatalError('LuaClassWrapper does not support $tr type for a class field.', Context.currentPos());
                                }}
                            }
                        }                    

                    case v: typeErr(TypeTools.toString(v));
                };

                cases.push({
                    values: [caseValue],
                    expr: caseExpr
                });
            
            case FMethod(k):
                if (field.meta.has(":luaFunc")) {
                    var funcKeyName = "fun_" + fieldName;

                    initExprs.push(macro {
                        luavm.FuncHelper.push(L, (L) -> {
                            var self = getObject(L, 1);
                            return @:privateAccess self.$fieldName(L);
                        });
                        luavm.Lua.setfield(L, -2, $v{funcKeyName});
                    });

                    var caseExpr = macro {
                        luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{regName});
                        luavm.Lua.getfield(L, -1, $v{funcKeyName});
                    }

                    cases.push({
                        values: [caseValue],
                        expr: caseExpr
                    });
                }
            default:
        }
    }

    static function luaNewIndexClassField(field:ClassField, cases:Array<Case>) {
        if (field.meta.has(":luaHide")) return;
        var fieldName = field.name;
        var caseValue = macro $v{fieldName};

        switch (field.kind) {
            case FVar(_, AccNormal|AccCall):
                var fieldExpr = macro self.$fieldName;
                
                var caseExpr = switch (field.type) {
                    case TAbstract(atr, params):
                        var atrStr = atr.toString();

                        if (atrStr == "Null" && params.length == 1) {
                            macro if (luavm.Lua.isnoneornil(L, 3)) {
                                $e{fieldExpr} = null;
                            } else {
                                $e{fieldSetPrim(fieldExpr, TypeTools.toString(params[0]))}
                            }
                        } else if (params.length == 0) {
                            fieldSetPrim(fieldExpr, atrStr);
                        } else {
                            typeErr(atrStr);
                        }
                    
                    case TInst(tr, params):
                        macro {
                            if (luavm.Lua.isnoneornil(L, 3)) {
                                $e{fieldExpr} = null;
                            } else {
                                $e{switch (tr.toString()) {
                                    case "String": macro $e{fieldExpr} = luavm.Lua.l_checkstring(L, 3);
                                    default:
                                        var complexType = TypeTools.toComplexType(
                                            TInst(tr, params)
                                        );
                                        var className = getTypeWrapper(complexType);

                                        macro {
                                            var v = $i{className}.getObject(L, 3);
                                            if (v == null) {
                                                return luavm.Lua.l_error(L, "internal error: invalid object");
                                            }
                                            $e{fieldExpr} = v;
                                        }
                                }}
                            }
                        }

                    case v: typeErr(TypeTools.toString(v));
                };

                cases.push({
                    values: [caseValue],
                    expr: caseExpr
                });
            
            default:
        }
    }

    static function getTypeWrapperClassName(t:ComplexType) {
        var fullName = ComplexTypeTools.toString(t);
        return "LuaClassWrapper__" + StringTools.replace(fullName, ".", "_");
    }

    static function getTypeWrapper(t:ComplexType) {
        var fullName = ComplexTypeTools.toString(t);

        var typeWrapper = typeWrappers[fullName];
        var typeWrapperClassName = getTypeWrapperClassName(t);
        if (typeWrapper == null) {
            var mtName = fullName;
            var classDataName = "hxwrap_dt_" + fullName;
            
            var initExprs:Array<Expr> = [];

            var indexSwitch = macro switch (key) {
                default: return luavm.Lua.l_error(L, "could not get " + key);
            };

            var newIndexSwitch = macro switch (key) {
                default: return luavm.Lua.l_error(L, "could not set " + key);
            };

            switch (indexSwitch.expr) {
                case ESwitch(_, indexCases, _):
                    switch (newIndexSwitch.expr) {
                        case ESwitch(_, newIndexCases, _):
                            var tResolv = Context.resolveType(t, Context.currentPos());
                            switch (tResolv) {
                                case TInst(ctr, _):
                                    var ct = ctr.get();
                                    if (!ct.meta.has(":luaExpose"))
                                        Context.error('Cannot wrap type $fullName, as it does not have the @:luaExpose metadata.', Context.currentPos());
        
                                    for (field in ct.fields.get()) {
                                        luaIndexClassField(field, indexCases, classDataName, initExprs);
                                        luaNewIndexClassField(field, newIndexCases);
                                    }
        
                                default: Context.fatalError("Cannot wrap type " + fullName, Context.currentPos());
                            }

                        default:
                    }

                default:
            }
            
            typeWrapper = macro class $typeWrapperClassName {
                static var wrapIDs:Map<Int, $t> = [];
                static var wrapCache:Map<$t, Int> = [];
                static var nextId = 1;

                static function luaGc(L:luavm.State):Int {
                    var udPtr = luavm.Lua.l_checkudata(L, 1, $v{mtName});
                    var id = udPtr.getI32(0);
                    var obj = wrapIDs[id];

                    wrapIDs.remove(id);
                    luavm.Lua.l_unref(L, luavm.Lua.REGISTRYINDEX, wrapCache[obj]);
                    wrapCache.remove(obj);

                    return 0;
                }

                static public function getObject(L:luavm.State, idx:Int) {
                    var udPtr = luavm.Lua.l_checkudata(L, idx, $v{mtName});
                    var id = udPtr.getI32(0);
                    return wrapIDs[id];
                }

                static function luaIndex(L:luavm.State):Int {
                    var self = getObject(L, 1);
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{indexSwitch};

                    return 1;
                }

                static function luaNewIndex(L:luavm.State):Int {
                    var udPtr = luavm.Lua.l_checkudata(L, 1, $v{mtName});
                    var id = udPtr.getI32(0);
                    var self = wrapIDs[id];
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{newIndexSwitch};
                    
                    return 0;
                }

                static function init(L:luavm.State) {
                    luavm.Lua.createtable(L, 0, 0);
                    $b{initExprs};
                    luavm.Lua.setfield(L, luavm.Lua.REGISTRYINDEX, $v{classDataName});

                    luavm.Lua.l_newmetatable(L, $v{mtName});

                    luavm.FuncHelper.push(L, luaGc);
                    luavm.Lua.setfield(L, -2, "__gc");

                    luavm.FuncHelper.push(L, luaIndex);
                    luavm.Lua.setfield(L, -2, "__index");

                    luavm.FuncHelper.push(L, luaNewIndex);
                    luavm.Lua.setfield(L, -2, "__newindex");
                }

                public static function push(L:luavm.State, v:$t) {
                    var cache = wrapCache[v];
                    if (cache != null) {
                        luavm.Lua.rawgeti(L, luavm.Lua.REGISTRYINDEX, cache);
                    } else {
                        var udPtr = luavm.LuaNative.lua_newuserdatauv(L, 4, 1);
                        udPtr.setI32(0, nextId);
                        wrapIDs[nextId] = v;
                        
                        if (luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{mtName}) == cast luavm.LuaType.TNil) {
                            luavm.Lua.pop(L, 1);
                            init(L);
                        }
                        
                        luavm.Lua.setmetatable(L, -2);

                        luavm.Lua.pushvalue(L, -1);
                        wrapCache[v] = luavm.Lua.l_ref(L, luavm.Lua.REGISTRYINDEX);
                        nextId++;
                    }
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
    }

    public static function pushObjectWrapper(L:Expr, v:Expr):Expr {
        var argType = Context.follow(Context.typeof(v));
        var wrapper:String = getTypeWrapper(TypeTools.toComplexType(argType));
        return macro $i{wrapper}.push($L, $v);
    }
    #end
}