local skynet = require "skynet"

local etcd
local root = {}

local rpc = {}

function rpc:new(node)
    local o = {
        node = node,
    }
    setmetatable(o, {__index=rpc})
    return o
end

function rpc:send(name, args)
    skynet.send(etcd, "lua", "req", self.node, name, args)
end

function rpc:call(name, args)
    return skynet.call(etcd, "lua", "req", self.node, name, args)
end

-- 观察节点是否已更改
function rpc:watch()
    return skynet.call(etcd, "lua", "etcd", "watch", self.node, name, args)
end

function root.lsdir(path)
    return skynet.call(etcd, "lua", "etcd", "lsdir", path)
end

function root.set(file, content)
    return skynet.call(etcd, "lua", "etcd", "set", file, content)
end

function root.rm(file)
    return skynet.call(etcd, "lua", "etcd", "rm", file)
end

function root.get(file)
    return skynet.call(etcd, "lua", "etcd", "get", file)
end

function root.open(file)
    return rpc:new(file)
end

function root.ttl(file, time)
    return skynet.call(etcd, "lua", "etcd", "ttl", file, time)
end


skynet.init(function ( )
    etcd = skynet.uniqueservice("srv_etcd")
end)

return root