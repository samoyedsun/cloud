local skynet = require "skynet"

local logpath = skynet.getenv("logpath")
local logmode = skynet.getenv("logmode")

local configure = {
    appenders = {
        {
            type = "console",
            category = ".*",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[%d] [%p] [%c] %i %m%n"
            }
        },
        {
            type = "date_file",
            category = ".*",
            pattern = logpath .. "error-%Y-%m-%d.log",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[%d] [%p] [%c] %i %m%n",
            }
        },
        {
            type = "date_file",
            category = "chaoshan",
            pattern = logpath .. "chaoshan-%Y-%m-%d.log",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[%d] [%p] [%c] %i %m%n",
            }
        },
        {
            type = "date_file",
            category = "test",
            pattern = logpath .. "test-%Y-%m-%d.log",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[%d] [%p] [%c] %i %m%n",
            }
        },
        {
            type = "date_file",
            category = "action",
            pattern = logpath .. "action-%Y-%m-%d.log",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[%d] %m%n",
            }
        },
    }
}

return configure