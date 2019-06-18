local lfs = require("lfs")
local hotfix = require("hotfix")

local global_objects = {
    arg,
    assert,
    bit32,
    collectgarbage,
    coroutine,
    debug,
    dofile,
    error,
    getmetatable,
    io,
    ipairs,
    lfs,
    load,
    loadfile,
    loadstring,
    math,
    module,
    next,
    os,
    package,
    pairs,
    pcall,
    print,
    rawequal,
    rawget,
    rawlen,
    rawset,
    require,
    select,
    setmetatable,
    string,
    table,
    tonumber,
    tostring,
    type,
    unpack,
    utf8,
    xpcall,
}

local M = { }
local PATH_TO_TIME = { }
local MOD_NAME 
local ROOT_DIR
local logger
local package_loaded = {}

-- 查找此文件被loaded的的模块名
local function find_package_loaded(path)
    if not string.find(path, ".lua", 1, true) then
        return
    end
    local module_name 
    local find_module = string.gsub(path, "/", ".")
    for _, v in ipairs(package_loaded) do 
        if string.find(find_module, v, 1, true) then
            module_name = v
            break
        end
    end
    if not module_name then
        return
    end

    local file_path = package.searchpath(module_name, package.path)
    if path == file_path then
        return module_name
    end
end

-- 遍历文件夹
local function each_dir(dir, attr, callback)
    if not lfs.attributes(dir) then
        logger.debug("not such dir %s", dir)
        return
    end
    for file in lfs.dir(dir) do 
        if file ~= "." and file ~= ".." then
            local path = dir .. "/" .. file
            local file_attr = lfs.attributes(path)
            if file_attr.mode == "file" then
                local module_name = find_package_loaded(path)
                if module_name then
                    callback(module_name, path, file_attr.modification, attr)
                end
            elseif file_attr.mode == "directory" then
                each_dir(dir .. "/" .. file, attr, callback)
            end
        end
    end
end

-- callback(module_name, module_file_path, file_modification_time)
local function each_module(callback)
    local path = package.searchpath(MOD_NAME, package.path)
    if not path then 
        logger.warn("not hotfix_module %s", MOD_NAME)
        return 
    end
    package.loaded[MOD_NAME] = nil
    local module_names = require(MOD_NAME)

    for _, cf in pairs(module_names) do
        local module_name, attr = table.unpack(cf)
        if attr == "dc" or attr == "df" then
            each_dir(ROOT_DIR .. string.gsub(module_name, "%.","/") , attr, callback)
        else
            local path, err = package.searchpath(module_name, package.path)
            -- Skip non-exist module.
            if not path then
                callback(module_name)
            else
                local file_time = lfs.attributes(path, "modification")
                callback(module_name, path, file_time, attr)
            end
        end
    end
end

function M.check()
    package_loaded = {}
    for name,_ in pairs(package.loaded) do
        table.insert(package_loaded, name)
    end
    each_module(function (name, path, file_time, attr)
        if not package.loaded[name] then
            logger.debug("check path %s %s not reqiure ", path, name)
            return
        elseif not path then
            logger.warn("check % not such module", name)
            return
        elseif PATH_TO_TIME[path] == file_time then
            logger.info("check %s %s not modification", name, path)
            return
        end
        PATH_TO_TIME[path] = file_time
        local replace = false
        if attr == "dc" or attr == "c" then
            replace = true
        end
        hotfix.hotfix_module(name, replace)
    end)
end

function M.init(root_dir, hotfix_module)
    logger = lib_logger.get_logger("hotfix")
    package_loaded = {}
    for name,_ in pairs(package.loaded) do
        table.insert(package_loaded, name)
    end
    hotfix.log_debug = logger.debug
    hotfix.log_info = logger.info
    hotfix.log_error = logger.erro
    hotfix.add_protect(global_objects)
    MOD_NAME = hotfix_module
    ROOT_DIR = root_dir

    each_module(function (name, path, file_time, attr)
        if not path then
            logger.warn("init no such module: %s", name)
            return
        end
        logger.debug("name:%s path:%s mod:%s attr:%s", name, path, os.date("%Y-%m-%d %H:%M:%S", file_time), attr)
        PATH_TO_TIME[path] = file_time      -- 初始化模块修改时间
    end)
end

return M
