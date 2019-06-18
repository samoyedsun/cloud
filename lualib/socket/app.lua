local skynet = require "skynet"

-- 用户事件处理器
local PROCESS = {}

local root = {}

-- 注册用户事件处理器
function root.use(name, process)
    table.insert(PROCESS, {name, process})
end

-- session = {fd = fd, agent = agent, gate = gate}
function root:new()
    local o = { session = {} }
    setmetatable(o, {__index = self})
    return o
end

-- 匹配事件
local function match_process(patterns, name, self, ...)
    for _, v in ipairs(patterns) do
        local pattern, f = table.unpack(v) 
        if string.match(name, pattern) then
            local ok = f(self, name, ...)
            if not ok then              -- 是否继续
                return
            end
        end
    end
end

-- 触发事件
function root:emit(name, ...)
    local trace_err
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    local ok = xpcall(match_process, trace, PROCESS, name, self, ...)
    if not ok then          
        if name == "error" then             -- 有死循环的风险 ...
            skynet.error("channel emit:('error') endless loop %s", trace_err)
            return
        end
        root.emit(self, "error", "emit", name, string.format("%s %s %s", name, trace_err, tostring(...)))
        return false
    end
    return true
end

-- 不推荐使用，可能一点用处都没有，反而让系统变复杂, 连接关闭的时候，协程可能一直没办法唤醒
function root:s2c_call(name,args)
    if not self.session.s2c then
        self.session.s2c = {req = {}, session = 0}
    end
    local s2c = self.session.s2c
    local session = s2c.session + 1
    s2c.session = session
    local co = coroutine.running()
    self:emit(name, args, session)
    s2c.req[session] = co
    skynet.wait()
    local res = s2c.req[session]
    s2c.req[session] = nil
    return res
end

return root