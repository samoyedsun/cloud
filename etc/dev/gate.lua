local etcdfile = "/mj/gates/gate1"
local root = {
    etcdfile = etcdfile,
    etcdcf = {
        name = etcdfile,
        backend = {
            ip = "127.0.0.1",
            type = "http",
            port = 8103,
        },
        frontend = {
            ip = "192.168.31.249",
            type = "http",
            ws = "ws://192.168.31.249:8203/ws",
            socket = 8303,
            port = 8203,
        },
    }
}


return root