/*
 * sha256.c - SHA256 HMAC Lua C 扩展（修正版）
 * 编译: gcc -O2 -fPIC -shared -o sha256.so sha256.c -llua
 */

#include <lua.h>
#include <lauxlib.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

/* SHA256 常量 */
static const uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

/* 位操作宏 */
#define ROTR32(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTR32(x, 2) ^ ROTR32(x, 13) ^ ROTR32(x, 22))
#define EP1(x) (ROTR32(x, 6) ^ ROTR32(x, 11) ^ ROTR32(x, 25))
#define SIG0(x) (ROTR32(x, 7) ^ ROTR32(x, 18) ^ ((x) >> 3))
#define SIG1(x) (ROTR32(x, 17) ^ ROTR32(x, 19) ^ ((x) >> 10))

/* SHA256 上下文结构 */
typedef struct {
    uint32_t state[8];
    uint64_t bitlen;
    uint8_t buffer[64];
    uint32_t buflen;
} SHA256_CTX;

/* HMAC-SHA256 上下文结构 */
typedef struct {
    SHA256_CTX inner_ctx;
    SHA256_CTX outer_ctx;
    SHA256_CTX current_ctx;
    uint8_t ipad[64];
    uint8_t opad[64];
} HMAC_CTX;

/* SHA256 初始化 */
static void sha256_init(SHA256_CTX *ctx) {
    ctx->state[0] = 0x6a09e667;
    ctx->state[1] = 0xbb67ae85;
    ctx->state[2] = 0x3c6ef372;
    ctx->state[3] = 0xa54ff53a;
    ctx->state[4] = 0x510e527f;
    ctx->state[5] = 0x9b05688c;
    ctx->state[6] = 0x1f83d9ab;
    ctx->state[7] = 0x5be0cd19;
    ctx->bitlen = 0;
    ctx->buflen = 0;
    memset(ctx->buffer, 0, 64);
}

/* SHA256 转换函数 */
static void sha256_transform(SHA256_CTX *ctx, const uint8_t data[64]) {
    uint32_t a, b, c, d, e, f, g, h, i, j;
    uint32_t m[64];
    uint32_t temp1, temp2;
    
    /* 将数据分成32位字 */
    for (i = 0, j = 0; i < 16; ++i, j += 4) {
        m[i] = (data[j] << 24) | (data[j + 1] << 16) | 
               (data[j + 2] << 8) | (data[j + 3]);
    }
    
    /* 扩展消息 */
    for (; i < 64; ++i) {
        m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];
    }
    
    /* 初始化工作变量 */
    a = ctx->state[0];
    b = ctx->state[1];
    c = ctx->state[2];
    d = ctx->state[3];
    e = ctx->state[4];
    f = ctx->state[5];
    g = ctx->state[6];
    h = ctx->state[7];
    
    /* 主循环 */
    for (i = 0; i < 64; ++i) {
        temp1 = h + EP1(e) + CH(e, f, g) + K[i] + m[i];
        temp2 = EP0(a) + MAJ(a, b, c);
        h = g;
        g = f;
        f = e;
        e = d + temp1;
        d = c;
        c = b;
        b = a;
        a = temp1 + temp2;
    }
    
    /* 添加到当前哈希值 */
    ctx->state[0] += a;
    ctx->state[1] += b;
    ctx->state[2] += c;
    ctx->state[3] += d;
    ctx->state[4] += e;
    ctx->state[5] += f;
    ctx->state[6] += g;
    ctx->state[7] += h;
}

/* SHA256 更新 */
static void sha256_update(SHA256_CTX *ctx, const uint8_t *data, size_t len) {
    uint32_t i;
    
    for (i = 0; i < len; ++i) {
        ctx->buffer[ctx->buflen] = data[i];
        ctx->buflen++;
        
        if (ctx->buflen == 64) {
            sha256_transform(ctx, ctx->buffer);
            ctx->bitlen += 512;
            ctx->buflen = 0;
        }
    }
}

