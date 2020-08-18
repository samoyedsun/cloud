local session = {}

function session:new(data)
    local o = {
        fd      = nil,
        gate    = nil,
        agent   = nil,
        addr    = nil,
        ip      = nil,
    }
    table.merge(o, data)
    setmetatable(o, {__index = self})
    return o
end

function session:totable()
    local t = {fd = self.fd, gate = self.gate, agent = self.agent, addr = self.addr, ip = self.ip}
end

function session:tostring()
    return tostring(self:totable())
end

return session