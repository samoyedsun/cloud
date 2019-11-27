local skynet = require "skynet"
local jproto = require "jproto"
local webapp = require "web.app"
local webproto = require "web.proto"
local web_util = require "utils.web_util"
local wsapp = require "server.frontend.wsapp"
local user = require "server.frontend.request.web_user"
local logger = log4.get_logger("server_frontend_webapp")
web_util.set_logger(logger)

local webproto = webproto:new(jproto.host)

webproto:use("error", function ( ... )
    print(...)
    return false
end)

webproto:use(".*", function (req, name, args, res)
    table.merge(res, { test = "is test rpc ", msg = "hello world"})
    return true
end)

webproto:before(".*", web_util.before_log)
webproto:after(".*", web_util.after_log)

--------------------------------------------------------------
webapp.before(".*", function (req, res)
    res.headers["Access-Control-Allow-Origin"] = "*"
    res.headers["Access-Control-Allow-Methods"] = "*"
    res.headers["Access-Control-Allow-Credentials"] = "true"
    return true
end)
webapp.before(".*", function(req, res)
    logger.debug("before web req %s body %s", tostring(req.url), tostring(req.body))
    return true
end)

webapp.use("^/game/:name$",function (req, res)
    res:json(game.request(req))
    return true
end)
webapp.use("^/gate/:name$", function (req, res)
    res:json(gate.request(req))
    return true
end)
webapp.use("^/user/:name$", function (req, res)
    res:json(user.request(req))
    return true
end)

webapp.post("^/jproto$", function ( ... )
    webproto:process(...)
end)
webapp.use("^/ws$", function (...)
    wsapp.process(...)
end)

webapp.after(".*", function(req, res)
    logger.debug("after web req %s body %s res body %s", tostring(req.url), tostring(req.body), tostring(res.body))
    return true
end)

webapp.static("^/static/*", "./server/")

return webapp