package luavm.util;

import haxe.macro.Compiler;
import haxe.macro.ExprTools;
import haxe.macro.ComplexTypeTools;
import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

typedef FieldParserData = {
    classTypeComplex:ComplexType,
    isAbstract:Bool,
    classPos:Position,
    objIdent:Expr,

    isStatic:Bool,

    regName:String,
    initExprs:Array<Expr>
};

class ClassWrapperMacros {
    #if macro
    static var substitutes:Map<String, String> = [];
    static var typeWrappers:Map<String, TypeDefinition> = [];

    static function isSimpleEnum(t:EnumType) {
        for (name => ctor in t.constructs) {
            if (ctor.type.match(TFun(_, _))) return false;
        }

        return true;
    }

    static function complexTypeToFieldExprArray(t:ComplexType):Array<String> {
        switch (t) {
            case TPath(path):
                var arr = path.pack.copy();
                if (path.sub != null) {
                    arr.push(path.name);
                    arr.push(path.sub);
                } else {
                    arr.push(path.name);
                }
        
                return arr;
            
            default: throw new haxe.Exception("could not convert complex type to field expr");
        }
    }

    static function complexTypeToFieldExpr(t:ComplexType):Expr {
        return macro $p{complexTypeToFieldExprArray(t)};
    }

    static function typeErr(typeName:String, pos:Position):Dynamic {
        throw new haxe.Exception('ClassWrapper does not support the $typeName type.');
        // return Context.error('ClassWrapper does not support the $typeName type.', pos);
    }

    static function isPrimitive(typeStr:String) {
        return switch (typeStr) {
            case "Int" | "Float" | "Single" | "Bool": true;
            default: false;
        }
    }

    // assumes src is in PascalCase or camelCase
    static function convertCasing(src:String, behavior:String):String {
		function splitByCase(src:String) {
			var upper = src.toUpperCase();
			var arr:Array<String> = [];
			var buf = new StringBuf();

			for (i in 0...src.length) {
				var ch = src.charCodeAt(i);
				if (i > 0 && ch == upper.charCodeAt(i) && src.charCodeAt(i - 1) != upper.charCodeAt(i - 1)) {
					arr.push(buf.toString().toLowerCase());
					buf = new StringBuf();
					buf.addChar(ch);
				} else {
					buf.addChar(ch);
				}
			}

			arr.push(buf.toString().toLowerCase());
			return arr;
		}

        return switch (behavior) {
            case "pascal":
                if (src.length <= 1) {
                    src.toUpperCase();
                } else {
                    src.substr(0, 1).toUpperCase() + src.substr(1);
                }

            case "camel":
                if (src.length <= 1) {
                    src.toLowerCase();
                } else {
                    src.substr(0, 1).toLowerCase() + src.substr(1);
                }

            case "kebab":
                StringTools.replace(splitByCase(src).join("-"), "_", "-");
            
            case "snake":
                splitByCase(src).join("_");

            case "flat":
                src.toLowerCase();

            default: Context.fatalError("Invalid casing rule " + behavior, Context.currentPos());
            // default: throw new haxe.Exception("invalid casing rule " + behavior);
        }
    }

