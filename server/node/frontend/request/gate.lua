local skynet = require "skynet"
local etcd_util = require "utils.etcd_util"
local etcd = require "etcd"
local code = require "code"

local logger = log4.get_logger("gate")
local logon_logger = log4.get_logger("logon")

local REQUEST = {}

-- 获得玩家节点位置
local function router_gate(uid)
    local dirname = "/mj/gates/"
    local result_list = etcd_util.call_dir_multi(dirname, "gate_logon", {uid = uid})
    if #result_list == 0 then
        return
    end

    local fail_list = {}
    for _, v in ipairs(result_list) do 
        if v.ok and v.ret and v.logon then
            logger.info("uid %s is logon %s", uid, v.nodename)
            return v.nodename
        elseif not v.ok then
            logger.error("rpc call %s error %s", v.nodename, tostring(res))
            table.insert(fail_list, v)
        end
    end

    local tmp = {}
    for _, v in ipairs(result_list) do
        if not table.member(fail_list, v) then
            table.insert(tmp, v)
        end
    end
    if #tmp == 0 then
        return
    end
    result_list = tmp
    table.sort(result_list, function (v1, v2)
        return v1.nodename > v2.nodename
    end)

    local idx = uid % #result_list + 1
    return result_list[idx].nodename
end

-- 获取gate服务的地址
function REQUEST:get_gate(msg)
    local nodename = router_gate(tonumber(msg.uid))
    if not nodename then
        local err = code.name(code.SERVICE_UNAVAILABLE)
        return {code = code.SERVICE_UNAVAILABLE, err = err}  -- 没有可用gate服务器
    end

    local ok, cf = etcd.get(nodename)
    if not ok then
        local err = code.name(code.SERVICE_UNAVAILABLE)
        return {code = code.SERVICE_UNAVAILABLE, err = err}  -- 没有可用gate服务器
    end

    local cf = cjson_decode(cf)
    local frontend = cf.frontend
    local ret = {
        code        = code.OK, 
        type        = frontend.type, 
        ip          = frontend.ip, 
        port        = frontend.port, 
        ws          = frontend.ws,
        nodename    = nodename,
    }
    logon_logger.info("uid=%s,type=%s,ip=%s,port=%s,ws=%s,nodename=%s;addr=%s", 
        msg.uid, ret.type, ret.ip, ret.port, ret.ws, ret.nodename, self.ip)
    return ret
end

return REQUEST