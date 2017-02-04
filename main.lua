package.path = "./?.lua;" .. package.path

local redis = require 'redis'
local redisClient 
local redisConfig = {
	host = '10.10.2.63',
	port = 6379,
	db   = 1,
}

local function connectRedis()
	redisClient = redis.connect(redisConfig)
	redisClient:select(redisConfig.db)
end 

local keys
function love.load() --资源加载回调函数，仅初始化时调用一次
	connectRedis()
	-- redisClient:set('test', '1111111')
	-- local value = redisClient:get('test')
	-- love.window.showMessageBox("testRedis", value)
end

local function useDefaultFont(text, x, y, size)
	love.graphics.setColor(255,0,0)
	love.graphics.setBlendMode("alpha")
	local font = love.graphics.newFont( size )
	love.graphics.setFont(font)
	love.graphics.print(text,x,y+size)

end

function love.draw() --绘图回调函数，每周期调用
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(255, 255, 255)
	love.graphics.rectangle("fill", 0, 0, 800, 600)

	love.graphics.setColor(0, 0, 0)
	love.graphics.line(200, 0, 200, 600)

	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("line", 0, 0, 800, 600)

	keys = redisClient:keys('*')
	table.sort(keys, function(a, b) return a < b end) -- key排序
	local len = #keys
	local keyHight = 30
	for i = 1, len do
		love.graphics.setColor(0, 0, 255)
		love.graphics.rectangle("line", 0,  (i - 1) * keyHight, 200, 30)
		useDefaultFont(keys[i], 20 , 2 + (i - 1) * keyHight, 10)
	end
end

function love.update(dt) --更新回调函数，每周期调用

end

function love.keypressed(key) --键盘检测回调函数，当键盘事件触发是调用

end