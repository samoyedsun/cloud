local skynet = require "skynet"
require "skynet.manager"
local queue = require "skynet.queue"
local CS = queue()
local LOGGER = {}
local CMD = {}

local function open(filename)
    local handle = LOGGER[filename]
    if handle then
        return handle
    end
    handle = skynet.launch("jmlogger", filename)
    LOGGER[filename] = handle
    return handle
end

local function close(filename)
    if LOGGER[filename] then
        skynet.error("close logger ", filename)
        skynet.kill(LOGGER[filename])
        LOGGER[filename] = nil
    end
end

function CMD.open(filename)
    return open(filename)
end

function CMD.close(filename)
    return close(filename)
end

function CMD.update( )
    -- body
end

function CMD.print(s)
    print(s)
end

skynet.start(function ( )
    skynet.register(".jmlogger")
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