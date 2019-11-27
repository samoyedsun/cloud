local code = require "code"

local REQUEST = {}


function REQUEST:user_auth( ... )
    -- TODO:验证用户信息
    local session = self.session
    session.auth = true
    return {code = code.OK}
end


return REQUEST