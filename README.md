# luavm
Helper repository for compiling and using the Lua VM for the HashLink and JavaScript targets. It uses a Lua script to generate a C source and Haxe bindings for a HashLink .hdll or a WebAssembly module.

Supported versions:
- Lua 5.3
- Lua 5.4

You may add support for different versions of Lua by creating a configuration file in generator/conf.

## Compiling
Requirements:
- GNU Make
- Lua 5.3+ interpreter
- GCC-compatible C compiler
- Emscripten compiler, if you want to build for the JS target.

> [!important]
> When specifying `LUA_SOURCES`, you need to exclude lua.c and luac.c or their equivalents. They are the source files for Lua command-line executables, and as such should not be included when building Lua as the library. Additionally, if you choose to omit `LUA_SOURCES`, the Makefile will use all C source files in `LUA_INCLUDE` directory, excluding lua.c and luac.c

### HashLink
1. Obtain the Lua source repository.
2. Run
```sh
# make lua54.hdll
make hl \
    LIB_NAME=lua54 \
    LUA_VERSION=5_4 \
    LUA_INCLUDE=<lua source directory> \
    LUA_SOURCES=<list of lua source files> \
    LUA=<lua interpreter command>

# if you are on a Unix, this installs it into your /usr/local/lib
make install
```

### JavaScript+WebAssembly
1. Obtain the Lua source repository.
2. Run
```sh
# make lua54.wasm and lua54.js
make wasm \
    LIB_NAME=lua54 \
    LUA_VERSION=5_4 \
    LUA_INCLUDE=<lua source directory> \
    LUA_SOURCES=<list of lua source files> \
    LUA=<lua interpreter command> \
    EMCC=<emcc command> \
    WASM_OUTPUT_DIR=<webassembly+js output directory> \
```
This will generate two files: lua54.js and lua54.wasm. They must be placed adjacent to each other in the directory structure, and then executed by the HTML source code before your Haxe code.

If you want to build the WASM without the Makefile, note that you must build it with these arguments:
```
-sMODULARIZE -sEXPORT_NAME=LuaVM -sALLOW_TABLE_GROWTH=1 -sEXPORTED_FUNCTIONS=_malloc,_free -sEXPORTED_RUNTIME_METHODS=addFunction,HEAPU8,HEAP32,HEAPU32
```

### Using Meson
Provided is a Meson build file for building the .hdll file with Meson. You will still need Make + GCC/Clang to run the generator (since it needs to use the preprocessor), and also additionally Python 3+, but this will allow you to use MSVC to compile the final .hdll. (I'm too lazy to install visual studio to make the vcxproj file)

Once you have the prerequisities installed, run this to set up the Meson build directory:
```bash
meson setup builddir \
    -Dlua_include=<lua source directory> \
    -Dhashlink_libs=C:/HaxeToolkit/hashlink \
    -Dhashlink_include=C:/HaxeToolkit/hashlink/include \
    -Dlib_name=lua54
```
Replace each option with the correct values, depending on your system and HashLink install location. Then, to build the library, run:
```bash
meson compile -C builddir
```
This will create a lua54.dll and lua54.lib file in the build directory. Rename lua54.dll to lua54.hdll and install it to your computer. You may run `meson install -C builddir` to do so.

## Usage
Register the library with `haxelib dev`, and then require the library in the .hxml like so:
```hxml
-lib luavm
```

The library also comes with a few optional utilities for your convenience, located in the `luavm.util` package. Below are their documentations.

### FuncHelper
This is a utility class for pushing Haxe functions.

There are limitations/qualms with regards to pushing Haxe functions onto the Lua stack.
- hl: Functions cannot reference upvalues.
- js: You must manually allocate a function pointer for every unique function you want to push.

This class provides a good workaround for this issue. Instead of pushing the Haxe function directly, it associates a unique integer ID per function pushed, pushes this ID as a userdata (a userdata, for GC tracking), and uses this userdata as an upvalue for a static wrapper function that is then pushed. This static wrapper function will obtain the userdata from the upvalue, obtain the function from the integer ID, and run it.

It provides these functions:
- `FuncHelper.init(L:luavm.State):Void`: Initialize the utility after creating the Lua state.
- `FuncHelper.push(L:luavm.State, func:State->Int):Void`: Push a function onto the Lua stack.
- `FuncHelper.pushClosure(L:luavm.State, upvalues:Int, func->State->Int):Void`: Like `push`, but pops `upvalues` values from the stack and assigns them as Lua upvalues to the context of the given function call. Refer to documentation for [lua_pushcclosure](https://www.lua.org/manual/5.4/manual.html#lua_pushcclosure) for additional information.

> [!important]
> For any function pushed with FuncHelper, the upvalue at index 1 is always occupied by FuncHelper internal data. Thus, when using `pushClosure`, the index of the first (user-defined) upvalue is at index 2.

### ClassWrapper
This is a utility class for automatic generation of Lua wrapper classes for Haxe classes using macros. It requires FuncHelper to be set up for any Lua state it is called in.

It provides these functions:
- `pushObject<T>(L:luavm.State, v:T):Void`, to push an object of type T to the Lua stack.
- `pushClass<T>(L:luavm.State, v:Class<T>):Void`, to push the static class wrapper for type T to the Lua stack.
- `pushMetatable<T>(L:luavm.State, v:Class<T>):Void`, to push the metatable for type T. This can be used to override/add metamethods.
- `registerTypeSubstitute(fromType:String, toType:String):Void` to be called in an initialization macro to substitute one type for another when building Lua wrappers.

It also provides these compiler metadatas for guiding the wrapper generation process:
- `@:luaExpose`:
    - **class**: Put this on a class to signify the generator can wrap around this. If not, it will throw an error on any attempts to process this class type.
    - **field**: By default, private fields will be hidden. Use this to force it to be exposed.
- `@:luaName(nm:String)`: Put this on a field to set the name of the field on the Lua side. If not specified, it will use the name of the field directly.
- `@:luaHide` Do not expose this field to Lua.
- `@:luaCatch` Internally wrap access to this field in a try/catch. If an exception occurs, raise a Lua error.

With respect to enums, the default behavior is to error when attempting to parse an enum type. However, you can configure how ClassWrapper handles enum types by defining `-D luawrap-enums=X`, where X is one of several configuration options. With this enabled, enum variants in Lua will be represented by either the name of the enum variant as a string, or the enum variant's integer index. The define has several configuration options:
- `luawrap-enums=pascal`: Use the name enum variants, in `PascalCase`.
- `luawrap-enums=camel`: Use the name enum variants, in `camelCase`.
- `luawrap-enums=kebab`: Use the name enum variants, in `kebab-case`.
- `luawrap-enums=snake`: Use the name enum variants, in `snake_case`.
- `luawrap-enums=flat`: Use the name enum variants, in `flatcase`.
- `luawrap-enums=int0`: Use the index of enum variants, indexed from 0.
- `luawrap-enums=int0`: Use the index of enum variants, indexed from 1.