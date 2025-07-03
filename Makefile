CC=clang
LUAPATH=lua-5.4.8
LIBLUA=$(LUAPATH)/src/liblua.a
CFLAGS=-arch x86_64

lua54.hdll: export.c $(LIBLUA)
	$(CC) -shared -o $@ -I$(LUAPATH)/src $< $(LIBLUA) $(CFLAGS)

install: lua54.hdll
	sudo cp $< /usr/local/lib