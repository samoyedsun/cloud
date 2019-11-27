local etcdfile = "/mj/games/game1"

local root = {
    etcdfile = "/mj/games/game1",
    etcdcf = {
        name = etcdfile,
        backend = {
            ip = "127.0.0.1",
            type = "http",
            port = 8104,
        },
    }
}

return root