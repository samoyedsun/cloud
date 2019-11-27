local code = require "server.config.code"

local skynet = require "skynet"
local REQUEST = {}

-- 查看是否登录
function REQUEST:gate_logon(msg)
    local logon = skynet.call(".logon", "lua", "is_logon", msg.uid)
    return {code = code.OK, logon = logon}
end

function REQUEST:gate_push(msg)
    local session = msg.session
    local agent = session.agent
    local fd = session.fd
    local name = msg.name
    local args = msg.msg
    skynet.send(agent, "lua", "emit", fd, "s2c", name, args)
    return {code = code.OK}
end

function REQUEST:gate_broadcast(msg)
    local name = msg.name
    local args = msg.msg
    skynet.send(".logon", "lua", "broadcast", name, args)
    return {code = code.OK}
end

return REQUEST