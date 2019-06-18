local skynet = require "skynet"
local httpd = require "http.httpd"
local websocket = require "websocket"
local socket = require "skynet.socket"
local sockethelper = require "http.sockethelper"

local handler = {}
local FD_TO_WEBSOCKET = {}

-- websocket echo server
function handler.on_open(ws)
    skynet.error(string.format("Client connected: %s", ws.addr))
    ws:send_text("Hello websocket !")
    local fd = ws.fd
    FD_TO_WEBSOCKET[fd] = ws
end

function handler.on_message(ws, msg)
    skynet.error(ws.fd .. " Received a message from client:\n"..msg)
    ws:send_binary(msg)
    if msg == "close" then
        FD_TO_WEBSOCKET[ws.fd] = nil
        ws:close()
        return
    end
end

function handler.on_error(ws, msg)
    skynet.error("Error. Client may be force closed.")
    -- do not need close.
    local fd = ws.fd
    ws:close()
    FD_TO_WEBSOCKET[fd] = nil
end

function handler.on_close(ws, fd, code, reason)
    skynet.error(string.format("Client disconnected: %s", ws.addr))
    local fd = ws.fd
    if not FD_TO_WEBSOCKET[fd] then
        return
    end
    ws:close()
    FD_TO_WEBSOCKET[fd] = nil
end 

local function handle_socket(fd, addr)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(fd), 8192)
    if code then
        if url == "/ws" then
            local ws = websocket.new(fd, addr, header, handler)
            ws:start()
        end
    end
    socket.close(fd)
end

skynet.start(function()
    local fd = assert(socket.listen("127.0.0.1:8001"))
    socket.start(fd , function(fd, addr)
        socket.start(fd)
        pcall(handle_socket, fd, addr)
    end)
    skynet.newservice("debug_console", "0.0.0.0", 8000)
end)