local skynet = require "skynet"

local logger = log4.get_logger(SERVICE_NAME)
-- 模拟一个etcd 配置服务器， 以后替换成真正的etcd
local REG = {               -- 根目录
    type = "dir",
    ctime = skynet_time(),
    child = {}
}

local WATCH = {}

local WAKEUP = {}

local CMD = {}

local function path_split(file)
    local paths = string.split(file, "/")
    if #paths == 0 then
        return paths
    end
    if paths[1] == "" then
        table.remove(paths, 1)
    end
    if paths[#paths] == "" then
        table.remove(paths, #paths) 
    end
    return paths
end

local function add_watch(file)
    local paths = path_split(file)
    file = "/" .. table.concat(paths, "/")
    local co = coroutine.running()
    if not WATCH[file] then
        WATCH[file] = {}
    end
    local watch = WATCH[file]
    table.insert(watch, co)
    skynet.wait()
    local event = WAKEUP[co]
    WAKEUP[co] = nil
    return event
end

function wakeup_watch(file, event)
    for k, watch in pairs(WATCH) do 
        if string.find(file, k) then
            for _, co in ipairs(watch) do 
                WAKEUP[co] = event
                skynet.wakeup(co)
            end
            WATCH[k] = nil
        end
    end
end

function CMD.mkdir(file)
    local paths = path_split(file)
    local dir = REG 
    local way = {}
    for _,key in ipairs(paths) do 
        table.insert(way, key)
        if not dir.child[key] then
            local d = {type = "dir", child = {}, ctime = skynet_time()}
            dir.child[key] = d
        end
        local d = dir.child[key]
        if d.type ~= "dir" then
            return false, "mkdir:" .. table.concat(way, "/") .. " Not a directory" 
        end
        dir = d
    end
    wakeup_watch(file, "mkdir")
    return true
end

function CMD.set(file, cf)
    local path = file
    local paths = path_split(file)
    local dir = REG
    local length = #paths
    local parent 
    for k, key in ipairs(paths) do 
        if not dir.child[key] then
            return false, "No such file or directory"
        end
        local file = dir.child[key]
        if file.type ~= "dir" then
            return false, "No such file or directory"
        end

        if k + 1 == length then --  倒数第一个目录
            parent = file
            break
        end
        dir = dir.child[key]
    end
    if not parent or parent.type ~= "dir" then
        return false, "No such file or directory"
    end
    local key = paths[#paths]
    local file = parent.child[key]
    if file and file.type ~= "file" then
        return false, "No such file or directory"
    end

    if file and file.type == "file" then
        file.mtime = skynet_time()
        file.content = cf
    else
        local file = {type = "file", ctime = skynet_time(), content = cf}
        parent.child[key] = file  
    end
    wakeup_watch(path, "set")
    return true
end

function CMD.get(file)
    local paths = path_split(file)
    local dir = REG
    local length = #paths
    local parent 
    for k, key in ipairs(paths) do 
        if not dir.child[key] then
            return false, "No such file or directory"
        end
        local file = dir.child[key]
        if file.type ~= "dir" then
            return false, "No such file or directory"
        end
        
        if k + 1 == length then --  倒数第一个目录
            parent = file
            break
        end
        dir = dir.child[key]
    end
    if not parent or parent.type ~= "dir" then
        return false, "No such file or directory"
    end
    local key = paths[#paths]
    local file = parent.child[key]
    if not file or file.type ~= "file" then
        return false, "No such file or directory"
    end

    file.atime = skynet_time()
    return true, file.content
end

function CMD.rm(file)
    local path = file
    local paths = path_split(file)
    local dir = REG
    local length = #paths
    local parent 
    for k, key in ipairs(paths) do 
        if not dir.child[key] then
            return false, "No such file or directory"
        end
        local file = dir.child[key]
        if file.type ~= "dir" then
            return false, "No such file or directory"
        end
        
        if k + 1 == length then --  倒数第一个目录
            parent = file
            break
        end
        dir = dir.child[key]
    end
    if not parent then
        return false, "No such file or directory"
    end
    local key = paths[#paths] 
    local file = parent.child[key]
    if not file then
        return false, "No such file or directory"
    end
    if file.type == "dir" and next(file.child) then
        return false, "is a directory not empty"
    end
    parent.child[key] = nil
    wakeup_watch(path, "rm")
    return true
end

function CMD.lsdir(dir)
    local paths = path_split(dir)
    local dir = REG
    local length = #paths
    if length == 0 then             --  根目录
        local dir_child = {}
        for name, v in pairs(dir.child) do 
            table.insert(dir_child, {type = v.type, name = name})
        end
        return true, dir_child
    end

    for k, key in ipairs(paths) do 
        if not dir.child[key] then
            return false, "No such file or directory"
        end
        local d = dir.child[key]
        if d.type ~= "dir" then
            return false, "No such file or directory"
        end

        if k == length then
            local dir_child = {}
            for name, v in pairs(d.child) do 
                table.insert(dir_child, {type = v.type, name = name})
            end
            return true, dir_child
        end
        dir = d
    end
    return false, "No such file or directory"
end

function CMD.watch(file)
    local event = add_watch(file)
    return true, event
end

local file_to_ttl = {}

function CMD.ttl(file, time)
    local t = file_to_ttl[file]
    if t then
        t.delete()
        file_to_ttl[file] = nil
    end
    file_to_ttl[file] = create_timeout(time, function ()
        CMD.rm(file)
    end)
    return true
end

function CMD.info( ... )
    logger.info("file %s", tostring(REG))
    return REG
end

skynet.start(function ( ... )
    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if not f then
            if session ~= 0 then
                skynet.ret(skynet.pack(nil))
            end
            return
        end
        if session == 0 then
            return f(...)
        end
        skynet.ret(skynet.pack(f(...)))
    end)
end)