/* SHA256 结束 */
static void sha256_final(SHA256_CTX *ctx, uint8_t hash[32]) {
    uint32_t i;
    
    i = ctx->buflen;
    
    /* 填充 */
    if (i < 56) {
        ctx->buffer[i++] = 0x80;
        while (i < 56) {
            ctx->buffer[i++] = 0x00;
        }
    } else {
        ctx->buffer[i++] = 0x80;
        while (i < 64) {
            ctx->buffer[i++] = 0x00;
        }
        sha256_transform(ctx, ctx->buffer);
        memset(ctx->buffer, 0, 56);
    }
    
    /* 添加长度 */
    ctx->bitlen += ctx->buflen * 8;
    ctx->buffer[63] = ctx->bitlen;
    ctx->buffer[62] = ctx->bitlen >> 8;
    ctx->buffer[61] = ctx->bitlen >> 16;
    ctx->buffer[60] = ctx->bitlen >> 24;
    ctx->buffer[59] = ctx->bitlen >> 32;
    ctx->buffer[58] = ctx->bitlen >> 40;
    ctx->buffer[57] = ctx->bitlen >> 48;
    ctx->buffer[56] = ctx->bitlen >> 56;
    
    sha256_transform(ctx, ctx->buffer);
    
    /* 生成哈希值 */
    for (i = 0; i < 4; ++i) {
        hash[i]      = (ctx->state[0] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 4]  = (ctx->state[1] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 8]  = (ctx->state[2] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 12] = (ctx->state[3] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 16] = (ctx->state[4] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 20] = (ctx->state[5] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 24] = (ctx->state[6] >> (24 - i * 8)) & 0x000000ff;
        hash[i + 28] = (ctx->state[7] >> (24 - i * 8)) & 0x000000ff;
    }
}

/* 计算 SHA256 哈希值 */
static void sha256_hash(const uint8_t *data, size_t len, uint8_t hash[32]) {
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, data, len);
    sha256_final(&ctx, hash);
}

/* HMAC-SHA256 初始化 */
static void hmac_sha256_init(HMAC_CTX *ctx, const uint8_t *key, size_t key_len) {
    uint8_t key_buffer[64];
    uint32_t i;
    
    /* 如果密钥长度超过64字节，先计算其哈希 */
    if (key_len > 64) {
        sha256_hash(key, key_len, key_buffer);
        key = key_buffer;
        key_len = 32;
    } else if (key_len < 64) {
        /* 复制密钥到缓冲区 */
        memcpy(key_buffer, key, key_len);
        /* 填充0 */
        memset(key_buffer + key_len, 0, 64 - key_len);
        key = key_buffer;
    }
    
    /* 生成 ipad 和 opad */
    for (i = 0; i < 64; ++i) {
        ctx->ipad[i] = key[i] ^ 0x36;
        ctx->opad[i] = key[i] ^ 0x5c;
    }
    
    /* 初始化内部上下文 */
    sha256_init(&ctx->inner_ctx);
    sha256_update(&ctx->inner_ctx, ctx->ipad, 64);
    
    /* 初始化外部上下文 */
    sha256_init(&ctx->outer_ctx);
    sha256_update(&ctx->outer_ctx, ctx->opad, 64);
    
    /* 初始化当前上下文（从内部上下文开始） */
    memcpy(&ctx->current_ctx, &ctx->inner_ctx, sizeof(SHA256_CTX));
    
    /* 清理敏感数据 */
    memset(key_buffer, 0, sizeof(key_buffer));
}

/* HMAC-SHA256 更新 */
static void hmac_sha256_update(HMAC_CTX *ctx, const uint8_t *data, size_t len) {
    sha256_update(&ctx->current_ctx, data, len);
}

/* HMAC-SHA256 结束 */
static void hmac_sha256_final(HMAC_CTX *ctx, uint8_t hash[32]) {
    uint8_t inner_hash[32];
    
    /* 完成内部哈希 */
    memcpy(&ctx->inner_ctx, &ctx->current_ctx, sizeof(SHA256_CTX));
    sha256_final(&ctx->inner_ctx, inner_hash);
    
    /* 完成外部哈希 */
    sha256_update(&ctx->outer_ctx, inner_hash, 32);
    sha256_final(&ctx->outer_ctx, hash);
    
    /* 清理敏感数据 */
    memset(inner_hash, 0, sizeof(inner_hash));
}

/* 计算 HMAC-SHA256 */
static void hmac_sha256_calc(const uint8_t *key, size_t key_len, 
                           const uint8_t *data, size_t data_len, 
                           uint8_t hash[32]) {
    HMAC_CTX ctx;
    hmac_sha256_init(&ctx, key, key_len);
    hmac_sha256_update(&ctx, data, data_len);
    hmac_sha256_final(&ctx, hash);
}

/* 将二进制转换为16进制字符串 */
static void bin_to_hex(char *hex, const uint8_t *bin, size_t len) {
    static const char hex_digits[] = "0123456789abcdef";
    size_t i;
    
    for (i = 0; i < len; ++i) {
        hex[i * 2] = hex_digits[(bin[i] >> 4) & 0x0F];
        hex[i * 2 + 1] = hex_digits[bin[i] & 0x0F];
    }
    hex[len * 2] = '\0';
}

