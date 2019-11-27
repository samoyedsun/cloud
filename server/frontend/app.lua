local skynet = require "skynet"
local app = require "socket.app"
local proto = require "server.frontend.proto"
local code = require "server.config.code"
local session_class = require "server.lualib.session"
local logger = log4.get_logger("app")

app.use("^c2s$", proto.c2s_process)
app.use("^s2c$", proto.s2c_process)

app.use("^error$", function (self, _name, _type, ...)
    if _type == "c2s" then
        logger.error("%s %s %s", _type, tostring(self.session), tostring({...}))
        local name, args, res, err = ...
        if res and type(res) == "table" then
            err = code.name(code.INTERNAL_SERVER_ERROR)
            table.merge(res, {code = code.INTERNAL_SERVER_ERROR, err = err})
        end
        return true
    end
    if _type == "socket" and not self.session then
        logger.debug("%s %s", _type, tostring({...}))
        return true
    end

    logger.error("%s %s %s", _type, tostring(self.session), tostring({...}))
    if _type == "s2c" then
    elseif _type == "proto" then
    elseif _type == "emit" then
    end
    return true
end)


app.use("^start$", function (self, _name, options)
    local session = session_class:new(options)
    self.session = session
    if session.gate then
        skynet.call(session.gate, "lua", "forward", session.fd)     -- 告诉gate，把socket消息发到agent中来
    end
    skynet.fork(function ( ... )
        while self.session do
            -- self:emit("s2c", "heartbeat")                        -- TODO: 发送心跳
            skynet.sleep(300)
        end
    end)
end)

app.use("^seat_voice$", function (self, _name, msg)
    local game = self.session.game
    if not game then
        return
    end
    skynet.call(game.handle, "lua", "c2s", game.session, "seat_voice", msg)
end)

app.use("^close$", function (self)
    local session = self.session
    skynet.send(".logon", "lua", "logout", session.uid, session.fd)

    self.close_session = session
    local game = session.game
    if game then
        skynet.call(game.handle, "lua", "c2s", game.session, "seat_offline", {})
    end
    self.session = nil
    return true
end)

app.use("^kick$", function (self)
    local session = self.session
    if not session then
        return
    end
    if session.gate then
        skynet.call(session.gate, "lua", "kick", session.fd)
        return
    end
    if session.ws then      -- websocket
        session.ws:close()
        return
    end
end)

return app