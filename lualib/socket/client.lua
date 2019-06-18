local skynet = require "skynet"
local socket = require "skynet.socket"

local function send_package(fd, pack)
    return socket.write(fd, string.pack(">s2", pack))
end

local function recv_package(fd)
    local size, err = socket.read(fd, 2)
    if not size then
        return false, err
    end
    size = string.byte(size, 1) * 2^8 +  string.byte(size, 2)
    if size > 10240 then
        skynet.error(size, ":size recv package is too big")
    end
    return socket.read(fd, size)
end

local root = {}

function root:new(host, host_request)
    local o = {
        session = {
            fd = 0,
            req = {},
            sno = 0,
        },
        process = {},
        host_request = host_request,
        host = host,
    }
    setmetatable(o, {__index = root})
    return o
end

function root:open(ip, port)
    local fd, err  = socket.open(ip, port)
    if not fd then
        return false, err
    end
    self.session.fd = fd
    return fd
end

function root:close()
    socket.close(self.session.fd)
    for k,v in pairs(self.session.req) do       -- 唤醒等待的thread
        if type(v) == "thread" then
            self.session.req[k] = false
            skynet.wakeup(co)
        end
    end
    self.session.fd = nil
end

function root:on(name, process)
    table.insert(self.process, {name = name, process = process})
end

function root:emit(name, ...)
    for _, v in ipairs(self.process) do
        if string.match(name, v.name) then
            local ok = v.process(self, name, ...)
            if not ok then              -- 是否继续
                return
            end
        end
    end
end

-- 请求，无需返回请求结果
function root:send(name, args)
    if not self.fd then
        return false
    end
    local data = self.host_request(name, args)
    return send_package(self.fd, data)
end

-- 请求，要获取返回
function root:call(name, args)
    local session = self.session
    session.sno = session.sno + 1
    local session = session.sno
    local data = self.host_request(name, args, session)

    local ok, err = send_package(self.session.fd, data)
    if not ok then
        return ok, err
    end

    local co = coroutine.running()
    local req = self.session.req
    req[session] = co
    skynet.wait()
    local res = req[session]
    req[session] = nil
    return true, res
end


local function dispatch(self, t, ...)
    if t == "REQUEST" then
        self:emit("s2c", ...)
        return
    end

    assert(t == "RESPONSE")
    local session, args = ...
    local co = self.session.req[session]
    if co and type(co) == "thread" then
        self.session.req[session] = args
        skynet.wakeup(co)
    end
end

function root:dispatch()
    while true do
        self.session.dispatch = true
        if not self.session.fd then
            return
        end
        local data, err = recv_package(self.session.fd)
        if not self.session.fd then
            return
        end

        if not data then
            for k,v in pairs(self.session.req) do       -- 唤醒等待的thread
                if type(v) == "thread" then
                    self.session.req[k] = false
                    skynet.wakeup(co)
                end
            end
            self:emit("close", err)
            break
        end
        skynet.fork(function ()
            dispatch(self, self.host:dispatch(data))
        end)
    end
end

function root:write(data)
    return send_package(self.session.fd, data)
end

function root:read()
    if self.session.dispatch then
        return false, "start dispatch"
    end
    return recv_package(self.session.fd)
end

return root