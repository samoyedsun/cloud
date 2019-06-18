local skynet = require "skynet"
local log4 = require "log4"

local cf = {
    appenders = {
        {
            type = "date_file",
            category = "date",
            pattern = "./run/test-%Y-%m-%d.log",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[%r] [%p] %i %c %% %d %m%n"
            }
        },
        {
            type = "date_file",
            category = "event",
            pattern = "./run/event-%Y-%m-%d.log",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "%d;%m%n"
            }
        },
        {
            type = "date_file",
            category = ".*",
            pattern = "./run/error-%Y-%m-%d.log",
            level = "ERROR",
            layout = {
                type = "pattern",
                pattern = "[%r] [%p] %i %c %% %d %m%n"
            }
        },
        {
            type = "console",
            category = ".*",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[console]%d;%m%n"
            }
        }
    },
}

-- %r - time in toLocaleTimeString format
-- %p - log level
-- %c - log category
-- %m - log data
-- %d - date in various formats
-- %% - %
-- %n - newline

-- log4.configure(cf)
-- local logger = log4.get_logger("test")
logger = log4.get_logger("event")
-- e_logger = log4.get_logger("event")

skynet.start(function (  )
    print("test4log")
    logger.debug("debug message")
    logger.info("info message")
    logger.warn("warn message")
    logger.error("error message")
    logger.fatal("fatal message")   
    -- e_logger.info("xx;aaa;bbb;") 
    skynet.exit()
end)