Build the Emscripten Lua with these flags:
```
-sMODULARIZE -sEXPORT_NAME=LuaVM -sALLOW_TABLE_GROWTH=1 -sEXPORTED_FUNCTIONS=_malloc,_free -sEXPORTED_RUNTIME_METHODS=addFunction,HEAPU8,HEAP32,HEAPU32
```

Make sure to define `LUA_API` in luaconf.h as this:
```c
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define LUA_API		EMSCRIPTEN_KEEPALIVE
#else
#define LUA_API		extern
#endif
```