    static function luaPushValue(type:Type, value:Expr):Expr {
        function pushPrimitive(typeString:String, v:Expr) {
            return switch (typeString) {
                case "Int": macro luavm.Lua.pushinteger(L, $e{v});
                case "Float": macro luavm.Lua.pushnumber(L, $e{v});
                case "Single": macro luavm.Lua.pushnumber(L, $e{v});
                case "Bool": macro luavm.Lua.pushboolean(L, $e{v});
                default: typeErr(typeString, Context.currentPos());
            }
        }

        function pushNonPrimitive(type:Type, v:Expr):Expr {
            #if target.static
            var realType = Context.followWithAbstracts(type);
            if (isPrimitive(TypeTools.toString(realType))) {
                return macro luavm.util.ClassWrapper.pushObject(L, $v);
            }
            #end

            switch (type) {
                case TEnum(enumTypeRef, params):
                    var enumBehavior = Context.definedValue("luawrap-enums");
                    if (enumBehavior == null) {
                        return Context.error(
                            'Cannot wrap type ${TypeTools.toString(type)}, as luawrap-enums is not defined.',
                            enumTypeRef.get().pos
                        );
                    } else {
                        var enumType = enumTypeRef.get();

                        if (!isSimpleEnum(enumType)) {
                            Context.error(
                                'Cannot wrap type ${TypeTools.toString(type)}, as it has one or more parameterized constructors.',
                                enumType.pos
                            );
                        }

                        return switch ((enumBehavior : String)) {
                            case "int0":
                                macro luavm.Lua.pushinteger(L, Type.enumIndex($v));

                            case "int1":
                                macro luavm.Lua.pushinteger(L, Type.enumIndex($v) + 1);

                            default:
                                var convertCases:Array<Case> = [
                                    for (name in enumType.names) {
                                        {
                                            values: [macro $i{name}],
                                            expr: macro luavm.Lua.pushstring(L, $v{convertCasing(name, enumBehavior)})
                                        }
                                    }
                                ];

                                {
                                    pos: Context.currentPos(),
                                    expr: ESwitch(value, convertCases, null)
                                }
                        }
                    }
                
                default:
                    return macro {
                        var tmp = $e{v};
                        if (tmp == null) {
                            luavm.Lua.pushnil(L);
                        } else {
                            $e{switch (TypeTools.toString(type)) {
                                case "String": macro luavm.Lua.pushstring(L, tmp);
                                default: macro luavm.util.ClassWrapper.pushObject(L, tmp);
                            }}
                        }
                    }
            }
        }

        function parse(typeArg:Type) {
            return switch (typeArg) {
                case TAbstract(atr, params):
                    var atrStr = atr.toString();

                    if (atrStr == "Null") {
                        var tstr = TypeTools.toString(params[0]);
                        if (isPrimitive(tstr)) {
                            macro {
                                var tmp = $e{value};
                                if (tmp == nul) {
                                    luavm.Lua.pushnil(L);
                                } else {
                                    $e{pushPrimitive(TypeTools.toString(params[0]), macro $i{"tmp"})};
                                }
                            }
                        } else {
                            pushNonPrimitive(params[0], value);
                        }
                    } else if (isPrimitive(atrStr)) {
                        #if target.static
                        pushPrimitive(atrStr, value);
                        #else
                        macro {
                            var tmp = $e{value};
                            if (tmp == null) {
                                luavm.Lua.pushnil(L);
                            } else {
                                $e{pushPrimitive(atrStr, macro $i{"tmp"})};
                            }
                        }
                        #end
                    } else {
                        pushNonPrimitive(typeArg, value);
                    }
                
                case TInst(tr, params):
                    pushNonPrimitive(typeArg, value);
                
                case TEnum(_, _):
                    pushNonPrimitive(typeArg, value);

                case v: typeErr(TypeTools.toString(v), Context.currentPos());
            };
        }

        return parse(TypeTools.follow(type));
    }

