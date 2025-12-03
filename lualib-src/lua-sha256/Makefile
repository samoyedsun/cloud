SHA256_VERSION = 1.0.0
LUA_VERSION = 5.3

# 路径配置
PREFIX ?= ../../skynet/3rd/lua
LUA_INCLUDE_DIR ?= $(PREFIX)/
LUA_LIB_DIR ?= ../../luaclib/

# 编译选项
CFLAGS ?= -g -O3 -Wall -fpic
override CFLAGS += -I$(LUA_INCLUDE_DIR) -DVERSION=\"$(SHA256_VERSION)\"

# 链接选项
LDFLAGS += -shared

INSTALL ?= install

.PHONY: all clean install linux macosx

all: sha256.so

sha256.so: lua_sha256.o
	$(CC) $(LDFLAGS) -o $@ $^

lua_sha256.o: lua_sha256.c
	$(CC) $(CFLAGS) -c lua_sha256.c

linux: sha256.so

macosx:
	$(CC) $(CFLAGS) -dynamiclib -Wl,-undefined,dynamic_lookup lua_sha256.c -o sha256.so

install:
	$(INSTALL) sha256.so $(LUA_LIB_DIR)

clean:
	rm -f *.o *.so