local skynet = require "skynet"

local Mysql = {
    pool = nil,
    name = "",
}


function Mysql:query( ... )
    if not self.pool or #self.pool == 0 then 
        local pool = skynet.call(".mysql", "lua", "acquire", self.name)
        self.pool = pool
    end
    if #self.pool == 0 then
        return
    end
    local db = self.pool[math.random(1, #self.pool)]
    return skynet.call(db, "lua", "query", ...)
end

function Mysql:new(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.name = name
    return o

end

local root = {}

local MYSQL = {}
function root.get_mysql(name)
    local mysql =  MYSQL[name]
    if mysql then
        return mysql
    end
	local mysql = Mysql:new(name)
    MYSQL[name] = mysql
    return mysql
end

function root.init(name, cf)
    skynet.call(".mysql", "lua", "init", name, cf)
end

skynet.init(function ( ... )
    skynet.uniqueservice("srv_mysql_sup")
end)
return root