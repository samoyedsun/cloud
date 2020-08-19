local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local proto = require "server.frontend.socketproto"
local app = require "server.frontend.socketapp"
local websocket = require "http.websocket"

local CMD = {}
local SOCKET_TO_CLIENT = {}

function CMD.close(fd, reason)
    local client = SOCKET_TO_CLIENT[fd]
    SOCKET_TO_CLIENT[fd] = nil
    if not client then
        return
    end
    client:emit("close", reason)        -- 清理工作
end

function CMD.emit(fd, ...)
    local client = SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    client:emit(...)
end

function CMD.info()
    for k, v in pairs(SOCKET_TO_CLIENT) do 
        skynet.error(string.format("fd %s to client session %s", k, tostring(v.session)))
    end
end


function CMD.exit()
    for k, v in pairs(SOCKET_TO_CLIENT) do 
        v:emit("kick")
    end
end

-- 注册 srv_web_agent CMD.xxx
for cmd, p in pairs(CMD) do 
   add_web_agent_cmd(cmd, p)
end

function app:close(fd, reason)
    local client = SOCKET_TO_CLIENT[fd]
    SOCKET_TO_CLIENT[fd] = nil
    if not client then
        return
    end
    client:emit("close", reason)        -- 清理工作
end

--- overide 重载 send_package
function proto.send_package(fd, package)
    local client = SOCKET_TO_CLIENT[fd] 
    if not client then
        return false, "close"
    end
    websocket.write(fd, package)
    return true, "ok"
end


-- websocket回调方法
local handle = {}

function handle.connect(fd)
    skynet.error(string.format("ws connect from: %s", tostring(fd)))
end

function handle.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    skynet.error(string.format("ws handshake from: %s, url: %s, addr: %s", tostring(fd), url, addr))
    skynet.error("----header-----")
    for k,v in pairs(header) do
        skynet.error(string.format("k:%s, v:%s", tostring(k), tostring(v)))
    end
    skynet.error("--------------")
    local client = app:new()
    SOCKET_TO_CLIENT[fd] = client
    local ip = addr:match("([^:]+):?(%d*)$")
    local session = {fd = fd, agent = skynet.self(), addr = addr, ip = ip}
    client:emit("start", session)
end

function handle.message(fd, msg, msg_type)
    assert(msg_type == "text")
    local client = SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    client:emit("c2s", msg, #msg)
end

function handle.ping(fd)
    skynet.error(string.format("ws ping from: %s", tostring(fd)))
end

function handle.pong(fd)
    skynet.error(string.format("ws pong from: %s", tostring(fd)))
end

function handle.close(fd, code, reason)
    skynet.error(string.format("ws close from: %s, code: %s, reason: %s", tostring(fd), tostring(code), tostring(reason)))
    local client = SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    CMD.close(fd, reason)
end

function handle.error(fd)
    skynet.error(string.format("ws error from: %s", tostring(fd)))
    local client = SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    CMD.close(fd, msg)
end

return handle
