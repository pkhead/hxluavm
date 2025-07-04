EMCC = emcc
CFLAGS ?= -sMODULARIZE -sEXPORT_NAME=LuaVM -sALLOW_TABLE_GROWTH=1 -sEXPORTED_FUNCTIONS=_malloc,_free -sEXPORTED_RUNTIME_METHODS=addFunction,HEAPU8,HEAP32,HEAPU32

LUA_SRC = ../lua-5.4.8/src

CORE_O = lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o ltm.o lundump.o lvm.o lzio.o
LIB_O = lauxlib.o lbaselib.o lcorolib.o ldblib.o lmathlib.o lstrlib.o ltablib.o lutf8lib.o loadlib.o liolib.o loslib.o linit.o
OBJS = $(addprefix $(LUA_SRC)/,$(CORE_O)) $(addprefix $(LUA_SRC)/,$(LIB_O))
SOURCES = $(addsuffix .c,$(basename $(OBJS)))

lua54.wasm: $(SOURCES)
	$(EMCC) -o test/lua54.js $(SOURCES) $(CFLAGS)

# clean:
# 	rm -f $(OBJS)

.PHONY: clean