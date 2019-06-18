local skynet = require "skynet"
local etcd = require "etcd"
local CMD = {}

function CMD.benchmark( )
    skynet.fork(function ( ... )
        print(etcd.get("/ssmj/games/game1"))
        local rpc = etcd.open("/ssmj/games/game1")
        local now = skynet_time()
        for i=0, 10000 do
            rpc:call("test_hello", {w = "sdfaf"})
        end
        print("totol", skynet_time() - now)
    end)
    skynet.fork(function ( ... )
        print(etcd.get("/ssmj/games/game2"))
        local rpc = etcd.open("/ssmj/games/game2")
        local now = skynet_time()
        for i=0, 10000 do
            rpc:call("test_hello", {w = "sdfaf"})
        end
        print("totol", skynet_time() - now)
    end)
end


function CMD.game()
    local games = "/ssmj/games/"
    local ok, gamelist = etcd.lsdir(games)
    print(ok, gamelist)
    for k, v in ipairs(gamelist) do 
        local file = games .. v.name
        local rpc = etcd.open(file)
        print(rpc:call("test_hello", {name = "i love you"}))
    end
end

skynet.start(function ( ... )
    CMD.benchmark()
    -- CMD.game()
end)