/* 16进制字符串转二进制 */
static int hex_to_bin(uint8_t *bin, const char *hex, size_t hex_len) {
    size_t i;
    int high, low;
    
    if (hex_len % 2 != 0) {
        return 0;
    }
    
    for (i = 0; i < hex_len / 2; ++i) {
        /* 高4位 */
        if (hex[i * 2] >= '0' && hex[i * 2] <= '9') {
            high = hex[i * 2] - '0';
        } else if (hex[i * 2] >= 'a' && hex[i * 2] <= 'f') {
            high = hex[i * 2] - 'a' + 10;
        } else if (hex[i * 2] >= 'A' && hex[i * 2] <= 'F') {
            high = hex[i * 2] - 'A' + 10;
        } else {
            return 0;
        }
        
        /* 低4位 */
        if (hex[i * 2 + 1] >= '0' && hex[i * 2 + 1] <= '9') {
            low = hex[i * 2 + 1] - '0';
        } else if (hex[i * 2 + 1] >= 'a' && hex[i * 2 + 1] <= 'f') {
            low = hex[i * 2 + 1] - 'a' + 10;
        } else if (hex[i * 2 + 1] >= 'A' && hex[i * 2 + 1] <= 'F') {
            low = hex[i * 2 + 1] - 'A' + 10;
        } else {
            return 0;
        }
        
        bin[i] = (high << 4) | low;
    }
    
    return 1;
}

/* ========== Lua 接口函数 ========== */

/* 简单 SHA256 哈希函数 */
static int l_sha256(lua_State *L) {
    size_t len;
    const char *data = luaL_checklstring(L, 1, &len);
    int return_binary = lua_toboolean(L, 2);
    uint8_t hash[32];
    
    sha256_hash((const uint8_t *)data, len, hash);
    
    if (return_binary) {
        lua_pushlstring(L, (const char *)hash, 32);
    } else {
        char hex[65];
        bin_to_hex(hex, hash, 32);
        lua_pushstring(L, hex);
    }
    
    return 1;
}

/* SHA256 上下文对象 */
static int l_sha256_new(lua_State *L) {
    SHA256_CTX *ctx = (SHA256_CTX *)lua_newuserdata(L, sizeof(SHA256_CTX));
    sha256_init(ctx);
    
    luaL_getmetatable(L, "sha256.ctx");
    lua_setmetatable(L, -2);
    
    return 1;
}

static int l_sha256_update(lua_State *L) {
    SHA256_CTX *ctx = (SHA256_CTX *)luaL_checkudata(L, 1, "sha256.ctx");
    size_t len;
    const char *data = luaL_checklstring(L, 2, &len);
    
    sha256_update(ctx, (const uint8_t *)data, len);
    lua_pushvalue(L, 1);
    return 1;
}

static int l_sha256_final(lua_State *L) {
    SHA256_CTX *ctx = (SHA256_CTX *)luaL_checkudata(L, 1, "sha256.ctx");
    int return_binary = lua_toboolean(L, 2);
    uint8_t hash[32];
    
    sha256_final(ctx, hash);
    
    if (return_binary) {
        lua_pushlstring(L, (const char *)hash, 32);
    } else {
        char hex[65];
        bin_to_hex(hex, hash, 32);
        lua_pushstring(L, hex);
    }
    
    return 1;
}

/* HMAC-SHA256 函数（修正版：支持第三个参数） */
static int l_hmac_sha256(lua_State *L) {
    size_t key_len, data_len;
    const char *key = luaL_checklstring(L, 1, &key_len);
    const char *data = luaL_checklstring(L, 2, &data_len);
    int return_binary = lua_toboolean(L, 3);  /* 第三个参数控制返回格式 */
    uint8_t hash[32];
    
    hmac_sha256_calc((const uint8_t *)key, key_len, 
                    (const uint8_t *)data, data_len, 
                    hash);
    
    if (return_binary) {
        lua_pushlstring(L, (const char *)hash, 32);
    } else {
        char hex[65];
        bin_to_hex(hex, hash, 32);
        lua_pushstring(L, hex);
    }
    
    return 1;
}

/* HMAC-SHA256 上下文对象 */
static int l_hmac_sha256_new(lua_State *L) {
    size_t key_len;
    const char *key = luaL_checklstring(L, 1, &key_len);
    
    HMAC_CTX *ctx = (HMAC_CTX *)lua_newuserdata(L, sizeof(HMAC_CTX));
    hmac_sha256_init(ctx, (const uint8_t *)key, key_len);
    
    luaL_getmetatable(L, "hmac_sha256.ctx");
    lua_setmetatable(L, -2);
    
    return 1;
}

static int l_hmac_sha256_update(lua_State *L) {
    HMAC_CTX *ctx = (HMAC_CTX *)luaL_checkudata(L, 1, "hmac_sha256.ctx");
    size_t len;
    const char *data = luaL_checklstring(L, 2, &len);
    
    hmac_sha256_update(ctx, (const uint8_t *)data, len);
    lua_pushvalue(L, 1);
    return 1;
}

