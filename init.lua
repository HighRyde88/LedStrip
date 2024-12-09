local wifi_config = {}
wifi_config.auto = true
wifi_config.save = true
wifi_config.ssid = ""
wifi_config.pwd = ""

local hostname = 0

ws2812.init(ws2812.MODE_SINGLE)
rainbow_buffer = ws2812.newBuffer(360, 3)

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
            local p = dofile("eus_params.lua")
            hostname = p.host_name
            if (wifi.sta.sethostname(hostname) == true) then
                print("Hostname was successfully changed: " .. hostname)
            else
                print("Hostname was not changed")
            end

            mqtt_client:connect(mqtt_config.host, mqtt_config.port, false)
        end
    end
end

function delayed_start(config)
    if file.exists("eus_params.lua") == true then local p = dofile("eus_params.lua") hostname = p.host_name else hostname = string.format("ESP%X", node.chipid()) end

    print(string.format("Starting the LED controller: " .. hostname))

    --or gpio.read(3) == gpio.LOW

    if file.exists("eus_params.lua") == false then
        print(string.format("An access point has been created for connection: " .. hostname))

        local ssid, password, bssid_set, bssid=wifi.sta.getconfig()
        if ssid ~= "" then wifi.sta.clearconfig() end

        enduser_setup.manual(false)
        enduser_setup.start(hostname, function() 
            local p = dofile("eus_params.lua")
            wifi_config.ssid = p.wifi_ssid
            wifi_config.pwd = p.wifi_password
            wifi.sta.config(wifi_config)
            node.restart()
        end)
    else
        dofile("strip.lua")
        dofile("mqtt.lua")
        tmr.create():alarm(500, tmr.ALARM_AUTO, function() wifi_check() end)
        wifi.setmode(wifi.STATION)
        wifi.sta.connect()
    end

end

do
    gpio.mode(3, gpio.INPUT)
    ws2812.write(rainbow_buffer)
    tmr.create():alarm(1500, tmr.ALARM_SINGLE, function() delayed_start(wifi_config) end)
end



