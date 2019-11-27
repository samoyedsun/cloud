local skynet = require "skynet"
local webapp = require "web.app"
local jproto = require "jproto"
local proto = require "web.proto"
local web_util = require "utils.web_util"
local etcd = require "node.backend.request.etcd"

local logger = log4.get_logger("backend")
web_util.set_logger(logger)

local proto = proto:new(jproto.host)

proto:use("^error$", function ( ... )
    print(...)
    return false
end)

proto:use(".*", function (req, name, args, res)
    if etcd[name] then
        local r = etcd[name](req, args)
        table.merge(res, r)
    end
    return true
end)

-- logger
-- proto:before(".*", web_util.before_log)
-- proto:after(".*", web_util.after_log)


webapp.post("^/jproto$", function ( ... ) 
    proto:process(...) 
end)

return webapp