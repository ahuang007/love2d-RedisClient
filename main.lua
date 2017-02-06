package.path = "./?.lua;" .. package.path

local love = love
local redis = require 'redis'
local redisClient 
local redisConfig = {
	host = '10.10.2.63',
	port = 6379,
	db   = 2,
}

local redisData = {}

local function connectRedis()
	redisClient = redis.connect(redisConfig)
	redisClient:select(redisConfig.db)
end

local function useDefaultFont(text, x, y, size)
	love.graphics.setColor(0, 0, 0)
	love.graphics.setBlendMode("alpha")
	local font = love.graphics.newFont(size)
	love.graphics.setFont(font)
	love.graphics.print(text, x, y)
end

local function useHanZiFont()
	local font = love.graphics.newFont("simkai.ttf", 15)
	love.graphics.setFont(font)
end

local keys
local hkeys

-- REDIS KEY类型
local REDIS_KEY_TYPE = {
	[1]	= 'string',
	[2]	= 'hash',
}

-- unicode_to_utf8
local function unicode_to_utf8(convertStr)
	if type(convertStr) ~= "string" then
		return convertStr
	end
	local bit = require("bit")
	local resultStr=""
	local i=1
	while true do
		local num1 = string.byte(convertStr, i)
		local unicode
		if num1 ~= nil and string.sub(convertStr, i, i+1) == "\\u" then
			unicode = tonumber("0x" .. string.sub(convertStr, i+2, i+5))
			i = i+6
		elseif num1 ~= nil then
			unicode = num1
			i = i+1
		else
			break
		end
		if unicode <= 0x007f then
			resultStr = resultStr .. string.char(bit.band(unicode, 0x7f))
		elseif unicode >= 0x0080 and unicode <= 0x07ff then
			resultStr = resultStr .. string.char(bit.bor(0xc0, bit.band(bit.rshift(unicode, 6), 0x1f)))
			resultStr = resultStr .. string.char(bit.bor(0x80, bit.band(unicode, 0x3f)))
		elseif unicode >= 0x0800 and unicode <= 0xffff then
			resultStr = resultStr .. string.char(bit.bor(0xe0, bit.band(bit.rshift(unicode, 12), 0x0f)))
			resultStr = resultStr .. string.char(bit.bor(0x80, bit.band(bit.rshift(unicode, 6), 0x3f)))
			resultStr = resultStr .. string.char(bit.bor(0x80, bit.band(unicode, 0x3f)))
		end
	end
	resultStr = resultStr .. '\0'
	return resultStr
end

local function drawKeyInfo(key)
	local keyType = redisClient:type(key)
	love.graphics.print(keyType .. " : ", 220, 10)
	love.graphics.print(key, 300, 10)
	if keyType == REDIS_KEY_TYPE[1] then
		local value = redisClient:get(key)
		love.graphics.print(value, 220, 40)
		hkeys = {key}
	elseif keyType == REDIS_KEY_TYPE[2] then
		love.graphics.rectangle("line", 200, 30, 600, 30)
		love.graphics.print("row", 220, 35)
		love.graphics.print("key", 320, 35)
		love.graphics.print("value", 420, 35)

		hkeys = redisClient:hkeys(key)
		table.sort(hkeys, function(a, b) return a < b end)
		local hashLen = #hkeys
		local initX = 200
		local initY = 60
		local height = 30
		for i = 1, hashLen do
			love.graphics.setBlendMode("alpha")
			local y = (i - 1) * height + initY
			love.graphics.rectangle("line", initX, y, 600, height)
			love.graphics.print(i, initX + 20, y + 5)
			love.graphics.print(hkeys[i], initX + 120, y + 5)
			love.graphics.print('...', initX + 220, y + 5)
		end
	end
end

function love.load() --资源加载回调函数，仅初始化时调用一次
	connectRedis()
end

local selectIndex = 1
function love.draw() --绘图回调函数，每周期调用
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(255, 255, 255)
	love.graphics.rectangle("fill", 0, 0, 800, 600)

	love.graphics.setColor(0, 0, 0)
	love.graphics.line(200, 0, 200, 600)

	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("line", 0, 0, 800, 600)

	love.graphics.rectangle("line", 200, 0, 800, 30)

	-- keys *
	keys = redisClient:keys('*')
	table.sort(keys, function(a, b) return a < b end) -- key排序
	local len = #keys
	local keyHight = 30
	for i = 1, len do
		love.graphics.setBlendMode("multiply")
		love.graphics.setColor(0, 0, 255)
		love.graphics.rectangle("line", 0,  (i - 1) * keyHight, 200, 30)

		useDefaultFont(keys[i], 20, (i - 1) * keyHight + 10, 10)
	end
	useHanZiFont()
	drawKeyInfo(keys[selectIndex])
end

function love.update(dt) --更新回调函数，每周期调用

end

function love.keypressed(key) --键盘检测回调函数，当键盘事件触发是调用

end

local function drawHashInfo(tb, key)
	love.window.showMessageBox(tb, "key   :" .. key .. " \n " .. "value : " .. redisClient:hget(tb,  key))
end

function love.mousepressed(x, y, button, istouch)
	if button == 1 then
		if x > 0 and x < 200 and y > 0 and y < #keys * 30 then -- 鼠标在keys上
			selectIndex = math.floor(y/30) + 1
			drawKeyInfo(keys[selectIndex])
		end

		if x > 200 and x < 800 and y > 60 and y < #hkeys * 30 + 60 then -- 鼠标在values上
			local selectHashIndex = math.floor((y-60)/30) + 1
			drawHashInfo(keys[selectIndex], hkeys[selectHashIndex])
		end
	end
end