static int l_hmac_sha256_final(lua_State *L) {
    HMAC_CTX *ctx = (HMAC_CTX *)luaL_checkudata(L, 1, "hmac_sha256.ctx");
    int return_binary = lua_toboolean(L, 2);  /* 支持第二个参数控制返回格式 */
    uint8_t hash[32];
    
    hmac_sha256_final(ctx, hash);
    
    if (return_binary) {
        lua_pushlstring(L, (const char *)hash, 32);
    } else {
        char hex[65];
        bin_to_hex(hex, hash, 32);
        lua_pushstring(L, hex);
    }
    
    return 1;
}

/* 工具函数：二进制转16进制 */
static int l_hexlify(lua_State *L) {
    size_t len;
    const char *data = luaL_checklstring(L, 1, &len);
    char *hex = (char *)malloc(len * 2 + 1);
    
    if (!hex) {
        luaL_error(L, "memory allocation failed");
    }
    
    bin_to_hex(hex, (const uint8_t *)data, len);
    lua_pushstring(L, hex);
    
    free(hex);
    return 1;
}

/* 工具函数：16进制转二进制 */
static int l_unhexlify(lua_State *L) {
    size_t hex_len;
    const char *hex = luaL_checklstring(L, 1, &hex_len);
    uint8_t *bin = (uint8_t *)malloc(hex_len / 2);
    
    if (!bin) {
        luaL_error(L, "memory allocation failed");
    }
    
    if (!hex_to_bin(bin, hex, hex_len)) {
        free(bin);
        luaL_error(L, "invalid hex string");
    }
    
    lua_pushlstring(L, (const char *)bin, hex_len / 2);
    free(bin);
    return 1;
}

/* 垃圾回收函数 */
static int l_sha256_gc(lua_State *L) {
    SHA256_CTX *ctx = (SHA256_CTX *)luaL_checkudata(L, 1, "sha256.ctx");
    memset(ctx, 0, sizeof(SHA256_CTX));
    return 0;
}

static int l_hmac_sha256_gc(lua_State *L) {
    HMAC_CTX *ctx = (HMAC_CTX *)luaL_checkudata(L, 1, "hmac_sha256.ctx");
    memset(ctx, 0, sizeof(HMAC_CTX));
    return 0;
}

/* 元方法 */
static int l_sha256_tostring(lua_State *L) {
    lua_pushstring(L, "sha256 context");
    return 1;
}

static int l_hmac_sha256_tostring(lua_State *L) {
    lua_pushstring(L, "hmac_sha256 context");
    return 1;
}

/* 模块注册 */
static const luaL_Reg sha256_lib[] = {
    {"hash", l_sha256},
    {"new", l_sha256_new},
    {"hmac", l_hmac_sha256},
    {"hmac_new", l_hmac_sha256_new},
    {"hexlify", l_hexlify},
    {"unhexlify", l_unhexlify},
    {NULL, NULL}
};

static const luaL_Reg sha256_ctx_methods[] = {
    {"update", l_sha256_update},
    {"final", l_sha256_final},
    {"__gc", l_sha256_gc},
    {"__tostring", l_sha256_tostring},
    {NULL, NULL}
};

static const luaL_Reg hmac_sha256_ctx_methods[] = {
    {"update", l_hmac_sha256_update},
    {"final", l_hmac_sha256_final},
    {"__gc", l_hmac_sha256_gc},
    {"__tostring", l_hmac_sha256_tostring},
    {NULL, NULL}
};

/* 注意：这个函数名必须和 require 的名字匹配 */
LUALIB_API int luaopen_sha256(lua_State *L) {
    /* 创建 SHA256 上下文元表 */
    luaL_newmetatable(L, "sha256.ctx");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, sha256_ctx_methods, 0);
    lua_pop(L, 1);
    
    /* 创建 HMAC-SHA256 上下文元表 */
    luaL_newmetatable(L, "hmac_sha256.ctx");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, hmac_sha256_ctx_methods, 0);
    lua_pop(L, 1);
    
    /* 创建库 */
    luaL_newlib(L, sha256_lib);
    
    /* 添加常量 */
    lua_pushinteger(L, 32);
    lua_setfield(L, -2, "digest_size");
    
    lua_pushinteger(L, 64);
    lua_setfield(L, -2, "block_size");
    
    lua_pushliteral(L, "2.0.0");
    lua_setfield(L, -2, "version");
    
    return 1;
}

/* 可选：提供其他入口点 */
LUALIB_API int luaopen_hmac_sha256(lua_State *L) {
    return luaopen_sha256(L);
}