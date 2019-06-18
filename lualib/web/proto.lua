--[[
    时间：2017年 3月 6日 星期一 17时42分12秒
    作者：LGC
    可以灵活添加不同消息序列化和反序列化方式支持
    比如说:JSON，SPROTO，BSON
]]

local web = {}

function web:new(proto_host)
    local o = {
        web_host = proto_host,
        process_array = {},
        process_after_array = {},
        process_before_array = {},
        process_sort = {},
        init_process = false,
    }
    setmetatable(o, {__index = web})
    return o
end

function web:use(name, process)
    self.init_process = false
    table.insert(self.process_array, {name = name, process = process})
end

function web:after(name, process)
    self.init_process = false
    table.insert(self.process_after_array, {name = name, process = process})
end

function web:before(name, process)
    self.init_process = false
    table.insert(self.process_before_array, {name = name, process = process})
end

function web:emit(req, name, args, res, ...)
    local trace_err = ""
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    if not self.init_process then
        for _, v in ipairs(self.process_before_array) do 
            table.insert(self.process_sort, v)
        end
        for _, v in ipairs(self.process_array) do 
            table.insert(self.process_sort, v)
        end
        for _, v in ipairs(self.process_after_array) do 
            table.insert(self.process_sort, v)
        end
        self.init_process = true
    end
    local function process(self, req, name, args, res, ...)
        local found = false
        for _, v in ipairs(self.process_sort) do 
            if string.match(name, v.name) then
                local ok = v.process(req, name, args, res, ...)
                found = true
                if not ok then
                    return
                end
            end
        end
        return found
    end
    local ok, rs = xpcall(process, trace, self, req, name, args, res, ...)
    if not ok then
        if name == "error" then         -- 有死循环的风险 ...
            skynet.error("channel :emit('error') endless loop %s", trace_err)
            return
        end
        self:emit(req, "error", name, args, res, trace_err)
    end 
end

function web:process(req, res)
    local body = req.body
    local sz = req.headers["Content-Length"] or #body
    local ok, type, name, args, response = pcall(self.web_host.dispatch, self.web_host, req.body, sz)
    if not ok then
        self:emit(req, "error", name, nil, nil, "proto unpack error ".. type)
        return
    end

    if type ~= "REQUEST" then
        local err
        if type == "RESPONSE" then
            err = "not support type=response"
        else
            err = "unknow type ".. type
        end
        self:emit(req, "error", name, args, nil, err)
        res:json({code = 400, err = err})
        return
    end

    local resp = {}
    self:emit(req, name, args, resp)
    if not response then
        return
    end
    local ok, data = pcall(response, resp)
    if not ok then
        self:emit(req, "error", name, args, resp, "c2s proto response " .. data)
        ok, data = pcall(response, resp)
    end
    res.body = data
end

return web
