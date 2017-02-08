require "catui"

local love = love
local redis = require 'redis'
local settings = require 'settings'
local redisConfig = settings.redisConfig


local redisClient
local redisData = {} -- 缓存数据

local keys
local hkeys

local function connectRedis()
    redisClient = redis.connect(redisConfig)
    redisClient:select(redisConfig.db)
end

local function useDefaultFont(size)
    love.graphics.setColor(0, 0, 0)
    love.graphics.setBlendMode("alpha")
    local font = love.graphics.newFont(size)
    love.graphics.setFont(font)
end

local function useHanZiFont(size)
    local font = love.graphics.newFont("simkai.ttf", size)
    love.graphics.setFont(font)
end

-- REDIS KEY类型
local REDIS_KEY_TYPE = {
    [1] = 'string',
    [2] = 'hash',
}

-- unicode_to_utf8
local function unicode_to_utf8(convertStr)
    if type(convertStr) ~= "string" then
        return convertStr
    end
    local bit = require("bit")
    local resultStr = ""
    local i = 1
    while true do
        local num1 = string.byte(convertStr, i)
        local unicode
        if num1 ~= nil and string.sub(convertStr, i, i + 1) == "\\u" then
            unicode = tonumber("0x" .. string.sub(convertStr, i + 2, i + 5))
            i = i + 6
        elseif num1 ~= nil then
            unicode = num1
            i = i + 1
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

function love.load(arg)
    connectRedis()
    love.graphics.setBackgroundColor(35, 42, 50, 255)
    mgr = UIManager:getInstance()

    keys = redisClient:keys('*')
    table.sort(keys, function(a, b) return a < b end) -- key排序
    local len = #keys
    local keyHight = 20
    local keyWidth = 200

    local contentKey = UIContent:new()
    contentKey:setPos(0, 0)
    contentKey:setSize(keyWidth, 600)
    contentKey:setContentSize(keyWidth, keyHight * len)
    mgr.rootCtrl.coreContainer:addChild(contentKey)

    local contentValue = UIContent:new()
    contentValue:setPos(200, 0)
    contentValue:setSize(600, 600)
    contentValue:setContentSize(600, 600)
    mgr.rootCtrl.coreContainer:addChild(contentValue)

    local keyTypeEdit = UIEditText:new()
    keyTypeEdit:setPos(0, 0)
    keyTypeEdit:setSize(600, 20)
    contentValue:addChild(keyTypeEdit)

--    local contentHashList = UIContent:new()
--    contentHashList:setPos(0, 20)
--    contentHashList:setSize(600, 280)
--    contentHashList:setContentSize(600, 280)
--    contentValue:addChild(contentHashList)
--
--    local contentHashKey = UIContent:new()
--    contentHashKey:setPos(0, 300)
--    contentHashKey:setSize(600, 100)
--    contentHashKey:setContentSize(600, 100)
--    contentValue:addChild(contentHashKey)
--
--    local contentHashValue = UIContent:new()
--    contentHashValue:setPos(0, 400)
--    contentHashValue:setSize(600, 200)
--    contentHashValue:setContentSize(600, 200)
--    contentValue:addChild(contentHashValue)

    for i = 1, len do
        local keyEditText = UIEditText:new()
        keyEditText:setPos(0, (i - 1) * keyHight)
        keyEditText:setSize(keyWidth, keyHight)
        keyEditText:setText("\t" .. keys[i])
        contentKey:addChild(keyEditText)

        local hashContent
        keyEditText.events:on(UI_CLICK, function()
            if hashContent then
                contentValue:removeChild(hashContent)
            end
            local keyType = redisClient:type(keys[i])
            keyTypeEdit:setText(keyType .. "\t : \t" .. keys[i])

            if keyType == REDIS_KEY_TYPE[1] then
                local value = redisClient:get(keys[i])
                hashContent = UIEditText:new()
                hashContent:setPos(0, 20)
                hashContent:setSize(600, 580)
                hashContent:setText(value)
                contentValue:addChild(hashContent)
            elseif keyType == REDIS_KEY_TYPE[2] then
                hkeys = redisClient:hkeys(keys[i])
                table.sort(hkeys, function(a, b) return a < b end)
                local hashLen = #hkeys

                hashContent = UIContent:new()
                hashContent:setPos(0, 20)
                hashContent:setSize(600, 580)
                hashContent:setContentSize(600, 580)
                contentValue:addChild(hashContent)

                local hashTable = UIContent:new()
                hashTable:setPos(0, 0)
                local tableHight = (hashLen+1)*keyHight + keyHight
                tableHight = tableHight > 280 and 280 or tableHight
                hashTable:setSize(600, tableHight)
                hashTable:setContentSize(600, (hashLen+1)*keyHight)
                hashContent:addChild(hashTable)

                local tableHeadText = UIEditText:new()
                tableHeadText:setPos(0, 0)
                tableHeadText:setSize(600, keyHight)
                tableHeadText:setText(string.format("%10s%20s%50s", 'row', 'key', 'value'))
                hashTable:addChild(tableHeadText)

                for j = 1, hashLen do
                    local hashValueEdit = UIEditText:new()
                    hashValueEdit:setPos(0, (j-1)*keyHight + keyHight)
                    hashValueEdit:setSize(600, keyHight)
                    hashValueEdit:setText(string.format("%10s%20s%50s", j, hkeys[j], '...'))
                    hashTable:addChild(hashValueEdit)

                    hashValueEdit.events:on(UI_CLICK, function()
                        -- 增加key
                        local hashKeyEdit = UIEditText:new()
                        hashKeyEdit:setPos(0, tableHight)
                        hashKeyEdit:setSize(600, 50)
                        hashKeyEdit:setText("key\t:\t" .. hkeys[j])
                        hashContent:addChild(hashKeyEdit)

                        -- 显示value
                        local hashValue = redisClient:hget(keys[i], hkeys[j])
                        local hashValueEdit = UIEditText:new()
                        hashValueEdit:setPos(0, tableHight + 50)
                        hashValueEdit:setSize(600, 2000)
                        hashValueEdit:setText("value\t:\t" .. hashValue)
                        hashContent:addChild(hashValueEdit)
                    end)
                end
            end
        end)
    end
end

function love.update(dt)
    mgr:update(dt)
end

function love.draw()
    mgr:draw()
end

function love.mousemoved(x, y, dx, dy)
    mgr:mouseMove(x, y, dx, dy)
end

function love.mousepressed(x, y, button, isTouch)
    mgr:mouseDown(x, y, button, isTouch)
end

function love.mousereleased(x, y, button, isTouch)
    mgr:mouseUp(x, y, button, isTouch)
end

function love.keypressed(key, scancode, isrepeat)
    mgr:keyDown(key, scancode, isrepeat)
end

function love.keyreleased(key)
    mgr:keyUp(key)
end

function love.wheelmoved(x, y)
    mgr:whellMove(x, y)
end

function love.textinput(text)
    mgr:textInput(text)
end
