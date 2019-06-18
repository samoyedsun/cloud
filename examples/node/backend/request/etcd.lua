local skynet = require "skynet"

local REQUEST = {}

local function call_register( ...)
    return skynet.call(".register", "lua", ...)
end
function REQUEST:lsdir(args)
    local ok, result = call_register("lsdir", args.file)
    return {ok = ok, result = result}
end

function REQUEST:mkdir(args, res)
    local ok, result = call_register("mkdir", args.file)
    return {ok = ok, result = result}
end

function REQUEST:watch(args)
    local ok, result = call_register("watch", args.file)
    return {ok = ok, result = result}
end

function REQUEST:set(args)
    local ok, result = call_register("set", args.file, args.content)
    return {ok = ok, result = result}
end 

function REQUEST:get(args)
    local ok, result = call_register("get", args.file)
    return {ok = ok, result = result}
end

function REQUEST:rm(args)
    local ok, result = call_register("rm", args.file)
    return {ok = ok, result = result}
end

function REQUEST:ttl(args)
    local ok, result = call_register("ttl", args.file, args.content)
    return {ok = ok, result = result}
end

return REQUEST