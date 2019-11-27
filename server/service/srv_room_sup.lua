local skynet = require "skynet"
require "skynet.manager"
require "skynet.queue"
local code = require "server.config.code"
local logger = log4.get_logger(SERVICE_NAME)
local mode = ...

local CS = skynet.queue()
local RID_TO_SERVICE = {}
local UID_TO_RID = {}           -- 
local RID_TO_NUMBER = {}        -- 房间人数

local MAX_NUMBER = 50
local UPDATE_COUNT = 0
local SERVICE_LIST = {}   -- ARRAY obj= {handle = skynet service handle, wait_close=false, number = 0}

local function acquire_service(uid, rid)
    if RID_TO_SERVICE[rid] then
        return RID_TO_SERVICE[rid]
    end
    local c
    for _, v in ipairs(SERVICE_LIST) do 
        if v and not v.wait_close then
            if not c then
                c = v
            elseif c.number > v.number then
                c = v
            end
        end
    end
    if not c or c.number >= MAX_NUMBER then
        local handle = skynet.newservice("server/service/srv_room", "update:"..UPDATE_COUNT)
        c = {handle = handle, wait_close = false, number = 0}
        table.insert(SERVICE_LIST, c)
    end
    
    skynet.call(c.handle, "lua", "create", uid, rid)           -- 创建房间
    c.number = c.number + 1
    RID_TO_SERVICE[rid] = c
    RID_TO_NUMBER[rid] = 0
    return c
end

local function release_service(rid)
    logger.debug("release_service %s", rid)
    if not RID_TO_SERVICE[rid] then
        return
    end
    local obj = RID_TO_SERVICE[rid]
    skynet.send(obj.handle, "lua", "close", rid)
    RID_TO_SERVICE[rid] = nil
    RID_TO_NUMBER[rid] = nil

    for uid, v in pairs(UID_TO_RID) do      -- TODO:是否有必要？
        if v == rid then
            UID_TO_RID[uid] = nil
        end
    end

    obj.number = obj.number - 1
    if obj.number > 0 or not obj.wait_close then
        return
    end
    skynet.timeout(60 * 100, function ()
        logger.info("kill %08x wait %s", obj.handle, obj.wait_close)
        skynet.kill(obj.handle)
    end)
end

local CMD = {}

function CMD.enter(uid, rid)
    logger.debug("enter uid %d rid %s", uid, rid)
    if UID_TO_RID[uid] then
        if UID_TO_RID[uid] ~= rid then
            rid = UID_TO_RID[uid]
            local obj = RID_TO_SERVICE[rid]
            return {code = code.SEAT_ALREAY_IN_ANOTHER_ROOM, handle = obj.handle, rid = rid}  
        end
        local obj = RID_TO_SERVICE[rid]
        return {code = code.OK, rid = rid, handle = obj.handle}
    end

    local obj = acquire_service(uid, rid)
    if RID_TO_NUMBER[rid] >= 4 then
        return {code = code.SEAT_ALREAY_FULL}
    end

    RID_TO_NUMBER[rid] = RID_TO_NUMBER[rid] + 1
    UID_TO_RID[uid] = rid
    return {code = code.OK, rid = rid, handle = obj.handle}
end

function CMD.leave(uid)
    logger.debug("leave uid %s rid %s",uid, UID_TO_RID[uid])
    if not UID_TO_RID[uid] then
        return
    end
    local rid = UID_TO_RID[uid]
    RID_TO_NUMBER[rid] = RID_TO_NUMBER[rid] - 1
    if RID_TO_NUMBER[rid] > 0 then
        return
    end
    release_service(rid)
end

function CMD.close(rid)
    logger.info("close rid %s", rid)
    release_service(rid)
end

function CMD.save(rid)
    if not RID_TO_SERVICE[rid] then
        return
    end
    skynet.send(RID_TO_SERVICE[rid].handle, "lua", "save", rid)
end

function CMD.save_all()
    for rid, obj in pairs(RID_TO_SERVICE) do 
        logger.info("save rid %s", rid)
        skynet.send(obj.handle, "lua", "save", rid)
    end
end

function CMD.update()
    UPDATE_COUNT = UPDATE_COUNT + 1
    for _, v in ipairs(SERVICE_LIST) do 
        v.wait_close = true
        skynet.send(v.handle, "lua", "update")
    end
    local handle = skynet.newservice(SERVICE_NAME)
    local data = {
        RID_TO_SERVICE = RID_TO_SERVICE,
        UID_TO_RID = UID_TO_RID,
        RID_TO_NUMBER = RID_TO_NUMBER,
        UPDATE_COUNT = UPDATE_COUNT,
        SERVICE_LIST = SERVICE_LIST,
    }
    skynet.call(handle, 'lua', 'reload', data)
    return handle
end


function CMD.reload(data)
    RID_TO_SERVICE = data.RID_TO_SERVICE
    UID_TO_RID = data.UID_TO_RID
    RID_TO_NUMBER = data.RID_TO_NUMBER
    UPDATE_COUNT = data.UPDATE_COUNT
    SERVICE_LIST = data.SERVICE_LIST
    -- 如果更新需要适配数据，只需在下面添加代码
    
end

if mode == "save" then
    skynet.start(function ()
        skynet.call(".seat", "lua", "save_all")
        skynet.exit()
    end)
else
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
end