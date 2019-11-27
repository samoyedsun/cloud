local skynet = require "skynet"
local webapp = require "web.app"
local jproto = require "jproto"
local proto = require "web.proto"
local gate = require "server.backend.request.gate"
local test = require "server.backend.request.test"
local web_util = require "utils.web_util"

local logger = log4.get_logger("backend")
web_util.set_logger(logger)

local proto = proto:new(jproto.host)

proto:use("^error$", function ( ... )
    print(...)
    return false
end)

proto:use("^gate_*", function (req, name, args, res)
    if gate[name] then
        local r = gate[name](req, args)
        table.merge(res, r)
    end
    return true
end)

proto:use("^test_*", function (req, name, args, res)
    if test[name] then
        local r = test[name](req, args)
        table.merge(res, r)
    end
    return true
end)

-- proto:before(".*", web_util.before_log)
-- proto:after(".*", web_util.after_log)

webapp.post("^/jproto$", function ( ... ) 
    proto:process(...) 
end)

return webapp