local skynet = require "skynet"
local httpc = require "http.httpc"
local webapp = require "web.app"
local jproto = require "jproto"
local proto = require "web.proto"
local web_util = require "utils.web_util"
local gate = require "node.frontend.request.gate"

local logger = log4.get_logger("frontend")
web_util.set_logger(logger)

local proto = proto:new(jproto.host)

proto:use("^error$", function (req, ... )
    logger.error("webapp proto %s", tostring({...}))
    return false
end)

proto:use(".*", function (req, name, args, res)
    table.merge(res, { test = "is test rpc ", msg = "hello world"})
    return true
end)


proto:before(".*", web_util.before_log)
proto:after(".*", web_util.after_log)

webapp.post("^/jproto$", function ( ... )
    proto:process(...)
end)

-- 退出进程接口，开发用, 方便客户端重启游戏服务
webapp.get("^/exit$", function (req, res)
    if not IS_DEBUG then
        res:json("not debug")
        return true
    end
    skynet.fork(function ( ... )
        skynet.sleep(300)
        os.exit()
    end)
    res:json("restart wait 3 sleep ...")
    return true
end)

-- 获取网关地址
webapp.use("^/gate$", function (req, res)
    local msg
    if req.query and req.query.uid then
        msg = req.query
    else
        msg = cjson_decode(req.body)
    end
    local ret = gate.get_gate(req, msg)
    res:json(ret)
    return true
end)

webapp.use("^/test_cjson1$", function (req, res)
    local ret = {}
    res:json(ret)
    return true
end)

webapp.use("^/test_cjson2$", function (req, res)
    local ret = {}
    cjson_default_parse_by_array_mode(ret)
    res:json(ret)
    return true
end)

-- TODO：测试头像
webapp.get("^/image", function (req, res)
    local host = "pic.wenwen.soso.com"
    local url = "/p/20110718/20110718210301-2022177829.jpg"
    local recvheader = {}
    local statecode, body = httpc.get(host, url, recvheader)
    recvheader["connection"] = nil
    table.merge(res.headers, recvheader)
    res.body = body
    return true
end)

webapp.static("^/static/*", "./examples/node/")

webapp.before(".*", function (req, res)
    res.headers["Access-Control-Allow-Origin"] = "*"
    res.headers["Access-Control-Allow-Methods"] = "*"
    res.headers["Access-Control-Allow-Credentials"] = "true"
    return true
end)

return webapp
