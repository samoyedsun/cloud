--! xmake 构建脚本(仅用于 Windows)
--
-- Linux / macOS 使用项目根目录的 Makefile:
--   make linux
--   make macosx
--
-- skynet 以 submodule 引入且不做任何修改。
-- Windows 下通过 3rd/posix(POSIX 兼容层 + wepoll 实现的 epoll) 和
-- 3rd/pthread-win32 提供运行环境。
--
--   xmake f -m release -y
--   xmake -y
--   xmake install -y

set_project("cloud")
set_version("1.0.0")
set_languages("c11", "cxx17")

add_rules("mode.debug", "mode.release")

-- xmake 只负责 Windows 构建, 其他平台请使用 Makefile
set_allowedplats("windows")

local project_dir = os.projectdir()
local skynet_dir = path.join(project_dir, "skynet")
local third_dir = path.join(project_dir, "3rd")

-- 构建产物(中间输出)
local out_dir = path.join(project_dir, "build", "out")
local out_skynet_dir = path.join(out_dir, "skynet")
local out_skynet_luaclib_dir = path.join(out_skynet_dir, "luaclib")
local out_skynet_cservice_dir = path.join(out_skynet_dir, "cservice")
local out_luaclib_dir = path.join(out_dir, "luaclib")
local out_cservice_dir = path.join(out_dir, "cservice")

-- xmake install 的安装目录
-- Windows 加载 DLL 时优先搜索 exe 所在目录, 所以 exe 和它依赖的 dll 必须安装到同一目录
local install_bin_dir = project_dir
-- 模块目录与 make linux 的布局一致
local install_skynet_luaclib_dir = path.join(skynet_dir, "luaclib")
local install_skynet_cservice_dir = path.join(skynet_dir, "cservice")
local install_luaclib_dir = path.join(project_dir, "luaclib")
local install_cservice_dir = path.join(project_dir, "cservice")

-- 导入库统一放这里, 避免污染构建产物目录
local lib_dir = path.join(project_dir, "build", "lib")

-- ---------------------------------------------------------------------------
-- 源码列表
-- ---------------------------------------------------------------------------
local function sources_without(dir, excludes)
    local excluded = {}
    for _, name in ipairs(excludes) do
        excluded[name] = true
    end
    local result = {}
    for _, src in ipairs(os.files(path.join(dir, "*.c"))) do
        if not excluded[path.filename(src)] then
            table.insert(result, src)
        end
    end
    return result
end

local lua_lib_src = sources_without(path.join(skynet_dir, "3rd/lua"),
    { "lua.c", "luac.c", "onelua.c", "ltests.c" })

local skynet_src = sources_without(path.join(skynet_dir, "skynet-src"),
    { "skynet_main.c" })

local skynet_lua_clib_src = {
    "lua-skynet.c", "lua-seri.c", "lua-socket.c", "lua-mongo.c",
    "lua-netpack.c", "lua-memory.c", "lua-multicast.c", "lua-cluster.c",
    "lua-crypt.c", "lsha1.c", "lua-sharedata.c", "lua-stm.c",
    "lua-debugchannel.c", "lua-datasheet.c", "lua-sharetable.c",
}
for i, name in ipairs(skynet_lua_clib_src) do
    skynet_lua_clib_src[i] = path.join(skynet_dir, "lualib-src", name)
end

local sproto_src = os.files(path.join(skynet_dir, "lualib-src/sproto/*.c"))
local lpeg_src = os.files(path.join(skynet_dir, "3rd/lpeg/*.c"))
local md5_src = os.files(path.join(skynet_dir, "3rd/lua-md5/*.c"))

local cjson_src = {
    "lualib-src/lua-cjson/lua_cjson.c",
    "lualib-src/lua-cjson/strbuf.c",
}
local lfs_src = "lualib-src/luafilesystem/src/lfs.c"
local sha256_src = "lualib-src/lua-sha256/lua_sha256.c"
local jmlogger_src = "service-src/service_logger.c"

-- ---------------------------------------------------------------------------
-- 辅助函数
-- ---------------------------------------------------------------------------
local cloud_targets = {}

-- 把目标文件安装到指定目录(xmake install)
local function install_to(opt)
    local install_dir = opt.install
    if install_dir then
        on_install(function (target)
            os.mkdir(install_dir)
            os.cp(target:targetfile(), install_dir)
        end)
    end
