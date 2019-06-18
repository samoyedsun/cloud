local skynet = require "skynet"
local skynet_core = require "skynet.core"

local CONFIG = {}
local TYPE_TO_APPENDER = {}

local GLOBAL_LEVEL = "DEBUG"

local LEVELS = {
    ["DEBUG"] = 1,
    ["INFO" ]= 2, 
    ["WARN" ]= 3, 
    ["ERROR"] = 4,
    ["FATAL"] = 5,
}



local root = {}

local logger = {
    conifgs = {},
    level = "DEBUG",
    appenders = {},
}

function root.configure(config)
    CONFIG = config or {}
end

function root.set_type_appender(type, f)
    TYPE_TO_APPENDER[type] = f
end

function root.get_logger(name)
    local o = logger:new(name)
    local log = {}
    local function get_logger(name)
        return function (...)
            local f = o[name]
            f(o, ...)
        end
    end
    log.debug = get_logger("debug")
    log.info = get_logger("info")
    log.warn = get_logger("warn")
    log.error = get_logger("error")
    log.fatal = get_logger("fatal")
    log.set_level = get_logger("set_level")
    log.add_appender = get_logger("add_appender")
    log.log = get_logger("log")

    return log
end

function root.set_global_level(level)
    if LEVELS[level] then
        GLOBAL_LEVEL = level
    end
end

-- %r - time in toLocaleTimeString format
-- %p - log level
-- %c - log category_name
-- %m - log data
-- %d - date in various formats
-- %% - %
-- %n - newline
-- %i - lua debug.getinfo
-- %f - log
local function layout_process(self_logger, cf, level, fmt, ...)
    if not cf or not cf.layout or cf.layout.type ~= "pattern" then
        return string.format(fmt, ...)
    end
    local args = table.pack(...)
    local str =  string.gsub(cf.layout.pattern, "%%[rpcmdi%%n]", function (c)
        if c == "%n" then
            return "\n"
        elseif c == "%p" then
            return level
        elseif c == "%r" then
            return  os.date("%c", skynet_time())
        elseif c == "%c" then
            return self_logger.category_name or ""
        elseif c == "%m" then
            return string.format(fmt, table.unpack(args))
        elseif c == "%d" then
            return os.date("%Y-%m-%d %H:%M:%S", skynet_time())
        elseif c == "%%" then
            return "%"
        elseif c == "%i" then
            local info = debug.getinfo(8,"nSl")
            return string.format("[::%s line:%-4d]", info.source, info.currentline)
        end
        return c
    end)
    return str
end

local function get_console_appender(cf)
    return function (self_logger, level, fmt, ...)
        if cf.level then
            if LEVELS[level] < LEVELS[string.upper(cf.level)] then
                return
            end
        end
        local s = layout_process(self_logger, cf, level, fmt, ...)
        if string.byte(s, #s) == string.byte("\n") then
            return io.write(s)
        end
        print(s)
    end
end

local function get_date_file_appender(cf)
    local log = { handle = nil, filename = nil, date = nil}
    return function (self_logger, level, fmt, ...)
        if cf.level then
            if LEVELS[level] < LEVELS[string.upper(cf.level)] then
                return
            end
        end
        local now = skynet_time()
        local date = os.date("%Y-%m-%d", now)
        if log.date ~= date then            -- update date file
            if log.handle and log.handle then
                skynet.send(".jmlogger", "lua", "close", log.filename)
            end
            log.filename = os.date(cf.pattern, now)
            log.handle = skynet.call(".jmlogger", "lua", "open", log.filename)
            log.date = date
        end
        if not log.handle then
            return
        end
        local s = layout_process(self_logger, cf, level, fmt, ...)
        skynet_core.send(log.handle, 1, 0, s)
    end
end

TYPE_TO_APPENDER["date_file"] = get_date_file_appender
TYPE_TO_APPENDER["console"] = get_console_appender

local LOGGERS = {}

function logger:new(category_name)
    if LOGGERS[category_name] then
        return LOGGERS[category_name]
    end

    local level
    if CONFIG.levels then
        level = CONFIG.levels[name]
    end

    local o = {
        appenders = {},
        category_name = category_name,
        level = level or GLOBAL_LEVEL,
    }
    LOGGERS[category_name] = o

    if CONFIG.appenders then
        for k, v in ipairs(CONFIG.appenders) do 
            if string.match(category_name, v.category) then
                local get_appender = TYPE_TO_APPENDER[v.type]
                if get_appender then
                    table.insert(o.appenders, get_appender(v))
                end
            end
        end
    end

    setmetatable(o, {__index = self})
    return o
end

function logger:set_level(level)
    level = string.upper(level)
    if not LEVELS[level] then
        return
    end
    self.level = level
end

-- 
function logger:add_appender(appender)
    table.insert(self.appenders, appender)
end

function logger:log(level, ... )
    for _,v in ipairs(self.appenders) do 
        v(self, level, ...)
    end
end

function logger:debug(...)
    local level = "DEBUG"
    if LEVELS[level] < LEVELS[self.level] then
        return
    end
    self:log(level, ...)
end

function logger:info( ... )
    local level = "INFO"
    if LEVELS[level] < LEVELS[self.level] then
        return
    end
    self:log(level, ...)
end

function logger:warn( ... )
    local level = "WARN"
    if LEVELS[level] < LEVELS[self.level] then
        return
    end
    self:log(level, ...)
end

function logger:error( ... )
    local level = "ERROR"
    if LEVELS[level] < LEVELS[self.level] then
        return
    end
    self:log(level, ...)
end

function logger:fatal( ... )
    local level = "FATAL"
    if LEVELS[level] < LEVELS[self.level] then
        return
    end
    self:log(level, ...)
end


return root