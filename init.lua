local wifi_config = {}
wifi_config.auto = true
wifi_config.save = true
wifi_config.ssid = ""
wifi_config.pwd = ""

prefix = 1407717

ws2812.init(ws2812.MODE_SINGLE)

local wifi_old_status = wifi.STA_IDLE
local wifi_status = wifi.STA_IDLE
function wifi_check()
    wifi_status = wifi.sta.status()
    if wifi_status ~= wifi_old_status then
        wifi_old_status = wifi_status

        if wifi_status == wifi.STA_IDLE then
            print("IDLE")
        end

        if wifi_status == wifi.STA_CONNECTING then
            local ssid, password, bssid_set, bssid=wifi.sta.getconfig()
            print("Attempting to connect to an access point: " .. ssid)
        end

        if wifi_status == wifi.STA_WRONGPWD then
            print("Incorrect password")
        end

        if wifi_status == wifi.STA_APNOTFOUND then
            print("The access point was not found")
        end

        if wifi_status == wifi.STA_FAIL then
            print("Station error")
        end

        if wifi_status == wifi.STA_GOTIP then
            print(string.format("Successfully connected: ip %s, netmask %s, gateway %s",  wifi.sta.getip()))  
            dofile("strip.lua")
            dofile("mqtt.lua")  
        end
    end
end

function delayed_start(config)
    ws2812.write(ws2812.newBuffer(10, 3))

    print(string.format("Starting the LED controller: " .. string.format("ESP%X", prefix)))

    --or gpio.read(3) == gpio.LOW

    if file.exists("eus_params.lua") == false then
        print(string.format("An access point has been created for connection: " .. string.format("ESP%X", prefix)))

        enduser_setup.manual(false)
        enduser_setup.start(string.format("ESP%X", prefix), function() 
            local p = dofile("eus_params.lua")
            wifi_config.ssid = p.wifi_ssid
            wifi_config.pwd = p.wifi_password
            wifi.sta.config(wifi_config)
            node.restart()
        end)
    else
        tmr.create():alarm(500, tmr.ALARM_AUTO, function() wifi_check() end)
        wifi.sta.connect()
    end

end

do
    gpio.mode(3, gpio.INPUT)
    tmr.create():alarm(1000, tmr.ALARM_SINGLE, function() delayed_start(wifi_config) end)
end



