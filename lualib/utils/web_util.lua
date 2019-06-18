local skynet = require "skynet"

local logger = log4.get_logger("webapp")
local IS_DEBUG = IS_DEBUG

local root = {}

function root.set_logger(log)
    logger = log
end

function root.before_log(req, name, args)
    if not IS_DEBUG then
        return true
    end
    logger.debug("%s args %s", name, tostring(args))
    return true
end

function root.after_log(req, name, args, res)
    if not IS_DEBUG then
        return true
    end
    logger.debug("%s args %s res %s", name, tostring(args), tostring(res))
    return true
end

function root.static(root, path)
    if string.find(path, "%.%s.") then
        return 
    end
    local file = root..path
    local fd = io.open(file, "r")
    local read = function ()
        local content = fd:read(1024 * 128)
        if content then
            return content
        else
            fd:close()
        end
    end
    return read
end

return root