local skynet = require "skynet"
local socket = require "skynet.socket"

-- 协议事件处理
local PROTO_PROCESS = { 
    C2S = {},
    S2C = {},
}

local C2S_PROCESS = {}
local S2C_PROCESS = {}

local C2S_AFTER_PROCESS = {}
local S2C_AFTER_PROCESS = {}

local C2S_BEFORE_PROCESS = {}
local S2C_BEFORE_PROCESS = {}
local IS_INIT_PROCESS = false

local HOST 
local HOST_REQUEST 

local root = {}


local function init_process()
    if IS_INIT_PROCESS then
        return
    end
    
    C2S_PROCESS = {}
    S2C_PROCESS = {}
    for _, v in ipairs(C2S_BEFORE_PROCESS) do 
        table.insert(C2S_PROCESS, v)
    end
    for _, v in ipairs(S2C_BEFORE_PROCESS) do 
        table.insert(S2C_PROCESS, v)
    end

    for _, v in ipairs(PROTO_PROCESS.C2S) do 
        table.insert(C2S_PROCESS, v)
    end
    for _, v in ipairs(PROTO_PROCESS.S2C) do 
        table.insert(S2C_PROCESS, v)
    end

    for _, v in ipairs(C2S_AFTER_PROCESS) do 
        table.insert(C2S_PROCESS, v)
    end
    for _, v in ipairs(S2C_AFTER_PROCESS) do 
        table.insert(S2C_PROCESS, v)
    end
end

function root.configure(host, host_request)
    HOST = host
    HOST_REQUEST = host_request
end

function root.c2s_use(name, process)
    IS_INIT_PROCESS = false
    PROTO_PROCESS.C2S[name] = process
    table.insert(PROTO_PROCESS.C2S, {name, process})
end

function root.s2c_use(name, process)
    IS_INIT_PROCESS = false
    table.insert(PROTO_PROCESS.S2C, {name, process})
end
function root.c2s_after( name, process)
    IS_INIT_PROCESS = false
    table.insert(C2S_AFTER_PROCESS, {name, process})
end

function root.c2s_before( name, process )
    IS_INIT_PROCESS = false
    table.insert(C2S_BEFORE_PROCESS, {name, process})
end

function root.s2c_after( name, process )
    IS_INIT_PROCESS = false
    table.insert(S2C_AFTER_PROCESS, {name, process})
end

function root.s2c_before( name, process )
    IS_INIT_PROCESS = false
    table.insert(S2C_BEFORE_PROCESS, {name, process})
end

-- 默认c2s处理器
local function not_found_c2s_process(self, name, args, res)
    return self:emit("error", "c2s", name, args, res, "c2s process not found")
end

local function c2s_process(self, name, req, res) 
    local found = false
    for _, v in ipairs(C2S_PROCESS) do
        local pattern, f = table.unpack(v) 
        if string.match(name, pattern) then
            found = true
            local ok = f(self, name, req, res)
            if not ok then
                return
            end
        end
    end

    return found or not_found_c2s_process(self, name, req, res)
end

local function s2c_process(self, name, args)
    for _, v in ipairs(S2C_PROCESS) do
        local pattern, f = table.unpack(v) 
        if string.match(name, pattern) then
            local ok = f(self, name, args)
            if not ok then
                return
            end
        end
    end
    return
end

function root.send_package(fd, pack)
    if not fd then
        return false, "socket close"
    end
    local package = string.pack(">s2", pack)
    return socket.write(fd, package)
end

local function s2c_request(self, name, args)
    local trace_err = ""
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    local ok = xpcall(s2c_process, trace, self, name, args)
    if not ok then
        self:emit("error", "s2c",  name, args, nil, "s2c process " .. trace_err)
    end

    local ok, data = pcall(HOST_REQUEST, name, args)
    if not ok then
        self:emit("error", "s2c",  name, args, nil, "s2c proto " .. data)
        ok, data = pcall(HOST_REQUEST, name, args)
    end

    if self.session then
        local ok, err = root.send_package(self.session.fd, data)
        if not ok then
            self:emit("error", "socket", err, name, args)
        end
    end
end

-- 处理proto 请求协议入口
local function proto_request(self, msg, sz)
    local ok, type, name, args, response = pcall(HOST.dispatch, HOST, msg, sz)
    if not ok then
        self:emit("error", "proto", name, nil, nil, "proto unpack error ".. type)
        return
    end

    if type == "RESPONSE" then
        local session = name
        local s2c = self.session.s2c 
        if not s2c then
            self:emit("error", "proto", name, args, nil, "response not found wakeup co")
            return
        end
        local req = s2c.req
        local co = req[session]
        if co and type(co) == "thread" then
            req[session] = args
            skynet.wakeup(co)
            return
        end
        self:emit("error", "proto", name, args, nil, "response not found wakeup co")
    end
    if type ~= "REQUEST" then
        self:emit("error", "proto", name, args, nil, "unknow type ".. type)
        return
    end
    
    local trace_err
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    local res = {}          -- 也许应该包含更多信息, 记录整个处理过程路径，方便debug
    local ok = xpcall(c2s_process, trace, self, name, args, res)
    if not ok then
        self:emit("error", "c2s", name, args, res, "c2s process ".. trace_err)
    end
    if not response or not self.session then
        return
    end
    local ok, data = pcall(response, res)
    if not ok then
        self:emit("error", "c2s", name, args, res, "c2s proto " .. data)
        ok, data = pcall(response, res)
    end
    local ok, err = root.send_package(self.session.fd, data)
    if not ok then
        self:emit("error", "socket", err, name, args, res)
    end
end

function root.c2s_process(self, _ , ...)
    init_process()
    proto_request(self, ...)
    return true
end

function root.s2c_process(self, _ , ...)
    init_process()
    s2c_request(self, ...)
    return true
end

return root