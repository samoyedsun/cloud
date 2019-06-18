--[[
时间：2017年 3月 6日 星期一 14时46分30秒
作者：lgc

用JSON 序列化和反序列化 消息
接口模仿sproto

]]

local root = {}

local TYPE = {
    q = "REQUEST",
    s = "RESPONSE",
}

local host = {}
root.host = host

function host:dispatch(data, sz)
    local type, name, args, response 
    local msg = cjson_decode(data)
    type = TYPE[msg.t]
    if not type then
        return  "UNKNON"
    end
    if type == "RESPONSE" then
        return type, msg.s, msg.d
    end
    local session = msg.s
    name = msg.n
    args = msg.d
    if not session then
        return type, name, args
    end
    response = function (s)
        local msg = {
            t = "s",
            s = session,
            d = s
        }
        return cjson_encode(msg)
    end
    return type, name, args, response
end


function root.host_request(name, msg, session)
    local req = {
        t = "q",
        s = session,
        n = name, 
        d = msg,
    }
    return cjson_encode(req)
end

return root