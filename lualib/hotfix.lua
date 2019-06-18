local skynet = require "skynet"
local hotfix
local root = {}

function root.start_hotfix_service(type, service_name, ...)
    return skynet.call(hotfix, "lua","start_hotfix_service", type, service_name, ...)
end

function root.start_reboot_service(type, service_name, ...)
    return skynet.call(hotfix, "lua", "start_reboot_service", type, service_name, ...)
end

skynet.init(function ()
    hotfix = skynet.uniqueservice("srv_hotfix", "master")
end)

return root