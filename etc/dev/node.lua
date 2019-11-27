local etcdfile = "/mj/nodes/node1"
local root = {
    etcdfile = etcdfile,
    etcdcf = {
        name = etcdfile,
        backend = {
            ip = "127.0.0.1",
            type = "http",
            port = 8101,
        },
        frontend = {
            ip = "192.168.31.249",
            type = "http",
            port = 8201,
        },
    }
}


return root