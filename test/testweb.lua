local skynet = require "skynet"
local logger = log4.get_logger("app")

local LOW_UID = 1
local HIG_UID = 100000
local TARGET_USER_ID = 3
local TARGET_USER_AMOUNT_NEARBY = 5

local user_info_list = {}

for uid=LOW_UID, HIG_UID do
    user_info_list[uid] = {
        uid = uid,
        ce = math.random(2147483647)
    }
end

local function get_ce_by_uid(uid)
    for k, v in ipairs(user_info_list) do
        if v.uid == uid then
            return v.ce
        end
    end
end

local function get_target_user_nearby_list()
    local target_user_nearby_list = {}
    for k, v in ipairs(user_info_list) do
        if v.uid ~= TARGET_USER_ID then
            table.insert(target_user_nearby_list, {
                uid = v.uid, ce = v.ce
            })
        end
        if TARGET_USER_AMOUNT_NEARBY == #target_user_nearby_list then
            return target_user_nearby_list
        end
    end
end

skynet.start(function()

    local begin_time = skynet.time()

    -- TODO:
    -- 1.获取目标用户的战斗力
    -- 2.通过最相对目标用户差值排序
    -- 3.获取前6个同时排除目标用户就是战斗力最接近的5个用户了

    local target_user_id = TARGET_USER_ID
    local target_user_ce = get_ce_by_uid(target_user_id)
    table.sort(user_info_list, function(a,b)
        local diff_value_a = a.ce - target_user_ce
        if target_user_ce > a.ce then
            diff_value_a = target_user_ce - a.ce
        end
        local diff_value_b = b.ce - target_user_ce
        if target_user_ce > b.ce then
            diff_value_b = target_user_ce - b.ce
        end
        return diff_value_a < diff_value_b
    end)
    local target_user_nearby_list = get_target_user_nearby_list()

    local end_time = skynet.time()
    print("处理耗时:", end_time - begin_time)
    print("------------------\n")
    
    print("目标玩家:")
    print(string.format("UID:%d\t战斗力:%d", target_user_id, target_user_ce))
    print("------------------\n")
    print(string.format("战斗力与目标接近的%d个玩家:", TARGET_USER_AMOUNT_NEARBY))
    for k, v in ipairs(target_user_nearby_list) do
        local a = v.ce
        local b = target_user_ce
        local diff_value = (a > b and {a-b} or {b-a})[1]
        print(string.format("UID:%d\t战斗力:%d\t相对目标玩家战斗力差值:%d", v.uid, v.ce, diff_value))
    end

    function myfunction ()
        n = n/nil
    end
    status, err = xpcall(myfunction, debug.traceback)
    logger.error("websocket process status: %s, err: %s", tostring(status), tostring())
end)
