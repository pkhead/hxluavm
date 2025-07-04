# luavm
Helper repository for compiling and using the Lua VM for the HashLink and JavaScript targets.

It (theoretically) supports compiling and using any version of Lua.

## Compiling
Requirements:
- GNU Make
- Lua 5.4+ interpreter
- C compiler
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