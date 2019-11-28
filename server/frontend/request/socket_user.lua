local code = require "server.config.code"
local skynet = require "skynet"
local logger = log4.get_logger("server_frontend_request_socket_user")

local REQUEST = {}

function REQUEST:user_auth(msg)
    local uid = msg.uid
    local token = msg.token
    local platform = msg.platform
    local reconnection = msg.reconnection
    if type(uid) ~= "number" or
        type(token) ~= "string" or
        type(platform) ~= "string" then
        return {code = code.ERROR_CLIENT_PARAMETER_TYPE, err = code.ERROR_CLIENT_PARAMETER_TYPE_MSG}
    end

    self.session.auth = true
    self.session.uid = uid
    return {code = code.SUCCEED, err = code.SUCCEED_MSG}
end

function REQUEST:user_info(msg)
    local uid = msg.uid
    if type(uid) ~= "number" then
        return {code = code.ERROR_CLIENT_PARAMETER_TYPE, err = code.ERROR_CLIENT_PARAMETER_TYPE_MSG}
    end
    local data = {
        uid = self.session.uid,
        fd = self.session.fd,
        agent = self.session.agent,
        addr = self.session.addr,
        ip = self.session.ip
    }
    return {code = code.SUCCEED, err = code.SUCCEED_MSG, data = data}
end

function REQUEST:user_heartbeat(msg)
    return {code = code.SUCCEED, err = code.SUCCEED_MSG}
end

local root = {}

function root:request(name, msg)
    if not REQUEST[name] then
        return {code = code.ERROR_NAME_UNFOUND, err = code.ERROR_NAME_UNFOUND_MSG}
    end

    local trace_err = ""
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    local ok, res = xpcall(REQUEST[name], trace, self, msg)
    if not ok then
        logger.error("%s %s %s", name, tostring(msg), trace_err)
        return {code = code.ERROR_INTERNAL_SERVER, err = code.ERROR_INTERNAL_SERVER_MSG}
    end
    return res
end

return root