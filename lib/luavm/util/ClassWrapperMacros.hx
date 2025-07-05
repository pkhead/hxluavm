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

    static function getFieldName(field:ClassField) {
        return if (field.meta.has(":luaName")) {
            switch (field.meta.extract(":luaName")[0].params[0].expr) {
                case EConst(CString(s, DoubleQuotes)):
                    s;

                default: Context.error("@:luaName must have a literal string as the first parameter.", Context.currentPos());
            }
        } else {
            field.name;
        }
    }

    static function luaIndexClassField(classPos:Position, objIdent:Expr, isStatic:Bool, field:ClassField, cases:Array<Case>, regName:String, initExprs:Array<Expr>) {
        if (field.meta.has(":luaHide")) return;
        var fieldName = field.name;
        var luaFieldName = getFieldName(field);
        var caseValue = macro $v{luaFieldName};

        switch (field.kind) {
            case FVar(AccNormal|AccCall, _) if (field.isPublic || field.meta.has(":luaExpose")):
                var fieldExpr = macro @:privateAccess $objIdent.$fieldName;

                function parse(t:Type) {
                    return switch (t) {
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
                            
                        // ???
                        case TLazy(f):
                            parse(f());

                        case v: typeErr(TypeTools.toString(v));
                    };
                }

                var caseExpr = parse(field.type);

                cases.push({
                    values: [caseValue],
                    expr: caseExpr
                });
            
            case FMethod(k):
                if (field.meta.has(":luaFunc")) {
                    if (isStatic) {
                        initExprs.push(macro {
                            luavm.util.FuncHelper.push(L, @:privateAccess $objIdent.$fieldName);
                            luavm.Lua.setfield(L, -2, $v{luaFieldName});
                        });
                    } else {
                        initExprs.push(macro {
                            luavm.util.FuncHelper.push(L, (L) -> {
                                var self = getObject(L, 1);
                                return @:privateAccess $objIdent.$fieldName(L);
                            });
                            luavm.Lua.setfield(L, -2, $v{luaFieldName});
                        });
                    }

                    var caseExpr = macro {
                        luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{regName});
                        luavm.Lua.getfield(L, -1, $v{luaFieldName});
                    }

                    cases.push({
                        values: [caseValue],
                        expr: caseExpr
                    });
                }
            default:
        }
    }

    static function luaNewIndexClassField(classPos:Position, objIdent:Expr, isStatic:Bool, field:ClassField, cases:Array<Case>) {
        if (field.meta.has(":luaHide")) return;
        var fieldName = field.name;
        var caseValue = macro $v{getFieldName(field)};

        switch (field.kind) {
            case FVar(_, AccNormal|AccCall) if (!field.isFinal && (field.isPublic || field.meta.has(":luaExpose"))):
                var fieldExpr = macro @:privateAccess $objIdent.$fieldName;

                function parse(t:Type):Expr {
                    return switch (t) {
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
                        
                        case TLazy(f):
                            parse(f());

                        case v: typeErr(TypeTools.toString(v));
                        // case v: macro null;
                    };
                }
                
                var caseExpr = parse(field.type);

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
            // trace("getTypeWrapper " + fullName);
            // temp
            // typeWrappers[fullName] = macro class {}

            var mtName = fullName;
            var classDataName = "hxwrap_static_" + fullName;
            var initExprs:Array<Expr> = [];

            var indexSwitch = macro switch (key) {
                default: return luavm.Lua.l_error(L, "could not get " + key);
            };

            var newIndexSwitch = macro switch (key) {
                default: return luavm.Lua.l_error(L, "could not set " + key);
            };

            var staticIndexSwitch = macro switch (key) {
                default: return luavm.Lua.l_error(L, "could not get " + key);
            };

            var staticNewIndexSwitch = macro switch (key) {
                default: return luavm.Lua.l_error(L, "could not set " + key);
            };

            var indexCases:Array<Case>;
            var newIndexCases:Array<Case>;
            var staticIndexCases:Array<Case>;
            var staticNewIndexCases:Array<Case>;

            switch (indexSwitch.expr) {
                case ESwitch(_, cases, _):
                    indexCases = cases;
                default:
            }

            switch (newIndexSwitch.expr) {
                case ESwitch(_, cases, _):
                    newIndexCases = cases;
                default:
            }

            switch (staticIndexSwitch.expr) {
                case ESwitch(_, cases, _):
                    staticIndexCases = cases;
                default:
            }

            switch (staticNewIndexSwitch.expr) {
                case ESwitch(_, cases, _):
                    staticNewIndexCases = cases;
                default:
            }
            
            var tResolv = Context.resolveType(t, Context.currentPos());
            switch (tResolv) {
                case TInst(ctr, _):
                    var ct = ctr.get();
                    if (!ct.meta.has(":luaExpose"))
                        Context.error('Cannot wrap type $fullName, as it does not have the @:luaExpose metadata.', Context.currentPos());
                    
                    // init static fields
                    for (field in ct.statics.get()) {
                        var id = macro $p{fullName.split(".")};
                        luaIndexClassField(ct.pos, id, true, field, staticIndexCases, classDataName, initExprs);
                        luaNewIndexClassField(ct.pos, id, true, field, staticNewIndexCases);
                    }

                    for (field in ct.fields.get()) {
                        var id = macro $i{"self"};
                        // trace(field.name);
                        // trace(field.type);
                        luaIndexClassField(ct.pos, id, false, field, indexCases, classDataName, initExprs);
                        luaNewIndexClassField(ct.pos, id, false, field, newIndexCases);
                    }

                default: Context.fatalError("Cannot wrap type " + fullName, Context.currentPos());
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

                static function luaStaticIndex(L:luavm.State):Int {
                    // var self = getObject(L, 1);
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{staticIndexSwitch};

                    return 1;
                }

                static function luaStaticNewIndex(L:luavm.State):Int {
                    // var self = getObject(L, 1);
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{staticNewIndexSwitch};

                    return 1;
                }

                static function luaMetatable(L:luavm.State):Int {
                    luavm.Lua.pushstring(L, "metatable is locked");
                    return 1;
                }

                static function init(L:luavm.State) {
                    // create static class table
                    luavm.Lua.createtable(L, 0, 0);

                    // method functions will be stored in the static class table
                    $b{initExprs};

                    // metatable for static fields
                    luavm.Lua.createtable(L, 0, 0);
                    luavm.util.FuncHelper.push(L, luaStaticIndex);
                    luavm.Lua.setfield(L, -2, "__index");

                    luavm.util.FuncHelper.push(L, luaStaticNewIndex);
                    luavm.Lua.setfield(L, -2, "__newindex");

                    luavm.util.FuncHelper.push(L, luaMetatable);
                    luavm.Lua.setfield(L, -2, "__metatable");

                    luavm.Lua.setmetatable(L, -2);

                    // store the static class table to the registry
                    luavm.Lua.setfield(L, luavm.Lua.REGISTRYINDEX, $v{classDataName});

                    // create the class metatable
                    luavm.Lua.l_newmetatable(L, $v{mtName});

                    luavm.util.FuncHelper.push(L, luaGc);
                    luavm.Lua.setfield(L, -2, "__gc");

                    luavm.util.FuncHelper.push(L, luaIndex);
                    luavm.Lua.setfield(L, -2, "__index");

                    luavm.util.FuncHelper.push(L, luaNewIndex);
                    luavm.Lua.setfield(L, -2, "__newindex");

                    luavm.util.FuncHelper.push(L, luaMetatable);
                    luavm.Lua.setfield(L, -2, "__metatable");
                }

                static function getOrInitMetatable(L:luavm.State) {
                    if (luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{mtName}) == cast luavm.LuaType.TNil) {
                        luavm.Lua.pop(L, 1);
                        init(L);
                    }
                }

                public static function push(L:luavm.State, v:$t) {
                    var cache = wrapCache[v];
                    if (cache != null) {
                        luavm.Lua.rawgeti(L, luavm.Lua.REGISTRYINDEX, cache);
                    } else {
                        var udPtr = luavm.LuaNative.lua_newuserdatauv(L, 4, 1);
                        udPtr.setI32(0, nextId);
                        wrapIDs[nextId] = v;
                        
                        getOrInitMetatable(L);
                        luavm.Lua.setmetatable(L, -2);

                        luavm.Lua.pushvalue(L, -1);
                        wrapCache[v] = luavm.Lua.l_ref(L, luavm.Lua.REGISTRYINDEX);
                        nextId++;
                    }
                }

                public static function pushStatic(L:luavm.State) {
                    getOrInitMetatable(L);
                    luavm.Lua.pop(L, 1);
                    luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{classDataName});
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
        var wrapper = getTypeWrapper(TypeTools.toComplexType(argType));
        return macro $i{wrapper}.push($L, $v);
    }

    public static function pushObjectClass(L:Expr, t:Expr):Expr {
        var tType = Context.typeof(t);
        switch (tType) {
            case TType(tr, params):
                var t = tr.get();
                var nm = t.name;

                // idk how else to do this
                // name is "Class<T>", check that it is in that format and extract the T string
                if (nm.substr(0, 6) == "Class<" && nm.substring(nm.length-1) == ">") {
                    var typeName = nm.substring(6, nm.length - 1);
                    var wrapper = getTypeWrapper(TypeTools.toComplexType(Context.getType(typeName)));
                    return macro $i{wrapper}.pushStatic($L);
                }

            default:
        }

        Context.error("expected Class<T> type, got " + TypeTools.toString(tType), Context.currentPos());
        return macro null;
    }
    #end
}