    static function luaGetValue(desiredType:Type, stackIndex:Expr):Expr {
        function getPrimitive(typeString:String):Expr {
            return switch (typeString) {
                case "Int": macro luavm.Lua.l_checkinteger(L, $stackIndex);
                case "Float" | "Single": macro luavm.Lua.l_checknumber(L, $stackIndex);
                case "Bool": macro luavm.Lua.toboolean(L, $stackIndex);
                case v: typeErr(v, Context.currentPos());
            }
        }

        function getNonPrimitive(type:Type):Expr {
            #if target.static
            var realType = Context.followWithAbstracts(type);
            if (isPrimitive(TypeTools.toString(realType))) {
                var complexType = TypeTools.toComplexType(type);
                var className = getTypeWrapper(complexType);

                return macro $i{className}.getObject(L, $stackIndex);
            }
            #end

            switch (type) {
                case TEnum(enumTypeRef, params):
                    var enumBehavior = Context.definedValue("luawrap-enums");
                    if (enumBehavior == null) {
                        return Context.error(
                            'Cannot wrap type ${TypeTools.toString(type)}, as luawrap-enums is not defined.',
                            enumTypeRef.get().pos
                        );
                    } else {
                        var enumType = enumTypeRef.get();

                        if (!isSimpleEnum(enumType)) {
                            Context.error(
                                'Cannot wrap type ${TypeTools.toString(type)}, as it has one or more parameterized constructors.',
                                enumType.pos
                            );
                        }

                        var eTypeArr = complexTypeToFieldExprArray(TypeTools.toComplexType(desiredType));
                        var eType = macro $p{eTypeArr};
                        return switch ((enumBehavior : String)) {
                            case "int0":
                                macro Type.createEnumIndex($eType, luavm.Lua.l_checkinteger(L, $stackIndex));
                                
                            case "int1":
                                macro Type.createEnumIndex($eType, luavm.Lua.l_checkinteger(L, $stackIndex) - 1);

                            default:
                                var convertCases:Array<Case> = [
                                    for (name in enumType.names) {
                                        var fields = eTypeArr.copy();
                                        fields.push(name);
                                        {
                                            values: [macro $v{convertCasing(name, enumBehavior)}],
                                            expr: macro $p{fields}
                                        }
                                    }
                                ];

                                convertCases.push({
                                    values: [macro v],
                                    expr: macro return luavm.Lua.l_argerror(
                                        L,
                                        $stackIndex,
                                        'invalid value \'$v\'. expected values: ' + $v{enumType.names.map(convertCasing.bind(_, enumBehavior)).join(", ")}
                                    )
                                });

                                {
                                    pos: Context.currentPos(),
                                    expr: ESwitch(macro luavm.Lua.l_checkstring(L, $stackIndex), convertCases, null)
                                }
                        }
                    }

                default: return macro {
                    if (luavm.Lua.isnoneornil(L, $stackIndex)) {
                        null;
                    } else {
                        $e{switch (TypeTools.toString(type)) {
                            case "String": macro luavm.Lua.l_checkstring(L, $stackIndex);
                            default:
                                var complexType = TypeTools.toComplexType(
                                    // TInst(type, params)
                                    type
                                );
                                var className = getTypeWrapper(complexType);
        
                                macro $i{className}.getObject(L, $stackIndex);
                        }}
                    }
                }
            }
        }

        // var realType = TypeTools.follow(desiredType);
        var realType = desiredType;
        function parse(type:Type) {
            return switch (type) {
                case TAbstract(atr, params):
                    var atrStr = atr.toString();
    
                    if (atrStr == "Null") {
                        if (isPrimitive(TypeTools.toString(params[0]))) {
                            macro if (luavm.Lua.isnoneornil(L, $stackIndex)) {
                                null;
                            } else {
                                $e{getPrimitive(TypeTools.toString(params[0]))}
                            }
                        } else {
                            getNonPrimitive(params[0]);
                        }
                    } else if (isPrimitive(atrStr)) {
                        getPrimitive(atrStr);
                    } else {
                        getNonPrimitive(type);
                    }
                
                case TInst(tr, params):
                    getNonPrimitive(type);

                case TEnum(_, _):
                    getNonPrimitive(type);

                case TLazy(f): parse(f());
    
                case v: typeErr(TypeTools.toString(v), Context.currentPos());
            }
        }

        return parse(realType);
    }

