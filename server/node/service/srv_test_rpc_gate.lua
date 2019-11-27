local skynet = require "skynet"
local etcd_util = require "utils.etcd_util"
local etcd = require "etcd"

local function test_call_dir_multi( )
    local dirname = "/mj/gates/"
    local result_list = etcd_util.call_dir_multi(dirname, "test_hello", { from = "node", to = "gate"})
    print("call_dir_multi /mj/gates/", result_list)
end

local function test_call_gate( )
    local nodename = "/mj/gates/gate1"
    local rpc = etcd.open(nodename)
    local ok, ret = rpc:call("test_hello", { from = "node", to = "gate"})
    print("rpc call /mj/gates/gate1", ok, ret)
end

skynet.start(function ( ... )
    test_call_dir_multi()
    test_call_gate()
    skynet.exit()
end)