local skynet = require "skynet"
require "skynet.queue"
local room = require "server.lualib.room"
local code = require "server.config.code"

local logger = log4.get_logger(SERVICE_NAME)
local CS = skynet.queue()

local RID_TO_ROOM = {}

local CMD = {}

-- 创建房间对象
function CMD.create(uid, rid)
    -- TODO:  create room
    local obj = niuniu_room:new({uid = uid, rid = rid})
    RID_TO_ROOM[rid] = obj
end

-- 关闭房间
function CMD.close(rid)
    local obj = RID_TO_ROOM[rid]
    logger.info("close rid %s", rid)
    if not obj then
        return
    end
    RID_TO_ROOM[rid] = nil
    -- TODO:是否需要保存？
end

-- 保存房间信息
function CMD.save(rid)
    -- TODO: 存入数据库
end

-- 客户端请求
function CMD.c2s(session, name, args)
    local rid = session.rid
    local obj = RID_TO_ROOM[rid]
    if not obj or not obj[name] then
        return {code = code.SEAT_NOT_FOUND, err = code.name(code.SEAT_NOT_FOUND)}
    end
    local trace_err = ""
    local trace = function (e)
        trace_err = e .. debug.traceback()
    end
    local ok, res = xpcall(obj[name], trace, obj, session, args)
    if not ok then
        logger.error("%s %s %s %s %s", name, tostring(session), tostring(args), obj:tostring(), trace_err)
        return {code = code.INTERNAL_SERVER_ERROR, err = code.name(code.INTERNAL_SERVER_ERROR)}
    end
    return res
end

function CMD.info()
    for k, v in pairs(RID_TO_ROOM) do 
        logger.info("rid %s %s", k, v:tostring())
    end
end

function CMD.update( )
    -- body
end

function CMD.exit()
    for k, v in pairs(RID_TO_ROOM) do 
        CMD.save(k)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if not f then
            if session ~= 0 then
                skynet.ret(skynet.pack(nil))
            end
            return
        end
        if session == 0 then
            return CS(f, ...)
        end
        skynet.ret(skynet.pack(CS(f, ...)))
    end)
end)