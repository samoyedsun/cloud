local skynet = require "skynet"
local webapp = require "web.app"
local wsapp = require "gate.frontend.wsapp"
local jproto = require "jproto"
local proto = require "web.proto"
local web_util = require "utils.web_util"

local logger = log4.get_logger("frontend")
web_util.set_logger(logger)

local proto = proto:new(jproto.host)

proto:use("^error$", function ( ... )
    print(...)
    return false
end)

proto:use(".*", function (req, name, args, res)
    table.merge(res, { test = "is test rpc ", msg = "hello world"})
    return true
end)

proto:before(".*", web_util.before_log)
proto:after(".*", web_util.after_log)

webapp.after(".*", function (req, res)
    res.headers["Access-Control-Allow-Origin"] = "*"
    res.headers["Access-Control-Allow-Methods"] = "*"
    res.headers["Access-Control-Allow-Credentials"] = "true"
end)

webapp.post("^/voice$", function (req, res)
    local url = skynet.call(".voice", "lua", "post",req.query, req.body)
    res:json({code = 200, url = url})
    return false
end)

webapp.get("^/voice$", function (req, res)
    res.headers['Content-Type'] ='application/octet-stream'
    local voice = skynet.call(".voice", "lua", 'get', req.query)
    res.body = voice
    return false
end)

webapp.post("^/jproto$", function ( ... ) 
    proto:process(...) 
end)


webapp.use("^/ws$", function (...)
    wsapp.process(...)
end)

return webapp