end

-- 定义一个 skynet 风格的 lua C 模块(输出为 xxx.so, 无 lib 前缀)
local function add_module(name, srcfiles, outdir, opt)
    opt = opt or {}
    target(name)
        set_kind("shared")
        set_prefixname("")
        set_extension(".so")
        add_files(srcfiles)
        if opt.basename then
            set_basename(opt.basename)
        end
        if opt.defines then
            add_defines(opt.defines)
        end
        if opt.deps and #opt.deps > 0 then
            add_deps(opt.deps)
        end
        if opt.forceincludes then
            add_forceincludes(opt.forceincludes)
        end
        if opt.syslinks and #opt.syslinks > 0 then
            add_syslinks(opt.syslinks)
        end
        -- 导出 DLL 的全部符号
        add_rules("utils.symbols.export_all")
        -- 导入库统一输出到 build/lib
        set_targetdir(outdir, { libdir = path.relative(lib_dir, outdir) })
    install_to(opt)
    table.insert(cloud_targets, name)
end

local function add_binary(name, srcfiles, outdir, opt)
    opt = opt or {}
    target(name)
        set_kind("binary")
        add_files(srcfiles)
        if opt.defines then
            add_defines(opt.defines)
        end
        if opt.deps and #opt.deps > 0 then
            add_deps(opt.deps)
        end
        if opt.forceincludes then
            add_forceincludes(opt.forceincludes)
        end
        if opt.syslinks and #opt.syslinks > 0 then
            add_syslinks(opt.syslinks)
        end
        set_targetdir(outdir)
    install_to(opt)
    table.insert(cloud_targets, name)
end

