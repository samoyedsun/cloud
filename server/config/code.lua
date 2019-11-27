local root = {
    OK = 200,                               -- 成功
    UNKNOWN = 400,                          -- 未知错误
    FORBIDDEND = 403,                       -- 禁止访问
    NOT_FOUND = 404,                        -- 请求未找到
    INTERNAL_SERVER_ERROR = 500,            -- 服务器内部错误
    SERVICE_UNAVAILABLE = 503,              -- 服务不可用

    SEAT_ALREAY_IN_ANOTHER_ROOM = 1001,     -- 已经在其他房间了
    SEAT_NOT_ENTER_ROOM = 1002,             -- 还未进入房间
    SEAT_ALREAY_FULL = 1003,                -- 房间已经满员
    SEAT_NOT_ROOM_UID = 1004,               -- 不是房主
    SEAT_NOT_WAIT_STATUS = 1005,            -- 房间不处于等待状态
    SEAT_NOT_READY_STATUS = 1006,           -- 房间不处于准备状态
    SEAT_DISSOLVE = 1007,                   -- 房间已解散
}

root.name = function (code)
    for k, v in pairs(root) do 
        if v == code then
            return tostring(k)
        end
    end
    return "unknow code"
end

return root