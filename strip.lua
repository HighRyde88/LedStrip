local led_state = '0'
local led_values = {}
led_values.hue = 0
led_values.sat = 255
led_values.val = 0
led_values.mode = "static"

local buffer_state = false
local gradient_tmr = tmr.create()
--==========================================================================================
local temp = nil
function save_brightness(br)
    if file.open("strip_values.txt", "r") then 
        temp = sjson.decode(file.read())
        file.close()
    end 

    temp.val = br

    if file.open("strip_values.txt", "w+") then 
        file.write(sjson.encode(temp))
        file.close()
    end 
    temp = nil
end

function save_color(hue, sat)
    if file.open("strip_values.txt", "r") then 
        temp = sjson.decode(file.read())
        file.close()
    end 

    temp.hue = hue
    temp.sat = sat

    if file.open("strip_values.txt", "w+") then 
        file.write(sjson.encode(temp))
        file.close()
    end 
    temp = nil
end
--==========================================================================================
function copy(src)
    local t2 = {}
    for k,v in pairs(src) do
      t2[k] = v
    end
    return t2
end
--==========================================================================================
function buffer_init()
    if buffer_state == false then 
        local p = dofile("eus_params.lua")
        buffer = ws2812.newBuffer(tonumber(p.leds_num), 3)
    
        buffer:fill(0,0,0)
        ws2812.write(buffer)

        print("Led buffer init: " .. p.leds_num .. " leds")

        buffer_state = true
    end
end
--==========================================================================================
do
    if file.open("strip_values.txt", "r") then
        led_values = sjson.decode(file.read())
        file.close() 
    else
        file.open("strip_values.txt", "w") 
        file.write(sjson.encode(led_values))
        file.close()     
    end
    
    saved_values = copy(led_values)
    led_values.val = 0

    if file.exists("eus_params.lua") then buffer_init() end
end
--==========================================================================================
gradient_tmr:register(25, tmr.ALARM_SEMI, function(t)
    buffer:fill(color_utils.hsv2grb(led_values.hue, led_values.sat, led_values.val))
    ws2812.write(buffer)
    led_values.hue = led_values.hue + 1
    if led_values.hue > 359 then led_values.hue = 0 end
    t:start()
end)
--==========================================================================================
function change_brightness(value) 
    print("The brightness is changing " .. "Led: " .. led_values.val .. " Asp: " .. value)

    local val_temp = led_values.val
    led_values.val = value

    tmr.create():alarm(1, tmr.ALARM_SEMI, function(t)
        if led_values.val ~= val_temp then

            if val_temp > led_values.val then 
                val_temp = val_temp - 1
            elseif val_temp < led_values.val then 
                val_temp = val_temp + 1
            end

            buffer:fill(color_utils.hsv2grb(led_values.hue, led_values.sat, val_temp))
            ws2812.write(buffer)
            t:start()
            return        
        else
            buffer:fill(color_utils.hsv2grb(led_values.hue, led_values.sat, val_temp))
            ws2812.write(buffer)
        end
    end)
end
--==========================================================================================
function change_color(green, red, blue) 
    print("The color changes " .. led_values.val)

    local green_temp, red_temp, blue_temp = color_utils.hsv2grb(led_values.hue, led_values.sat, led_values.val)

    tmr.create():alarm(5, tmr.ALARM_SEMI, function(t)
        if green_temp ~= green or red_temp ~= red or blue_temp ~= blue then

            if green_temp > green then green_temp = green_temp - 1  elseif green_temp < green then green_temp = green_temp + 1 end
            if red_temp > red then red_temp = red_temp - 1  elseif red_temp < red then red_temp = red_temp + 1 end
            if blue_temp > blue then blue_temp = blue_temp - 1  elseif blue_temp < blue then blue_temp = blue_temp + 1 end

            buffer:fill(green_temp, red_temp, blue_temp)
            ws2812.write(buffer)

            t:start()
            return
        end
    end)
end
--==========================================================================================
function change_state(state)
    if state == '0' and led_state == '1' then
        saved_values.val = led_values.val
        change_brightness(0)
        if led_values.mode == "gradient" then gradient_tmr:stop() end
    elseif state == '1' and led_state == '0' then
        change_brightness(saved_values.val)
        if led_values.mode == "gradient" then gradient_tmr:start() end
    end
end
--==========================================================================================
function new_message(client, topic, data)

    if topic == topicStateSub then
        change_state(data)
        led_state = data
        mqtt_client:publish(topicStateStatus, data, 0, 0, function(client) end)
    end

    if topic == topicColorSub then
        if data == "#000000" then return end
        local r = tonumber(string.format("0x%s", data:sub(2, 3)))
        local g = tonumber(string.format("0x%s", data:sub(4, 5)))
        local b = tonumber(string.format("0x%s", data:sub(6, 7)))
        change_color(g, r, b)
        mqtt_client:publish(topicColorStatus, data, 0, 0, function(client) end)  
    end

    if topic == topicBrightnessSub then
        local value = math.floor(tonumber((255 / 100) * data))
        if led_state == '1' then change_brightness(value) elseif led_state == '0' then saved_values.val = value end
        mqtt_client:publish(topicBrightnessStatus, data, 0, 0, function(client) end) 
        save_brightness(value)
    end

    if topic == topicModeSub then
        led_values.mode = data

        if led_values.mode == "static" then 
            gradient_tmr:stop() 
            led_values.sat = saved_values.sat 
            local g, r, b = color_utils.hsv2grb(led_values.hue, led_values.sat, led_values.val)

            local brg = math.floor(tonumber((led_values.val / 255) * 100)) + 1
            
            client:publish(topicColorStatus, string.format("#%02x%02x%02x", r, g, b), 0, 0, function(client) end)
            client:publish(topicBrightnessStatus, brg, 0, 0, function(client) end)
        end

        if led_values.mode == "gradient" then 
            led_values.sat = 255 
            if led_state == "1" then gradient_tmr:start() end
        end
        mqtt_client:publish(topicModeStatus, data, 0, 0, function(client) end)
    end
end
