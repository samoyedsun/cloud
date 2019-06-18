local codecache = require "skynet.codecache"
local skynet = require "skynet"
local snax = require "skynet.snax"
local mode = ...

local reboot_service = {}            -- 可重启更新service, {type, handle, service_name, register, {...}}
local hotfix_service = {}            -- 不重启，通过热更新服务, {type, handle, service_name, register, {...}}




local function update_hotfix_service()
    for k, v in ipairs(hotfix_service) do 
        local handle = v[2]
        local ok 
        if type(handle) == "number" then
            ok = pcall(skynet.call, handle, "lua", "update")
        else
            ok = pcall(handle.req.update)
        end
    end
end

local function start_service(type, service_name, ...)
    local handle
    if type == "skynet" then
        handle = skynet.newservice(service_name, ...)
    elseif type == "snax" then
        handle = snax.newservice(service_name, ...)
    elseif type == "snaxunique" then
        handle = snax.uniqueservice(service_name, ...)
    elseif type == "skynetunique" then
        handle = skynet.uniqueservice(service_name, ...)
    end
    return handle
end

local function update_reboot_service()
    local reboot = {}
    for k, v in ipairs(reboot_service) do 
        local handle = start_service(v[1], v[3], table.unpack(v[4]))
        local tmp_handle = v[2]
        v[2] = handle
        if type(tmp_handle) == "number" then
            skynet.kill(tmp_handle)
        else
            snax.kill(tmp_handle)
        end
        table.insert(reboot, v)
    end
    reboot_service = reboot
end


local CMD = {}

-- 更新服务
function CMD.update()
    codecache.clear()               -- 更新代码
    update_reboot_service()
    update_hotfix_service()
end



function CMD.start_hotfix_service(_type, service_name, ...)
    local handle = start_service(_type, service_name, ...)
    if not handle then
        return
    end
    table.insert(hotfix_service, {_type, handle, service_name, {...}})

    if type(handle) ~= "number" then
        return handle.handle
    end
    return handle
end

function CMD.start_reboot_service(_type, service_name, ...)
    local handle = start_service(_type, service_name, register, ...)
    if not handle then
        return
    end
    table.insert(reboot_service, {_type, handle, service_name,  {...}})
    if type(handle) ~= "number" then
        return handle.handle
    end
    return handle
end

if mode == "master" then
    skynet.start(function ()
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
else
    local args = {...}
    skynet.start(function()
        local handle = skynet.uniqueservice("srv_hotfix", "master")
        skynet.call(handle, "lua", table.unpack(args))
        skynet.exit()
    end)
end