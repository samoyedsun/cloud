local skynet = require "skynet"
require "luaext"
require "print_r"
require "utils.utils"

local logpath = skynet.getenv("logpath")
local logmode = skynet.getenv("logmode")

log4 = require "log4"
local env = skynet.getenv("env")
local configure = require('config.' .. env .. ".log4")

log4.configure(configure)
IS_DEBUG = logmode == "DEBUG"