.PHONY : clean all none

LUA_CLIB_PATH ?= luaclib
LUA_INC ?= skynet/3rd/lua
CSERVICE_PATH ?= cservice
SKYNET_INC ?= skynet/skynet-src
SHARED := -fPIC --shared
CFLAGS = -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)
CC ?= gcc

PLATS = macosx linux

none :
	@echo "Please do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"

init: 
	git submodule update --init && cd skynet && git submodule update --init 

linux : PLAT = linux
macosx : PLAT = macosx
macosx : SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup

TLS_MODULE=ltls
TLS_LIB= /usr/local/opt/openssl/lib
TLS_INC= /usr/local/opt/openssl/include

linux macosx : init
	cd skynet && $(MAKE) TLS_MODULE="$(TLS_MODULE)" TLS_LIB="$(TLS_LIB)" TLS_INC="$(TLS_INC)" PLAT="$(PLAT)" && cd .. && $(MAKE) all SHARED="$(SHARED)" PLAT="$(PLAT)"
	
CSERVICE = jmlogger
LUA_CLIB = cjson lfs


$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

all : \
  $(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so) 


$(LUA_CLIB_PATH)/cjson.so : lualib-src/lua-cjson/lua_cjson.c lualib-src/lua-cjson/strbuf.c lualib-src/lua-cjson/strbuf.h | $(LUA_CLIB_PATH)
	cd lualib-src/lua-cjson && $(MAKE) $(PLAT) && $(MAKE) install

$(LUA_CLIB_PATH)/lfs.so : lualib-src/luafilesystem/src/lfs.c lualib-src/luafilesystem/src/lfs.h
	cd lualib-src/luafilesystem/ && $(MAKE) $(PLAT) && $(MAKE) install

$(CSERVICE_PATH)/jmlogger.so : service-src/service_logger.c | $(CSERVICE_PATH) 
	$(CC) $(CFLAGS) $(SHARED) $< -o $@ -I$(SKYNET_INC)

clean :
	rm -rf $(LUA_CLIB_PATH)/*
	rm -rf $(CSERVICE_PATH)/*
	cd skynet && $(MAKE) clean
