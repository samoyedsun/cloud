local skynet = require "skynet"
local config
local FILE_TO_VOICE = {}
local CMD = {}


function CMD.post(msg, voice)
    local uid = tonumber(msg.uid) 
    local rid = tonumber(msg.rid) 
    if not uid or not rid then
        return
    end
    local timestamp = skynet_time()
    local file = string.format("%s%s%s%s", math.random(1000, 9000), uid, rid, timestamp)
    FILE_TO_VOICE[file] = voice
    local frontend = config.frontend
    local url = string.format("http://%s:%s/voice?file=%s", frontend.ip, frontend.port, file)
    local req = { url = url, second = msg.second, uid = uid, rid = rid}
    local timeout = 30 * 100 -- 30s
    create_timeout(timeout, function ()
        FILE_TO_VOICE[file] = nil
    end)
    local agent = skynet.call(".logon", "lua", "agent", uid)
    if not agent then
        return url
    end
    skynet.send(agent.agent, "lua", "emit", agent.fd, "seat_voice", req)
    return url
end

function CMD.get(msg)
    local uid = msg.uid
    local file = msg.file
    local voice = FILE_TO_VOICE[file]
    return voice
end

skynet.start(function() 
    local env = skynet.getenv("env")
    config = require('etc.' .. env .. ".server")
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