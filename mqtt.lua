mqtt_config = {}
mqtt_config.host = "m9.wqtt.ru"
mqtt_config.port = 14144
mqtt_config.login = "u_AJLQ40"
mqtt_config.password = "YFkAJ6B1"
mqtt_config.client_id = node.chipid()
mqtt_config.keepalive = 120

local hostname = 0

mqtt_client = mqtt.Client(mqtt_config.client_id, mqtt_config.keepalive, mqtt_config.login, mqtt_config.password)

local keepalive_tmr = tmr.create()
keepalive_tmr:register((mqtt_config.keepalive * 1000) / 2, tmr.ALARM_SEMI, function(t)
    print("Keepalive update.")
    mqtt_client:publish("ESP/keepalive/" .. hostname, 0, 0, 0, function(client) print("Keepalive update.") end)
    t:start()
end)

mqtt_client:on("message", function(client, topic, data) 
    print("Topic: " .. topic .. ", Data: " .. data)
    new_message(client, topic, data)
end)

mqtt_client:on("offline", function(client) 
    keepalive_tmr:stop()
end)

mqtt_client:on("connect", function(client) 

    if file.exists("eus_params.lua") == true then local p = dofile("eus_params.lua") hostname = p.host_name else hostname = string.format("ESP%X", node.chipid()) end

    topicStateSub = "ESP/state/" .. hostname
    topicColorSub = "ESP/color/" .. hostname
    topicBrightnessSub = "ESP/brightness/" .. hostname
    topicModeSub = "ESP/mode/" .. hostname

    topicStateStatus = "ESP/state/status/" .. hostname
    topicColorStatus= "ESP/color/status/" .. hostname
    topicBrightnessStatus = "ESP/brightness/status/" .. hostname
    topicModeStatus = "ESP/mode/status/" .. hostname

    client:subscribe(topicStateSub, 0, function(client) 
        print("The subscription is successful: " .. topicStateSub) 

        client:subscribe(topicColorSub, 0, function(client) 
            print("The subscription is successful: " .. topicColorSub) 

            client:subscribe(topicBrightnessSub, 0, function(client) 
                print("The subscription is successful: " .. topicBrightnessSub) 

                client:subscribe(topicModeSub, 0, function(client) 
                    print("The subscription is successful: " .. topicModeSub) 
                end)
            end)
        end)
    end)

    client:publish(topicStateStatus, '1', 0, 0, function(client) end)
    client:publish(topicColorStatus, "#caff0a", 0, 0, function(client) end)
    client:publish(topicBrightnessStatus, 100, 0, 0, function(client) end)
    client:publish(topicModeStatus, "static", 0, 0, function(client) end)

    keepalive_tmr:start()

    print("MQTT has been successfully connected")
end)













