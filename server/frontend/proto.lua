local skynet = require "skynet"
local proto = require "socket.proto"
local sproto = require "sproto"
local etcd = require "etcd"
local code = require "server.config.code"
local jproto = require "jproto"
local user = require "server.frontend.request.user"


-- local host = sproto.parse(gate_proto.c2s):host "package"
-- local host_request = host:attach(sproto.parse(gate_proto.s2c))
-- proto.configure(host, host_request)

-- 设置客户端消息序列化和反序列化方法
proto.configure(jproto.host, jproto.host_request)

local logger = log4.get_logger("proto")

-- access log
proto.c2s_before(".*", function (self, name, args, res)
    if IS_DEBUG then
        -- logger.debug("c2s access %s %s %s", tostring(self.session), name, tostring(args))
    end
    return true
end)

-- auth, 过滤未验证权限请求
proto.c2s_before(".*", function (self, name, args, res)
    if self.session.auth then
        return true
    end
    if name == "user_auth" then  
        return true
    end
    table.merge(res, {code = 400, err = "not auth"})
    skynet.yield()
    self:emit("kick")   -- 踢下线
    return false
end)

-- access after log
proto.c2s_after(".*", function (self, name, args, res)
    local session = self.session
    if IS_DEBUG then
        logger.debug("c2s after %s %s %s %s", tostring(session), name, tostring(args), tostring(res))
    end
end)

proto.s2c_after(".*", function (self, name, args)
    local session = self.session
    if IS_DEBUG then
        if name == "heartbeat" then
            return
        end
        logger.debug("s2c after %s %s %s", tostring(session), name, tostring(args))
    end
end)

proto.c2s_use("^user_*", function (self, name, args, res)
    if user[name] then
        local r = user[name](self, args)
        table.merge(res, r)
    end
    return true
end)


return proto