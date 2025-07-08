ifndef LUA_INCLUDE
  $(error Need to set LUA_INCLUDE directory)
endif

ifndef LUA_VERSION
  $(error Need to set LUA_VERSION. ex: LUA_VERSION=5_3)
endif

LIB_NAME ?= lua$(LUA_VERSION)
CFLAGS ?= -O2
LUA ?= lua
LUA_SOURCES ?= $(filter-out $(LUA_INCLUDE)/luac.c,$(filter-out $(LUA_INCLUDE)/lua.c,$(wildcard $(LUA_INCLUDE)/*.c)))

EMCC ?= emcc
EMCCFLAGS ?= -O2

WASM_OUTPUT_DIR?=test/out/js

all: hl wasm

hlexport.c wasmexport.c: generator/main.lua generator/conf/init.lua generator/conf/$(LUA_VERSION).lua
	$(LUA) generator/main.lua OUTPUT_LIB_NAME=$(LIB_NAME) LUA_VERSION=$(LUA_VERSION) LUA_INCLUDE=$(LUA_INCLUDE) CC=$(CC)

$(LIB_NAME).hdll: hlexport.c $(LUA_SOURCES)
	$(CC) -shared -fPIC -o $@ -I$(LUA_INCLUDE) $< $(LUA_SOURCES) -lhl $(CFLAGS)

$(WASM_OUTPUT_DIR)/$(LIB_NAME).js: wasmexport.c $(LUA_SOURCES)
	$(EMCC) -o $@ $(EMCCFLAGS) -I$(LUA_INCLUDE) wasmexport.c $(LUA_SOURCES) -sMODULARIZE -sEXPORT_NAME=LuaVM -sALLOW_TABLE_GROWTH=1 -sEXPORTED_FUNCTIONS=_malloc,_free -sEXPORTED_RUNTIME_METHODS=addFunction,HEAPU8,HEAPU32,wasmMemory

install: $(LIB_NAME).hdll
	sudo cp $< /usr/local/lib

hl: $(LIB_NAME).hdll

wasm: $(WASM_OUTPUT_DIR)/$(LIB_NAME).js

gen: hlexport.c

clean:
	rm -f $(LIB_NAME).hdll
	rm -f $(WASM_OUTPUT_DIR)/$(LIB_NAME).js $(WASM_OUTPUT_DIR)/$(LIB_NAME).wasm
	rm -f hlexport.c
	rm -f wasmexport.c
	rm -f lib/luavm/Lua.hx
	rm -f lib/luavm/LuaNative.hx

.PHONY: clean install wasm hl gen