    static function getFieldName(field:ClassField, ?defaultName:String) {
        return if (field.meta.has(":luaName")) {
            switch (field.meta.extract(":luaName")[0].params[0].expr) {
                case EConst(CString(s, DoubleQuotes)):
                    s;

                default: Context.error("@:luaName must have a literal string as the first parameter.", field.pos);
            }
        } else {
            defaultName ?? field.name;
        }
    }

    static function luaIndexClassField(field:ClassField, cases:Array<Case>, setup:FieldParserData) {
        if (field.meta.has(":luaHide")) return;
        var fieldName = field.name;
        // trace('INDEX FIELD\t\t${field.name}: ${TypeTools.toString(field.type)}');

        if (setup.isAbstract && fieldName == "_new")
            fieldName = "new";
        
        var luaFieldName = getFieldName(field, fieldName);
        var caseValue = macro $v{luaFieldName};

        var classPos = setup.classPos;
        var objIdent = setup.objIdent;
        var isStatic = setup.isStatic;
        var regName = setup.regName;
        var initExprs = setup.initExprs;

        if (!(field.isPublic || field.meta.has(":luaExpose"))) return;

        var caseExpr = switch (field.kind) {
            case FVar(AccNormal|AccCall, _):
                var fieldExpr = macro $objIdent.$fieldName;
                
                // report this
                luaPushValue(field.type, fieldExpr);
            
            case FMethod(k):
                var fieldType = field.expr().t;
                var funcDef:Array<Expr> = null;
                switch (fieldType) {
                    case TFun(args, ret):
                        var stackIndex = 1;
                        funcDef = [];

                        var isInstance = !isStatic;
                        var callTarget = objIdent;
                        var argStart = 0;

                        // for abstracts
                        if (setup.isAbstract && args.length > 0 && args[0].name == "this") {
                            isInstance = true;
                            callTarget = macro $i{"self"};
                            argStart = 1;
                        }

                        if (isInstance) {
                            funcDef.push(macro var self = getObject(L, $v{stackIndex++}));
                        }

                        var callArgs:Array<Expr> = [];
                        for (i in argStart...args.length) {
                            var arg = args[i];
                            if (i > 0 && args[i-1].opt && !arg.opt) {
                                Context.error("Lua: all optional arguments must be at the end", field.pos);
                            }

                            var varName = "__" + arg.name;
                            funcDef.push(macro var $varName = $e{luaGetValue(arg.t, macro $v{stackIndex++})});
                            callArgs.push(macro $i{varName});
                        }

                        if (fieldName == "new") {
                            switch (setup.classTypeComplex) {
                                case TPath(p):
                                    var callExpr = macro new $p($a{callArgs});
                                    funcDef.push(luaPushValue(ComplexTypeTools.toType(setup.classTypeComplex), callExpr));
                                    funcDef.push(macro return 1);

                                default:
                                    Context.error("internal error: classTypeComplex is not a TPath?", Context.currentPos());
                            }
                        } else {
                            var callExpr = macro $callTarget.$fieldName($a{callArgs});
                            if (TypeTools.toString(ret) == "Void") {
                                var callExpr = macro $callTarget.$fieldName($a{callArgs});
                                funcDef.push(callExpr);
                                funcDef.push(macro return 0);
                            } else {
                                funcDef.push(luaPushValue(ret, callExpr));
                                funcDef.push(macro return 1);
                            }
                        }

                        // trace("\n" + [for (v in funcDef) ExprTools.toString(v)].join("\n"));
                    
                    default: Context.error("Could not parse this method", field.pos);
                }

                initExprs.push(macro {
                    luavm.util.FuncHelper.push(L, (L) -> {
                        $b{funcDef}
                    });
                    luavm.Lua.setfield(L, -2, $v{luaFieldName});
                });

                // report this
                macro {
                    luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{regName});
                    luavm.Lua.getfield(L, -1, $v{luaFieldName});
                }
            
            default: null;
        }

