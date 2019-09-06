local cjson = require "cjson"
local skynet = require "skynet"
local crypt = require "skynet.crypt"


function cjson_encode(obj)
	return cjson.encode(obj)
end

function cjson_decode(json)
	return cjson.decode(json)
end

function cjson_default_parse_by_array_mode(tab)
    setmetatable(tab, {
        __index = {__default_parse_by_array_mode__ = 1}
    })
end

function skynet_time()
	return math.ceil(skynet.time())
end

function addslashes(str)
    return string.gsub(str, ".", function (c)
        if c == "\\" then
            return "\\\\"
        end
        return c
    end)
end

--创建定时器
function create_timeout(ti, func, ...)
    local active = true
    local args = {...}
    skynet.timeout(ti, function () 
        if active then
            active = false
            func(table.unpack(args))
        end
    end)
    local timer = {}

    timer.is_timeout = function ()
    	return not active
    end
    timer.delete = function () 
    	local is_active = active
    	active = false
    	return is_active
	end
    return timer
end

--根据权重筛选
function key_rand(obj)
    local weight = {}
    local t = 0
    for k, v in ipairs(obj) do
        t = t + v.weight
        weight[k] = t
    end
    local c = math.random(0, t)
    for k, v in ipairs(weight) do 
        if c < v then
            return k
        end
    end
    return #weight
end

--bool转为整型
function bool_to_int(val)
    if val then 
        return 1
    else
        return 0
    end
end

--初始化为默认值
function init_inc(old_val,default_val,inc_val)
    if not old_val then
        old_val = default_val
    end
    return old_val + inc_val
end

--两者取较大值
function max(val1,val2)
    if val1>val2 then
        return val1
    end
    return val2
end

--两者取最小值
function min(val1, val2)
    if val1 < val2 then
        return val1
    end
    return val2
end

--列表转为发送数据
function empty_to_data(t)
    if not t or table.empty(t) then
        return nil
    end
    return t
end

--列表随机一个值
function list_rand(obj)
    local index = math.random(1, #obj)
    return obj[index]
end


function per_hour_timer(f, ...)      
    while true do
        local now = os.date("*t", skynet_time())                          -- 每1小时进入循环
        local t = (59 - now.min) * 60 * 100 + (60 - now.sec) * 100
        skynet.sleep(t)  
        f(...)
    end
end

function per_day_timer(f, ...)
    while true do
        local now = os.date("*t", skynet_time())
        local t = (23 - now.hour ) * 3600 * 100 + (59 - now.min) * 60 * 100 + (60 - now.sec) * 100
        skynet.sleep(t)
        f(...) 
    end
end

-- 1 time = 0.01s
function per_timer(time, f, ...)
    while true do 
        skynet.sleep(time)
        f(...)
    end
end


--创建token
function token_create(uid, timestamp, password, secret)
    local s = string.format("%s:%s:%s", uid, timestamp, password)
    s = crypt.base64encode(crypt.desencode(secret, s))
    return s:gsub("[+/]", function (c)
        if c == '+' then
            return '-'
        else
            return '_'
        end
    end)
end

--解析token
function token_parse(token, secret)
    token = token:gsub("[-_]", function (c)
        if c == '-' then
            return '+'
        else
            return '/'
        end
    end)
    local s = crypt.desdecode(secret, crypt.base64decode(token))
    local uid, timestamp, password = s:match("([^:]+):([^:]+):(.+)")
    return uid, timestamp, password
end

function time_now_str()
    return os.date("%Y-%m-%d %H:%M:%S", skynet_time())
end

function time_now_utc_str()
	local t = skynet.time()
	ts = string.format("%0.1f", t)
	t = string.split(ts, ".")[1]
	f = string.split(ts, ".")[2]
	t = os.date("!*t", tonumber(t))
	t = os.time({year=t.year, month=t.month, day=t.day, hour=t.hour, min=t.min ,sec=t.sec})
	return os.date("%Y-%m-%d", t) .. "T" .. os.date("%H:%M:%S", t) .. "." .. f .. "Z"
end

function is_robot(uid)
    return tonumber(uid) < 1000000
end

function is_include_channel(uid_channel, include_channel, not_include_channel)
    if not include_channel then
        return false
    end
    if not_include_channel and table.member(not_include_channel, uid_channel) then
        return false
    end

    if table.member(include_channel, 0) then
        return true
    elseif table.member(include_channel, uid_channel) then
        return true
    end
    return false
end

function is_include_version(version, include_version, not_include_version)
    if not include_version then
        return false
    end
    if not_include_version then
        for _, v in ipairs(not_include_version) do
            if string.find(version, v) == 1 then
                return false
            end
        end
    end
    for _, v in ipairs(include_version) do 
        if string.find(version, v) == 1 then
            return true
        end
    end
    return false
end
