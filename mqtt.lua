local mqtt_config = {}
mqtt_config.host = "m9.wqtt.ru"
mqtt_config.port = 14144
mqtt_config.login = "u_AJLQ40"
mqtt_config.password = "YFkAJ6B1"
mqtt_config.client_id = string.format("Esp8266_" .. string.format("%X", prefix))
mqtt_config.keepalive = 120

topicStateSub = string.format("Esp8266_%X/state", prefix)
topicColorSub = string.format("Esp8266_%X/color", prefix)
topicBrightnessSub = string.format("Esp8266_%X/brighntess", prefix)
topicModeSub = string.format("Esp8266_%X/mode", prefix)

topicKeepalive = string.format("Esp8266_%X/keepalive", prefix)

topicStateStatus = string.format("Esp8266_%X/state/status", prefix)
topicColorStatus = string.format("Esp8266_%X/color/status", prefix)
topicBrightnessStatus = string.format("Esp8266_%X/brighntess/status", prefix)
topicModeStatus = string.format("Esp8266_%X/mode/status", prefix)

mqtt_client = mqtt.Client(mqtt_config.client_id, mqtt_config.keepalive, mqtt_config.login, mqtt_config.password)

local keepalive_tmr = tmr.create()
keepalive_tmr:register((mqtt_config.keepalive * 1000) / 2, tmr.ALARM_SEMI, function(t)
    print("Keepalive update.")
    mqtt_client:publish(topicKeepalive, 0, 0, 0, function(client) end)
    t:start()
end)

do

    mqtt_client:connect(mqtt_config.host, mqtt_config.port, false, function(client) 
        client:subscribe(topicStateSub, 0, function(client) end)
        client:subscribe(topicColorSub, 0, function(client) end)
        client:subscribe(topicBrightnessSub, 0, function(client) end)
        client:subscribe(topicModeSub, 0, function(client) end)

        if file.open("strip_values.txt", "r") then
            local p = sjson.decode(file.read())
            local g, r, b = color_utils.hsv2grb(p.hue, p.sat, 255)
            local rgb = string.format("#%02x%02x%02x", r, g, b)
            local brg = math.floor(tonumber((p.val / 255) * 100)) + 1

            client:publish(topicStateStatus, 0, 0, 0, function(client) end)
            client:publish(topicColorStatus, rgb, 0, 0, function(client) end)
            client:publish(topicBrightnessStatus, brg, 0, 0, function(client) end)
            client:publish(topicModeStatus, "static", 0, 0, function(client) end)

            keepalive_tmr:start()
        end

        print("MQTT has been successfully connected")
    end)

    mqtt_client:on("message", function(client, topic, data) 
        print("Topic: " .. topic .. ", Data: " .. data)
        new_message(client, topic, data)
    end)
  
    mqtt_client:on("offline", function(client) 
        keepalive_tmr:stop()
    end)
end