        if (caseExpr != null) {
            if (field.meta.has(":luaCatch")) {
                caseExpr = macro try {
                    $e{caseExpr};
                } catch(e) {
                    return luavm.Lua.l_error(L, e.message);
                } 
            }
            
            cases.push({
                values: [caseValue],
                expr: caseExpr
            });
        }
    }

    static function luaNewIndexClassField(field:ClassField, cases:Array<Case>, setup:FieldParserData) {
        if (field.meta.has(":luaHide")) return;
        var fieldName = field.name;
        // trace('NEW INDEX FIELD:\t${field.name}:${TypeTools.toString(field.type)}');

        var caseValue = macro $v{getFieldName(field)};

        var classPos = setup.classPos;
        var objIdent = setup.objIdent;
        var isStatic = setup.isStatic;

        var caseExpr = switch (field.kind) {
            case FVar(_, AccNormal|AccCall) if (!field.isFinal && (field.isPublic || field.meta.has(":luaExpose"))):
                var fieldExpr = macro $objIdent.$fieldName;
                
                // report this value
                macro $e{fieldExpr} = $e{luaGetValue(field.type, macro 3)};
                
            default: null;
        }

        if (caseExpr != null) {
            if (field.meta.has(":luaCatch")) {
                caseExpr = macro try {
                    $e{caseExpr};
                } catch(e) {
                    return luavm.Lua.l_error(L, e.message);
                } 
            }

            cases.push({
                values: [caseValue],
                expr: caseExpr
            });
        }
    }

    public static function getTypeWrapper(t:ComplexType) {
        var fullName = ComplexTypeTools.toString(t);
        {
            var subStr = substitutes[fullName];
            if (subStr != null) {
                t = TypeTools.toComplexType(Context.getType(subStr));
                fullName = subStr;
            }
        }

        var typeWrapper = typeWrappers[fullName];
        var typeWrapperClassName = "LuaClassWrapper__" + StringTools.replace(fullName, ".", "_");
        
        if (typeWrapper == null) {
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
            var actualType = t;
            var data:FieldParserData = {
                classTypeComplex: t,
                isAbstract: false,
                classPos: null,
                objIdent: null,
                isStatic: true,
                regName: classDataName,
                initExprs: initExprs
            };
            
            switch (tResolv) {
                case TInst(ctr, _):
                    var ct = ctr.get();
                    if (!ct.meta.has(":luaExpose"))
                        Context.error('Cannot wrap type $fullName, as it does not have the @:luaExpose metadata.', ct.pos);
                    
                    data.classPos = ct.pos;
                    data.isAbstract = false;
                    
                    // parse static fields
                    data.isStatic = true;
                    data.objIdent = complexTypeToFieldExpr(t);
                    for (field in ct.statics.get()) {
                        luaIndexClassField(field, staticIndexCases, data);
                        luaNewIndexClassField(field, staticNewIndexCases, data);
                    }

                    if (ct.constructor != null) {
                        var ctor = ct.constructor.get();
                        luaIndexClassField(ctor, staticIndexCases, data);
                    }

                    // parse instance fields
                    data.isStatic = false;
                    data.objIdent = macro $i{"self"};
                    for (field in ct.fields.get()) {
                        luaIndexClassField(field, indexCases, data);
                        luaNewIndexClassField(field, newIndexCases, data);
                    }

                case TAbstract(abtr, _):
                    var abt = abtr.get();
                    if (!abt.meta.has(":luaExpose"))
                        Context.error('Cannot wrap type $fullName, as it does not have the @:luaExpose metadata.', abt.pos);

                    if (abt.impl == null)
                        Context.error('Cannot wrap type $fullName, as it does not have an internal implementation.', abt.pos);

                    data.classPos = abt.pos;
                    data.isAbstract = true;
                    
                    if (abt.impl != null) {
                        // actualType = TypeTools.toComplexType(abt.type);
                        actualType = TypeTools.toComplexType(Context.followWithAbstracts(abt.type));
                        var impl = abt.impl.get();

                        for (field in impl.statics.get()) {
                            var isStatic = false;

                            // if this is a method, it isn't "static" if the first argument
                            // is named "this"
                            switch (field.kind) {
                                case FMethod(_):
                                    switch (field.expr().t) {
                                        case TFun(funcArgs, ret):
                                            if (funcArgs.length < 1 || funcArgs[0].name != "this") {
                                                isStatic = true;
                                            }

                                        default:
                                    }

                                default:
                            }

                            if (isStatic) {
                                data.isStatic = true;
                                data.objIdent = complexTypeToFieldExpr(t);

                                luaIndexClassField(field, staticIndexCases, data);
                                luaNewIndexClassField(field, staticNewIndexCases, data);
                            } else {
                                data.isStatic = false;
                                data.objIdent = macro $i{"self"};

                                luaIndexClassField(field, indexCases, data);
                                luaNewIndexClassField(field, newIndexCases, data);
                            }
                        }
                    }
                
                default: Context.fatalError("Cannot wrap type " + fullName, Context.currentPos());
            }

            var whyDoesntPrivateAccessWorkINeedToDoThisInstead = macro $p{fullName.split(".")};
            
            typeWrapper = macro class $typeWrapperClassName {
                static var wrapIDs:Map<Int, $actualType> = [];
                static var wrapCache:Map<$actualType, Int> = [];
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

                static public function getObject(L:luavm.State, idx:Int):$t {
                    var udPtr = luavm.Lua.l_checkudata(L, idx, $v{mtName});
                    var id = udPtr.getI32(0);
                    return (cast wrapIDs[id]) ?? throw new haxe.Exception($v{"internal error: invalid object for " + fullName});
                }

                @:access($whyDoesntPrivateAccessWorkINeedToDoThisInstead)
                static function luaIndex(L:luavm.State):Int {
                    var self = getObject(L, 1);
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{indexSwitch};

                    return 1;
                }

                @:access($whyDoesntPrivateAccessWorkINeedToDoThisInstead)
                static function luaNewIndex(L:luavm.State):Int {
                    var self = getObject(L, 1);
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{newIndexSwitch};
                    
                    return 0;
                }

                @:access($whyDoesntPrivateAccessWorkINeedToDoThisInstead)
                static function luaStaticIndex(L:luavm.State):Int {
                    // var self = getObject(L, 1);
                    var key = luavm.Lua.l_checkstring(L, 2);

                    $e{staticIndexSwitch};

                    return 1;
                }

                @:access($whyDoesntPrivateAccessWorkINeedToDoThisInstead)
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
                
                @:access($whyDoesntPrivateAccessWorkINeedToDoThisInstead)
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
                    if (luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{mtName}) == cast luavm.Lua.LuaType.TNil) {
                        luavm.Lua.pop(L, 1);
                        init(L);
                    }
                }

                public static function push(L:luavm.State, v:$t) {
                    var cache = wrapCache[cast v];
                    if (cache != null) {
                        luavm.Lua.rawgeti(L, luavm.Lua.REGISTRYINDEX, cache);
                    } else {
                        var udPtr = luavm.LuaNative.lua_newuserdatauv(L, 4, 1);
                        udPtr.setI32(0, nextId);
                        wrapIDs[nextId] = cast v;
                        
                        getOrInitMetatable(L);
                        luavm.Lua.setmetatable(L, -2);

                        luavm.Lua.pushvalue(L, -1);
                        wrapCache[cast v] = luavm.Lua.l_ref(L, luavm.Lua.REGISTRYINDEX);
                        nextId++;
                    }
                }

                public static function pushStatic(L:luavm.State) {
                    getOrInitMetatable(L);
                    luavm.Lua.pop(L, 1);
                    luavm.Lua.getfield(L, luavm.Lua.REGISTRYINDEX, $v{classDataName});
                }

                public static function pushMetatable(L:luavm.State) {
                    getOrInitMetatable(L);
                }
            }

            Context.onTypeNotFound((s) -> {
                if (typeWrapperClassName == s) {
                    return typeWrapper;
                }

                return null;
            });

            // var printer = new haxe.macro.Printer();
            // trace(printer.printTypeDefinition(typeWrapper));

            typeWrappers[fullName] = typeWrapper;
        }

        return typeWrapperClassName;
    }

    public static function parseClassType(t:Expr):ComplexType {
        var typeName = ExprTools.toString(t);
        var type = Context.getType(typeName);

        return TypeTools.toComplexType(type);
    }

    public static function pushClassWrapper(L:Expr, t:Expr):Expr {
        var wrapper = getTypeWrapper(parseClassType(t));
        return macro $i{wrapper}.pushStatic($L);
    }

    public static function pushObjectWrapper(L:Expr, v:Expr):Expr {
        var argType = Context.follow(Context.typeof(v));
        var wrapper = getTypeWrapper(TypeTools.toComplexType(argType));

        #if target.static
        if (isPrimitive(TypeTools.toString(TypeTools.followWithAbstracts(argType)))) {
            return macro $i{wrapper}.push($L, $v);
        } else {
            return macro {
                var tmp = $v;
                if (tmp == null) luavm.Lua.pushnil($L);
                else $i{wrapper}.push($L, tmp);
            }
        }
        #else
        return macro {
            var tmp = $v;
            if (tmp == null) luavm.Lua.pushnil($L);
            else $i{wrapper}.push($L, tmp);
        }
        #end
    }

    public static function pushMetatable(L:Expr, t:Expr):Expr {
        var wrapper = getTypeWrapper(parseClassType(t));
        return macro $i{wrapper}.pushMetatable($L);
    }

    /**
     * Substitute one type to another when parsing the fields of types or parameters.
     * 
     * This must be called from an initialization macro. The replacement type also
     * must satisfy these requirements, lest it throw an error:
     * 1. It must be an abstract over the source type.
     * 2. Implicit conversions to/from the types must be possible.
     * @param srcType The type that will be substituted.
     * @param dstType The type that will be the substitute.
     */
    public static function registerSubstitute(srcType:String, dstType:String) {
        substitutes[srcType] = dstType;
    }

    public static function lspInit() {
        Compiler.registerCustomMetadata({
            metadata: ":luaExpose",
            doc: "- **type:** Put this on a type on signify that the generator may wrap this class. If not, it will throw an error on any attempt to process the class type.\n- **field:** By default, private fields will be hidden. Use this to force it to be exposed.",
            targets: [AnyField, Abstract, Class]
        });

        Compiler.registerCustomMetadata({
            metadata: ":luaName",
            doc: "Set the name of the field on the Lua side.",
            params: ["The name of the Lua field."],
            targets: [AnyField]
        });

        Compiler.registerCustomMetadata({
            metadata: ":luaHide",
            doc: "Do not expose this field to Lua.",
            targets: [AnyField]
        });

        Compiler.registerCustomMetadata({
            metadata: ":luaCatch",
            doc: "Internally wrap access to this field in a try/catch. If an exception occurs, a Lua error will be thrown instead of a Haxe exception.",
            targets: [AnyField]
        });

        Compiler.registerCustomDefine({
            define: "luawrap-enums",
            doc: "Signal to the wrapper generator to interface enum types with strings. The enum must not have a constructor which takes parameters. You can also specify which casing rules it should apply to the strings.
- **pascal:** `MyEnum`
- **camel:** `myEnum`
- **kebab:** `my-enum`
- **snake:** `my_enum`
- **flat:** `myenum`
- **int0:** Use the index of the enum variant, starting from 0.
- **int1:** Use the index of the enum variant, starting from 1.",
            params: ["pascal", "camel", "kebab", "snake", "flat", "int0", "int1"]
        });
    }
    #end
}