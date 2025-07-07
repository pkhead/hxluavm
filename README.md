# luavm
Helper repository for compiling and using the Lua VM for the HashLink and JavaScript targets.

It uses a Lua script to read Lua headers and a configuration file to generate a C source for a HashLink native extension and a WebAssembly module that exports the desired Lua functions. It also generates Haxe bindings/wrappers to said extension/module.

## Compiling
Requirements:
- GNU Make
- Lua 5.4+ interpreter
- GCC-compatible C compiler
- Emscripten compiler, if you want to build for the JS target.

> [!important]
> When specifying `LUA_SOURCES`, you need to exclude lua.c and luac.c, or their equivalents. They are the source files for Lua command-line programs, and as such should not be included when building Lua as the library. Additionally, if you choose to omit `LUA_SOURCES`, the Makefile will use all C source files in `LUA_INCLUDE` directory, excluding lua.c and luac.c

### HashLink
1. Obtain the Lua source repository.
2. Run
```sh
# make lua54.hdll
make hl \
    LIB_NAME=lua54 \
    LUA_INCLUDE=<lua source directory> \
    LUA_SOURCES=<list of lua source files> \
    LUA=<lua interpreter command>

# if you are on a unix, this installs it into your /usr/local/lib
make install
```

### JavaScript/WebAssembly
1. Obtain the Lua source repository.
2. Run
```sh
# make lua54.wasm and lua54.js
make wasm \
    LIB_NAME=lua54 \
    LUA_INCLUDE=<lua source directory> \
    LUA_SOURCES=<list of lua source files> \
    LUA=<lua interpreter command> \
    EMCC=<emcc command> \
    WASM_OUTPUT_DIR=<webassembly+js output directory> \
```

If you want to build the lua54.wasm without the Makefile, note that you must build it with these arguments:
```
-sMODULARIZE -sEXPORT_NAME=LuaVM -sALLOW_TABLE_GROWTH=1 -sEXPORTED_FUNCTIONS=_malloc,_free -sEXPORTED_RUNTIME_METHODS=addFunction,HEAPU8,HEAP32,HEAPU32
```

## Usage
Register the library with `haxelib dev`, and then require the library in the .hxml like so:
```hxml
-lib luavm
```

The library also comes with a few optional utilities for your convenience, located in the `luavm.util` package. Below are their documentations.

### FuncHelper
This is a utility class for pushing Haxe functions.

There are limitations/qualms with regards to pushing Haxe functions onto the Lua stack.
- hl: Functions cannot reference a closure.
- js: You must manually allocate a function pointer for every function you want to push.

This class provides a good workaround for this issue. Instead of pushing the Haxe function directly, it associates a unique integer ID per function pushed, pushes this ID as a userdata (a userdata, for GC tracking), and uses this userdata as an upvalue for a static wrapper function that is then pushed. This static wrapper function will obtain the userdata from the upvalue, obtain the function from the integer ID, and run it.

To activate it, call `FuncHelper.init(L)` after creating the Lua state.

### ClassWrapper
This is a utility class for automatic macrogeneration of Lua wrapper classes for Haxe classes using macros. It requires FuncHelper to be set up for any Lua state it is called in.

It provides two functions:
- `push<T>(L:luavm.State, v:T):Void`, to push an object of type T to the Lua stack.
- `pushClass<T>(L:luavm.State, v:Class<T>):Void`, to push the static class wrapper for type T to the Lua stack.

It also provides these compiler metadatas for guiding the wrapper generation process:
- `@:luaExpose`:
    - **class**: Put this on a class to signify the generator can wrap around this. If not, it will throw an error on any attempts to process this class type.
    - **field**: By default, private fields will be hidden. Use this to force it to be exposed.
- `@:luaName(nm:String)`: Put this on a field to set the name of the field on the Lua side. If not specified, it will use the name of the Haxe field.
- `@:luaHide` Do not expose this field to Lua.