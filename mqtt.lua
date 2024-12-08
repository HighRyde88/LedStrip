local mqtt_config = {}
mqtt_config.host = "m9.wqtt.ru"
mqtt_config.port = 14144
mqtt_config.login = "u_AJLQ40"
mqtt_config.password = "YFkAJ6B1"
mqtt_config.client_id = hostname
mqtt_config.keepalive = 120

topicStateSub = "ESP/state/" .. hostname
topicColorSub = "ESP/color/" .. hostname
topicBrightnessSub = "ESP/brightness/" .. hostname
topicModeSub = "ESP/mode/" .. hostname

topicStateStatus = "ESP/state/status/" .. hostname
topicColorStatus= "ESP/color/status/" .. hostname
topicBrightnessStatus = "ESP/brightness/status/" .. hostname
topicModeStatus = "ESP/mode/status/" .. hostname

mqtt_client = mqtt.Client(mqtt_config.client_id, mqtt_config.keepalive, mqtt_config.login, mqtt_config.password)

local keepalive_tmr = tmr.create()
keepalive_tmr:register((mqtt_config.keepalive * 1000) / 2, tmr.ALARM_SEMI, function(t)
    print("Keepalive update.")
    mqtt_client:publish("ESP/keepalive/" .. hostname, 0, 0, 0, function(client) end)
    t:start()
end)

mqtt_client:connect(mqtt_config.host, mqtt_config.port, false, function(client) 
    client:subscribe(topicStateSub, 0, function(client) end)
    client:subscribe(topicColorSub, 0, function(client) end)
    client:subscribe(topicBrightnessSub, 0, function(client) end)
    client:subscribe(topicModeSub, 0, function(client) end)

    if file.open("strip_values.txt", "r") then
        local p = sjson.decode(file.read())
        local g, r, b = color_utils.hsv2grb(p.hue, p.sat, 255)
        local rgb = string.format("#%02x%02x%02x", r, g, b)

        client:publish(topicStateStatus, 0, 0, 0, function(client) end)
        client:publish(topicColorStatus, rgb, 0, 0, function(client) end)
        client:publish(topicBrightnessStatus, p.brg, 0, 0, function(client) end)
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















