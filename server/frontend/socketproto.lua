local skynet = require "skynet"
local sproto = require "sproto"
local jproto = require "jproto"
local socketproto = require "socket.proto"
local code = require "server.config.code"
local user = require "server.frontend.request.socket_user"
local logger = log4.get_logger("server_frontend_socketproto")

-- local host = sproto.parse(gate_proto.c2s):host "package"
-- local host_request = host:attach(sproto.parse(gate_proto.s2c))
-- proto.configure(host, host_request)

-- 设置客户端消息序列化和反序列化方法
socketproto.configure(jproto.host, jproto.host_request)

socketproto.c2s_before(".*", function (self, name, args, res)
    if (name == "user_auth") or self.session.auth then
        return true
    end
    create_timeout(3 * 100, function(s) self:emit("kick") end)
    table.merge(res, {code = code.ERROR_USER_UNAUTH, err = code.ERROR_USER_UNAUTH_MSG})
    return false
end)

socketproto.c2s_use("^user_*", function (self, name, args, res)
    table.merge(res, user.request(self, name, args))
    return true
end)

socketproto.c2s_after(".*", function (self, name, args, res)
    logger.debug("c2s after %s %s %s %s", "hello", name, tostring(args), "a lot data")
end)

return socketproto
