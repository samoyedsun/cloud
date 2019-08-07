local skynet = require "skynet"
local etcd = require "etcd"
local root = {}

function root.call_dir_multi(dirname, name, msg)
    local ok, server_list = etcd.lsdir(dirname)
    if not ok then
        return ok, server_list
    end

    local result_list = {}
    local current_thread = coroutine.running()
    for _, v in ipairs(server_list) do            -- 先查看是否有已登录的gate服务
        skynet.fork(function ()
            local nodename = dirname .. v.name 
            local rpc = etcd.open(nodename)
            local ok, ret = rpc:call(name, msg)
            table.insert(result_list, {ok = ok, ret = ret, nodename = nodename})
            if #result_list == #server_list then
                skynet.wakeup(current_thread)
            end
        end)
    end

    if #server_list ~= 0 then
        skynet.wait()
    end
    return result_list
end

-- {{nodename = xx, name = , msg = }, ...}
function root.call_multi(call_list)
    local result_list = {}
    local current_thread = coroutine.running()
    local ret_count = 0
    local __call = function (index, v)
        return function ()
            local rpc = etcd.open(v.nodename)
            local ok, ret = rpc:call(v.name, v.msg)
            result_list[index] = {ok = ok, ret = ret}
            ret_count = ret_count + 1
            if ret_count == #call_list then
                skynet.wakeup(current_thread)
            end
        end
    end
    
    for k, v in ipairs(call_list) do 
        skynet.fork(__call(k, v))      
    end

    if #call_list ~= 0 then
        skynet.wait()
    end
    return result_list
end

return root
