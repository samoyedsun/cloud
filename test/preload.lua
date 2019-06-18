local skynet = require "skynet"
require "luaext"
require "print_r"
require "utils.utils"

log4 = require "log4"

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
            pattern = "./run/error-%Y-%m-%d.log",
            level = "DEBUG",
            layout = {
                type = "pattern",
                pattern = "[%d] [%p] [%c] %i %m%n",
            }
        },
    }
}
log4.configure(configure)
IS_DEBUG = true