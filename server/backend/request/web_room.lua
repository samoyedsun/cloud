local skynet = require "skynet"
local code = require "server.config.code"
local logger = log4.get_logger("server_backend_request_web_room")

local REQUEST = {}

function REQUEST:stop_operations(msg)
    return {code = code.SUCCEED, err = code.SUCCEED_MSG}
end

function REQUEST:open_operations(msg)
    return {code = code.SUCCEED, err = code.SUCCEED_MSG}
end

function REQUEST:sync_block_data(msg)
    local block_data = msg.block_data
    local channel = msg.channel
    if type(channel) ~= "string" or
        type(block_data) ~= "string" then
        return {code = code.ERROR_CLIENT_PARAMETER_TYPE, err = code.ERROR_CLIENT_PARAMETER_TYPE_MSG}
    end
    return {code = code.SUCCEED, err = code.SUCCEED_MSG, data = data}
end

local root = {}

function root.request(req)
    local name = req.params.name
    if not REQUEST[name] then
        return {code = code.ERROR_NAME_UNFOUND, err = code.ERROR_NAME_UNFOUND_MSG}
    end
    local msg
    if req.method == "GET" then
        msg = req.query
    else
        msg = cjson_decode(req.body)
    end
    local trace_err = ""
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    local ok, res = xpcall(REQUEST[name], trace, req, msg)
    if not ok then
        logger.error("%s %s %s", req.path, tostring(msg), trace_err)
        return {code = code.ERROR_INTERNAL_SERVER, err = code.ERROR_INTERNAL_SERVER_MSG}
    end
    return res
end

return root