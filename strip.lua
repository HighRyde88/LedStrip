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
    led_values.val = 0

    aspiring_values = copy(led_values)
    saved_values = copy(led_values)
    saved_values.val = 255

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
    if value ~= nil then aspiring_values.val = value end
    print("The brightness is changing " .. "Led: " .. led_values.val .. " Asp: " .. aspiring_values.val)
    tmr.create():alarm(1, tmr.ALARM_SEMI, function(t)
        if led_values.val ~= aspiring_values.val then
            if led_values.val > aspiring_values.val then led_values.val = led_values.val - 1
            elseif led_values.val < aspiring_values.val then led_values.val = led_values.val + 1 
            end
            buffer:fill(color_utils.hsv2grb(led_values.hue, led_values.sat, led_values.val))
            ws2812.write(buffer)
            t:start()
            return        
        end
    end)
end
--==========================================================================================
function change_state(state)
    led_state = state
    if state == '0' then
        saved_values = copy(aspiring_values)
        aspiring_values.val = 0
        if led_values.mode == "gradient" then gradient_tmr:stop() end
    elseif state == '1' then
        aspiring_values = copy(saved_values)
        if led_values.mode == "gradient" then gradient_tmr:start() end
    end

    change_brightness(nil)
end
--==========================================================================================
function change_color(green, red, blue) 
    print("The color changes")
    if led_state == '1' then
        local led_green, led_red, led_blue = color_utils.hsv2grb(led_values.hue, led_values.sat, led_values.val)
        led_values.hue, led_values.sat, led_values.val = color_utils.grb2hsv(green, red, blue)
        aspiring_values.hue, aspiring_values.sat, aspiring_values.val = color_utils.grb2hsv(green, red, blue)
        tmr.create():alarm(5, tmr.ALARM_SEMI, function(t)
            if led_green ~= green or led_red ~= red or led_blue ~= blue then

                if led_green > green then led_green = led_green - 1  elseif led_green < green then led_green = led_green + 1 end
                if led_red > red then led_red = led_red - 1  elseif led_red < red then led_red = led_red + 1 end
                if led_blue > blue then led_blue = led_blue - 1  elseif led_blue < blue then led_blue = led_blue + 1 end

                buffer:fill(led_green, led_red, led_blue)
                ws2812.write(buffer)
                t:start()
                return
            end
        end)
    elseif led_state == '0' then
        led_values.hue, led_values.sat, val = color_utils.grb2hsv(green, red, blue)
    end
    save_color(led_values.hue, led_values.sat)
end
--==========================================================================================
function new_message(client, topic, data)

    if topic == topicStateSub then
        change_state(data)
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
        if led_state == '1' then 
            change_brightness(math.floor(tonumber((255 / 100) * data)))
        elseif led_state == '0' then
            saved_values.val = math.floor(tonumber((255 / 100) * data))
        end
        mqtt_client:publish(topicBrightnessStatus, data, 0, 0, function(client) end) 
        save_brightness(math.floor(tonumber((255 / 100) * data)))
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
