local skynet = require "skynet"
local socket = require "skynet.socket"
local service = require "skynet.service"
local websocket = require "http.websocket"

local port, wsapp_name , mode = ...
local handle = require(wsapp_name)

local CMD = {}
local agent = {}
local update_count = 0
local thread = tonumber(skynet.getenv("thread")) or 1
local listen_id 
local agent_num = thread * 2

function CMD.update()                           -- 热更新

end

function CMD.exit()

end

if mode == "agent" then
    skynet.start(function ()
        skynet.dispatch("lua", function (_,_, id, protocol, addr)
            local ok, err = websocket.accept(id, handle, protocol, addr)
            if not ok then
                print(err)
            end
        end)
    end)
else
    skynet.start(function ()
        for i= 1, agent_num do
            agent[i] = skynet.newservice(SERVICE_NAME, port, wsapp_name, "agent")
        end

        skynet.dispatch("lua", function(session, _, command, ...)
            local f = CMD[command]
            if session == 0 then
                return f(...)
            end
            skynet.ret(skynet.pack(f(...)))
        end)

        local balance = 1
        local protocol = "ws"
        local id = socket.listen("0.0.0.0", 9948)
        listen_id = id
        skynet.error(string.format("Listen websocket port 9948 protocol:%s", protocol))
        socket.start(id, function(id, addr)
            skynet.error(string.format("accept client socket_id: %s addr:%s", id, addr))
            skynet.send(agent[balance], "lua", id, protocol, addr)
            balance = balance + 1
            if balance > #agent then
                balance = 1
            end
        end)
    end)
end