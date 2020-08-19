local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local port, wsapp_name, protocol = ...

local CMD = {}
local agent = {}
local update_count = 0
local thread = tonumber(skynet.getenv("thread")) or 1
local listen_id 
local agent_num = thread * 2

function CMD.update()                           -- 热更新
    local old_agent = agent
    local new_agent = {}
    update_count = update_count + 1             -- 更新次数
    for i = 1, agent_num do 
        new_agent[i] = skynet.newservice("srv_websocket_agent", wsapp_name)
    end
    
    agent = new_agent
    for _, v in ipairs(old_agent) do
        skynet.send(v, "lua", "update")
    end
end

function CMD.exit()
    socket.close(listen_id)
    for _, v in ipairs(agent) do
        skynet.send(v, "lua", "update")
    end
end

skynet.start(function ()
    for i= 1, agent_num do
        agent[i] = skynet.newservice("srv_websocket_agent", wsapp_name)
    end

    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if session == 0 then
            return f(...)
        end
        skynet.ret(skynet.pack(f(...)))
    end)

    local balance = 1
    local id = socket.listen("0.0.0.0", port)
    listen_id = id
    skynet.error("Listen websocket port ", port)
    socket.start(id, function(fd, addr)
        skynet.error(string.format("accept client fd: %s addr:%s", fd, addr))
        skynet.send(agent[balance], "lua", "socket", fd, protocol, addr)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)
end)
