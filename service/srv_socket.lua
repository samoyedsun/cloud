local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socket = require "skynet.socket"
local skynet_queue = require "skynet.queue"
local logger = log4.get_logger(SERVICE_NAME)
local CS = skynet_queue()

--[[
    Code:
        200 请求成功
        400 Bad Request . challenge failed
        401 Unauthorized . unauthorized by auth_handler
        403 Forbidden . login_handler failed
        406 Not Acceptable . already in login (disallow multi login)
]]

local SOCKET_TO_AGENT = {}          -- MAP key = socket fd, value = srv_agent service handle
local CONNECT_NUMBER = 0
local UPDATE_COUNT = 0

local AGENT_SERVICE = {}            -- ARRAY obj= {handle = skynet service handle, wait_close=false, number = 0}
local thread = tonumber(skynet.getenv("thread")) or 1
local AGENT_NUMBER = thread * 2
local AGENTAPP                      -- 处理连接的模块

local CMD = {}                 
local SOCKET = {}                   -- SOCKET msg handler
local GATE

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
}

local function open_client(fd, addr)
    CONNECT_NUMBER = CONNECT_NUMBER + 1
    local chance = AGENT_SERVICE[1]
    for k, v in ipairs(AGENT_SERVICE) do 
        if v.wait_close then
            break
        end
        if v.number < chance.number then
            chance = v
        end
    end
    SOCKET_TO_AGENT[fd] = chance
    chance.number = chance.number + 1
    skynet.send(chance.handle, "lua", "start", GATE, fd, addr)
    return
end

-- 玩家离线过程 watchdog ->  srv_agent -> client -> agent_sup
local function close_client(fd, reason)
    local agent = SOCKET_TO_AGENT[fd]
    if not agent then
        return
    end

    logger.info("close fd %s handle %08x reason %s", fd,  agent.handle, reason)
    SOCKET_TO_AGENT[fd] = nil
    CONNECT_NUMBER = CONNECT_NUMBER - 1
    agent.number = agent.number - 1
    skynet.send(agent.handle, "lua", "close", fd)
    if not agent.wait_close or not agent.number == 0 then
        return
    end
    skynet.timeout(200, function ( ... )        -- 2S后删除尸体
        logger.info("kill %08x wait %s", agent.handle, agent.wait_close)
        skynet.kill(agent.handle)    
    end)
end

function SOCKET.open(fd, addr)
    logger.info("New client %d from %s online num %d ", fd, addr, CONNECT_NUMBER)
    open_client(fd, addr)
end

function SOCKET.close(fd)
    logger.info("SOCKET.close fd %d", fd)
    close_client(fd, "SOCKET.close")
end

function SOCKET.error(fd, msg)
    logger.info("SOCKET.error fd %d msg %s", fd, msg)
    local errmsg = "SOCKET.error "..msg
    close_client(fd, errmsg)
end

local function send_package(fd, pack)
    local package = string.pack(">s2", pack)
    return socket.write(fd, package)
end

function SOCKET.data(fd, data)
    -- TODO:not enter here
    local agent = SOCKET_TO_AGENT[fd]
    if not agent then
        return
    end
    skynet.redirect(agent.handle, skynet.self(), "client", fd, data, #data)
end

function CMD.start(conf, agentapp)
    AGENTAPP = agentapp
    for i=1, AGENT_NUMBER do 
        local handle = skynet.newservice("srv_socket_agent", AGENTAPP, "update:"..UPDATE_COUNT)
        table.insert(AGENT_SERVICE, {handle = handle, number = 0, wait_close = false})
    end
    skynet.call(GATE, "lua", "open" , conf)
end

function CMD.close(fd)
    logger.info("CMD.close fd %s", fd)
    close_client(fd, "CMD.close")
end

function CMD.info()
    logger.info("socket number %s", CONNECT_NUMBER)
    for k, v in pairs(SOCKET_TO_AGENT) do 
        logger.info("socket %s to agent %s", k, v.handle)        
    end
end

function CMD.exit()
    
end

function CMD.update()
    UPDATE_COUNT = UPDATE_COUNT + 1
    local agents = {}
    for i=1, AGENT_NUMBER do 
        local handle = skynet.newservice("srv_socket_agent", AGENTAPP, "update:"..UPDATE_COUNT)
        table.insert(agents, {handle = handle, number = 0, wait_close = false})
    end
    for _, v in ipairs(AGENT_SERVICE) do 
        v.wait_close = true
        skynet.send(v.handle, "lua", "update")
    end
    for _, v in ipairs(agents) do 
        table.insert(AGENT_SERVICE, 1, v)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            CS(f, ...)
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(CS(f, subcmd, ...)))
        end
    end)

    GATE = skynet.newservice("srv_gate")
end)
