local skynet = require "skynet"
require "skynet.queue"
local logger = log4.get_logger(SERVICE_NAME)

local UID_TO_LOGON = {}

local ONLINE_NUMBER = 0
local CS = skynet.queue()
local CMD = {}

function CMD.logon(uid, fd, agent)
    if UID_TO_LOGON[uid] then
        local logon = UID_TO_LOGON[uid]
        pcall(skynet.call, logon.agent, "lua", "emit", logon.fd, "s2c",  "on_player_kick", {err = "duplicate logon"})
        pcall(skynet.call, logon.agent, "lua", "emit", logon.fd, "kick")          -- 踢人
        logger.info("kick uid %s fd %s agent %s", uid, fd, agent)
        ONLINE_NUMBER = ONLINE_NUMBER - 1
    end
    UID_TO_LOGON[uid] = {fd = fd, agent = agent}
    ONLINE_NUMBER = ONLINE_NUMBER + 1
end

function CMD.logout(uid, fd)
    if not UID_TO_LOGON[uid] then
        return
    end
    if UID_TO_LOGON[uid].fd ~= fd then
        return
    end
    UID_TO_LOGON[uid] = nil
    ONLINE_NUMBER = ONLINE_NUMBER - 1
end

function CMD.is_logon(uid)
    if UID_TO_LOGON[uid] then
        return true
    end
    return false
end

function CMD.is_logon_list(uid_list)
    local UID_TO_LOGON = {}
    for _, uid in ipairs(uid_list) do 
        UID_TO_LOGON[uid] = CMD.is_logon[uid]
    end
end

function CMD.agent(uid)
    return UID_TO_LOGON[uid]
end

function CMD.broadcast(name, msg)
    local agent = {}
    for _, v in pairs(UID_TO_LOGON) do 
        agent[v.agent] = true
    end
    local agents = table.indices(agent)
    for _, agent in ipairs(agents) do 
        pcall(skynet.send, agent, "lua", "s2c_broadcast", name, args)
    end
end

function CMD.info()
    -- TODO
end

skynet.start(function() 
    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if not f then
            if session ~= 0 then
                skynet.ret(skynet.pack(nil))
            end
            return
        end
        if session == 0 then
            return CS(f, ...)
        end
        skynet.ret(skynet.pack(CS(f, ...)))
    end)
end)