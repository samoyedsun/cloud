local code = require "code"

local skynet = require "skynet"
local REQUEST = {}

function REQUEST:test_hello(msg)
    return {code = code.OK, time = skynet_time(), msg = msg}
end

return REQUEST