-- ---------------------------------------------------------------------------
-- Windows
-- ---------------------------------------------------------------------------
if is_plat("windows") then
    set_toolchains("clang-cl")

    -- 新版 clang 默认把部分隐式转换当作 error, 与 skynet 旧代码不兼容
    add_cxflags("-Wno-int-conversion", "-Wno-implicit-function-declaration",
                "-Wno-deprecated-declarations", "-Wno-inconsistent-dllimport",
                "-Wno-macro-redefined")

    -- 不修改 skynet 源码: 通过 3rd/posix + 3rd/pthread-win32 提供 POSIX 兼容层
    add_defines("NOUSE_JEMALLOC")
    add_includedirs(
        path.join(skynet_dir, "3rd/lua"),
        path.join(skynet_dir, "skynet-src"),
        path.join(third_dir, "posix"),
        path.join(third_dir, "pthread-win32"))

    -- skynet 源码中有未显式 include <unistd.h> 的 POSIX 调用, 强制包含兼容层
    local unistd_h = path.join(third_dir, "posix/unistd.h")

    -- LUA_BUILD_AS_DLL: 从 liblua.dll 导入 lua 符号
    -- LUA_LIB:          目标自身定义 luaopen_* 入口时改为 dllexport
    local lua_import = { "LUA_BUILD_AS_DLL" }
    local lua_module = { "LUA_BUILD_AS_DLL", "LUA_LIB" }

    -- pthread-win32(静态库, 单文件 jumbo 编译)
    target("pthreadVC3")
        set_kind("static")
        add_files(path.join(third_dir, "pthread-win32/pthread-JMP.c"))
        add_includedirs(path.join(third_dir, "pthread-win32"))
        add_defines("PTW32_BUILD_INLINED", "PTW32_CLEANUP_C", "PTW32_STATIC_LIB",
                    "HAVE_CONFIG_H", "PTW32_RC_MSC")
        if is_arch("x86") then
            add_defines("PTW32_ARCHX86")
        else
            add_defines("PTW32_ARCHAMD64")
        end
        set_targetdir(lib_dir)
    -- 静态库仅用于链接, 不参与 xmake install
    on_install(function (target) end)
    table.insert(cloud_targets, "pthreadVC3")

    -- lua
    target("liblua")
        set_kind("shared")
        add_files(lua_lib_src)
        add_defines("LUA_BUILD_AS_DLL", "LUA_CORE", "LUA_LIB")
        add_rules("utils.symbols.export_all")
        set_targetdir(out_skynet_dir,
            { libdir = path.relative(lib_dir, out_skynet_dir) })
    install_to({ install = install_bin_dir })
    table.insert(cloud_targets, "liblua")

    add_binary("lua", path.join(skynet_dir, "3rd/lua/lua.c"), out_skynet_dir, {
        defines = lua_import,
        deps = { "liblua" },
        install = install_bin_dir,
    })

    -- POSIX 兼容层(含 wepoll 实现的 epoll)
    target("libposix")
        set_kind("shared")
        add_files(os.files(path.join(third_dir, "posix/*.c")))
        add_defines("POSIX_LIBRARY")
        add_syslinks("ws2_32")
        add_rules("utils.symbols.export_all")
        set_targetdir(out_skynet_dir,
            { libdir = path.relative(lib_dir, out_skynet_dir) })
    install_to({ install = install_bin_dir })
    table.insert(cloud_targets, "libposix")

    -- skynet 核心
    target("libskynet")
        set_kind("shared")
        add_files(skynet_src)
        add_defines(lua_import)
        add_forceincludes(unistd_h)
        add_deps("liblua", "libposix", "pthreadVC3")
        add_syslinks("ws2_32")
        add_rules("utils.symbols.export_all")
        set_targetdir(out_skynet_dir,
            { libdir = path.relative(lib_dir, out_skynet_dir) })
    install_to({ install = install_bin_dir })
    table.insert(cloud_targets, "libskynet")

    add_binary("skynet", path.join(skynet_dir, "skynet-src/skynet_main.c"),
        out_skynet_dir, {
            defines = lua_import,
            forceincludes = unistd_h,
            deps = { "libskynet" },
            install = install_bin_dir,
        })

    -- skynet 的 C 模块: skynet.so
    add_module("skynetso", skynet_lua_clib_src, out_skynet_luaclib_dir, {
        basename = "skynet",
        defines = lua_module,
        deps = { "libskynet", "libposix", "liblua" },
        syslinks = { "ws2_32" },
        forceincludes = unistd_h,
        install = install_skynet_luaclib_dir,
    })

    -- bson.so / md5.so / sproto.so / lpeg.so
    add_module("bson", path.join(skynet_dir, "lualib-src/lua-bson.c"),
        out_skynet_luaclib_dir, {
            defines = lua_module,
            deps = { "liblua" },
            syslinks = { "ws2_32" },
            install = install_skynet_luaclib_dir,
        })
    add_module("md5", md5_src, out_skynet_luaclib_dir, {
        defines = lua_module,
        deps = { "liblua" },
        install = install_skynet_luaclib_dir,
    })
    add_module("sproto", sproto_src, out_skynet_luaclib_dir, {
        defines = lua_module,
        deps = { "liblua" },
        install = install_skynet_luaclib_dir,
    })
    add_module("lpeg", lpeg_src, out_skynet_luaclib_dir, {
        defines = lua_module,
        deps = { "liblua" },
        install = install_skynet_luaclib_dir,
    })

    -- skynet 的 C 服务
    for _, src in ipairs(os.files(path.join(skynet_dir, "service-src/service_*.c"))) do
        local name = path.basename(src):gsub("^service_", "")
        add_module(name, src, out_skynet_cservice_dir, {
            defines = lua_import,
            deps = { "libskynet", "libposix", "liblua" },
            syslinks = { "ws2_32" },
            forceincludes = unistd_h,
            install = install_skynet_cservice_dir,
        })
    end

    -- 本项目的 lua C 模块
    add_module("cjson", cjson_src, out_luaclib_dir, {
        defines = { "LUA_BUILD_AS_DLL", "LUA_LIB", 'VERSION="1.0.3"' },
        deps = { "liblua" },
        forceincludes = unistd_h,
        install = install_luaclib_dir,
    })
    add_module("lfs", lfs_src, out_luaclib_dir, {
        defines = lua_module,
        deps = { "liblua" },
        install = install_luaclib_dir,
    })
    add_module("sha256", sha256_src, out_luaclib_dir, {
        defines = lua_module,
        deps = { "liblua" },
        install = install_luaclib_dir,
    })

    -- 本项目的 C 服务
    add_module("jmlogger", jmlogger_src, out_cservice_dir, {
        deps = { "libskynet", "libposix", "liblua" },
        syslinks = { "ws2_32" },
        install = install_cservice_dir,
    })
end
