local session = {}

function session:new(data)
    local o = {
        fd      = nil, 
        ws      = nil,
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
    local ws = nil
    if self.ws then
        ws = true
    end
    local t = {fd = self.fd, gate = self.gate, agent = self.agent, addr = self.addr, ws = ws}
end

function session:tostring()
    return tostring(self:totable())
end

return session