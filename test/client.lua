local skynet = require "skynet"
local socket = require "socket"
local sproto = require "sproto"

local logger = log4.get_logger("client")

local HOST 
local SPROTO_REQUEST 
local S2C_REQUEST = {}

local client = {
    fd = nil,
    req = {},
    session = 0,
    events = {}, 
}

function client.configure(proto, s2c_request)
    HOST = sproto.new(proto.s2c):host "package"
    SPROTO_REQUEST = HOST:attach(sproto.new(proto.c2s))
    S2C_REQUEST = s2c_request or {}
end


function client:new(uid)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.uid = uid
    o.req = {}
    o.events = {}
    o.session  = 0
    o.fd = nil
    return o
end

function client:create_connect(ip, port)
    self.fd = assert(socket.open(ip, port))
end

local function send_package(fd, pack)
    local package = string.pack(">s2", pack)
    return socket.write(fd, package)
end

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s+2 then
        return nil, text
    end

    return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(fd)
    local size = socket.read(fd, 2)
    if not size then
        return
    end
    size = string.byte(size, 1) * 2^8 +  string.byte(size, 2)
    if size > 10240 then
        logger.warn("recv_package size %d is too big", size)
        return
    end
    return socket.read(fd, size)
end

-- 请求，无需返回请求结果
function client:send(name, args)
    if not self.fd then
        return false
    end
    local str = SPROTO_REQUEST(name, args)
    return send_package(self.fd, str)
end

-- 请求，要获取返回
function client:call(name, args)
    self.session = self.session + 1
    local session = self.session
    -- logger.debug("call c2s %s session %s args %s", name, session, tostring(args))
    local str = SPROTO_REQUEST(name, args, session)
    if not send_package(self.fd, str) then
        return
    end
    local co = coroutine.running()
    self.req[session] = co
    skynet.wait()
    local res = self.req[session]
    self.req[session] = nil
    return res 
end


function client:close()
    socket.close(self.fd)
    self.fd = nil
    self.uid = nil
end

local function client_process_request(self, name, args)
    logger.debug("s2c %s args %s", name, tostring(args))
    local f = S2C_REQUEST[name] 
    if not f then
        logger.info("s2c %s args %s not found process", name, tostring(args))
        return
    end
    local trace_err
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    local ok, rs = xpcall(f, trace, self, args)
    if not ok then
        logger.error("s2c %s args %s error %s", name, tostring(args), trace_err)
    end
end

local function client_process_response(self, session, args)
    -- logger.debug("session %d args %s", session, tostring(args))
    local co = self.req[session]
    if co and type(co) == "thread" then
        self.req[session] = args
        skynet.wakeup(co)
    end
end

local function client_process_package(self, t, ...)
    if t == "REQUEST" then
        client_process_request(self, ...)
    else
        assert(t == "RESPONSE")
        client_process_response(self, ...)
    end
end

function client:dispatch_package()
    while true do
        local v = recv_package(self.fd)
        if not v then
            logger.info("%d close: recv data is null", self.fd)
            self:close()
            break
        end
        client_process_package(self, HOST:dispatch(v))
    end
end

function client:send_package(data)
    return send_package(self.fd, data)
end

function client:recv_package()
    return recv_package(self.fd)
end

return client