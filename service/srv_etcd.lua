local skynet = require "skynet"
local etcdhost = skynet.getenv("etcdhost")
local jproto = require "jproto"
local httpc = require "http.httpc"
local socket_client = require "socket.client"

local NODE_TO_CF = {}
local NODE_TO_CLIENT = {}


function jproto_send_request(host, name, msg)
    local session = 0
    local body = jproto.host_request(name, msg, session)
    local url = "/jproto"
    local statscode, res = httpc.request("POST", host, url, nil, nil, body)
    local type, session, args = jproto.host:dispatch(res)
    if type == "REQUEST" then
        skynet.error("error proto send request")
        return 
    end
    return args
end

local function open_socket_client(node, cf)
    if NODE_TO_CLIENT[node] then
        return
    end
    local backend = cf.backend

    local client = socket_client:new(jproto.host, jproto.host_request)
    if not client:open(backend.ip, backend.port) then
        return
    end
    client:on("error", function ( ... )
        skynet.error(...)           -- TODO
    end)
    skynet.fork(function ()
        client:dispatch()
    end)
    NODE_TO_CLIENT[node] = client
end


local CMD = {}



function CMD.etcd(cmd, ...)
    local file, content = ...
    local ok, res = pcall(jproto_send_request, etcdhost, cmd, {file = file, content = content})
    if not ok then
        return ok, "etcd send_request fail" 
    end
    return res.ok, res.result
end


function CMD.req(node, name, args)
    local cf = NODE_TO_CF[node]
    if not cf then
        CMD.open(node)
        cf = NODE_TO_CF[node]
    end
    if not cf then
        return false, "not such node ".. node
    end
    if not cf.backend then
        return false, "not backend node ".. node
    end

    local backend = cf.backend
    if backend.type == "socket" then
        local client = NODE_TO_CLIENT[node]
        if not client then
            NODE_TO_CLIENT[node] = nil
            NODE_TO_CF[node] = nil
            return false, "not socket client"
        end
        local ok, res = client:call(name, args)
        if not ok then
            NODE_TO_CLIENT[node] = nil
            NODE_TO_CF[node] = nil
        end
        return ok, res
    end

    local host = string.format("%s:%s", backend.ip, backend.port)
    local res = jproto_send_request(host, name, args)
    if not res then
        return false, "not return msg"
    end
    return true, res
end



function CMD.open(node)
    local ok, cf = CMD.etcd("get", node)
    if not ok then
        return
    end
    cf = cjson_decode(cf)
    if cf.backend and cf.backend.type == "socket" then
        open_socket_client(node, cf)
    end
    NODE_TO_CF[node] = cf
    return true
end

skynet.start(function ( ... )
    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if not f then
            if session ~= 0 then
                skynet.ret(skynet.pack(nil))
            end
            return
        end
        if session == 0 then
            return f(...)
        end
        skynet.ret(skynet.pack(f(...)))
    end)
end)