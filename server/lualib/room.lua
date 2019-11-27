local code = require "server.config.code"
local room = {}

function room:new(opt)
    local o = {
        roomuid = 0,
        rid = 0,
        createtime = 0,
        -- TODO：init 房间信息
    }

    setmetatable(o, {__index = self})
    return o
end

-- app proto c2s => srv_room c2s => room object
function room:room_enter(session, msg)
    -- TODO:进入房间
    return {code = code.OK}
end

return room