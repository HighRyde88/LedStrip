local led_state = '0'
local led_num = 0
local led_values = {}
led_values.hue = 0
led_values.sat = 255
led_values.val = 0
led_values.mode = "static"
led_values.brg = 0

local buffer_state = false
local gradient_tmr = tmr.create()
local strip_tmr = tmr.create()
--==========================================================================================
local temp = nil
function save_brightness(br, br_prc)
    if file.open("strip_values.txt", "r") then 
        temp = sjson.decode(file.read())
        file.close()
    end 

    temp.val = br
    temp.brg = br_prc

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
        led_num = tonumber(p.leds_num)
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

    for i = 1, 360 do
        rainbow_buffer:set(i, color_utils.hsv2grb(i - 1, 255, 255))
    end


    if file.exists("eus_params.lua") then buffer_init() end
end
--==========================================================================================
local timer_divide = 0
local old_hue, old_sat, old_val = 0
strip_tmr:register(1, tmr.ALARM_AUTO, function(t) 
    if led_values.mode == "static" or led_values.mode == "gradient" then
        if led_values.hue ~= old_hue or led_values.sat ~= old_sat or led_values.val ~= old_val then
            old_hue = led_values.hue
            old_sat = led_values.sat
            old_val = led_values.val
            buffer:fill(color_utils.hsv2grb(led_values.hue, led_values.sat, led_values.val))
            ws2812.write(buffer)
        end
    elseif led_values.mode == "rainbow" then

        if timer_divide ~= 20 then timer_divide = timer_divide + 1 return elseif timer_divide == 20 then timer_divide = 0 end
        rainbow_buffer:shift(1, pixbuf.SHIFT_CIRCULAR)
        rainbow_v = rainbow_buffer:sub(1, led_num)
        for i = 1, led_num do
            local h, s, v = color_utils.grb2hsv(rainbow_v:get(i))
            v = led_values.val
            rainbow_v:set(i, color_utils.hsv2grb(h, s, v))
        end
        ws2812.write(rainbow_v)

    end
end)
strip_tmr:start()

gradient_tmr:register(25, tmr.ALARM_SEMI, function(t)
    led_values.hue = led_values.hue + 1
    if led_values.hue > 359 then led_values.hue = 0 end
    t:start()
end)
--==========================================================================================
function change_brightness(value, value_prc) 
    local temp_val = 0
    if value == nil then 
        saved_values.val = led_values.val
    else
        temp_val = value
        if value_prc ~= nil then save_brightness(value, value_prc) end
    end
    tmr.create():alarm(1, tmr.ALARM_SEMI, function(t)
        if led_values.val ~= temp_val then
            if led_values.val < temp_val then
                led_values.val = led_values.val + 1
            elseif led_values.val > temp_val then
                led_values.val = led_values.val - 1
            end
            t:start()
            return        
        end
        t:unregister()
    end)
end
--==========================================================================================
function change_state(state)
    if state == '0' and led_state == '1' then
        change_brightness(nil, nil)
        if led_values.mode == "gradient" then gradient_tmr:stop() end
    elseif state == '1' and led_state == '0' then
        change_brightness(saved_values.val, nil)
        if led_values.mode == "gradient" then gradient_tmr:start() end
    end
end
--==========================================================================================
function change_color(green, red, blue) 
   local green_temp, red_temp, blue_temp = color_utils.hsv2grb(led_values.hue, led_values.sat, 255)

   save_color(led_values.hue, led_values.sat)

    tmr.create():alarm(1, tmr.ALARM_SEMI, function(t)
        if green_temp ~= green or red_temp ~= red or blue_temp ~= blue then

            if green_temp > green then green_temp = green_temp - 1  elseif green_temp < green then green_temp = green_temp + 1 end
            if red_temp > red then red_temp = red_temp - 1  elseif red_temp < red then red_temp = red_temp + 1 end
            if blue_temp > blue then blue_temp = blue_temp - 1  elseif blue_temp < blue then blue_temp = blue_temp + 1 end

            led_values.hue, led_values.sat, val = color_utils.grb2hsv(green_temp, red_temp, blue_temp)
            t:start()
            return
        end
        t:unregister()
    end)
end
--==========================================================================================
function new_message(client, topic, data)

    if topic == topicStateSub then
        change_state(data)
        led_state = data
        mqtt_client:publish(topicStateStatus, data, 0, 0, function(client) end)
    end

    if topic == topicBrightnessSub then
        local br_value = tonumber((255 / 100) * data)
        if led_state == '1' then 
            change_brightness(br_value, data)
        else 
            saved_values.val = br_value 
            save_brightness(br_value, data)
        end
        mqtt_client:publish(topicBrightnessStatus, data, 0, 0, function(client) end) 
    end

    if topic == topicColorSub then
        if data == "#000000" then return end

        set_static()

        local r = tonumber(string.format("0x%s", data:sub(2, 3)))
        local g = tonumber(string.format("0x%s", data:sub(4, 5)))
        local b = tonumber(string.format("0x%s", data:sub(6, 7)))
        if led_state == '1' then 
            change_color(g, r, b) 
        else 
            led_values.hue, led_values.sat, val = color_utils.grb2hsv(g, r, b)
            save_color(led_values.hue, led_values.sat) 
        end

        mqtt_client:publish(topicColorStatus, data, 0, 0, function(client) end) 
    end


    if topic == topicModeSub then
        led_values.mode = data

        if led_values.mode == "static" then 
            set_static()
            return
        end

        if led_values.mode == "gradient" then 
            led_values.sat = 255 
            if led_state == "1" then gradient_tmr:start() end
        end

        mqtt_client:publish(topicModeStatus, data, 0, 0, function(client) end)
    end
end

function set_static()
    gradient_tmr:stop() 
    strip_tmr:start()
    led_values.mode = "static"
    local g, r, b = color_utils.hsv2grb(led_values.hue, led_values.sat, 255)
    save_color(led_values.hue, led_values.sat)
    mqtt_client:publish(topicColorStatus, string.format("#%02x%02x%02x", r, g, b), 0, 0, function(client) end)
    mqtt_client:publish(topicModeStatus, "static", 0, 0, function(client) end)
end