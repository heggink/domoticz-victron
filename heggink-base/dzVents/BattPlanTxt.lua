return {
	active = true,
	logging = {
	    --level = domoticz.LOG_INFO,
	    marker = "batt_plan_test"
    },
	on = {
		devices = {
            'BattTest'
        },
        variables = {
            'new_scheme_today',
            'new_scheme_tomorrow'
        },
		--timer = { 'at 00:02', 'at 01:02', 'at 14:02', 'at 15:02' } 
	},
	execute = function(dz, item)
        local today = dz.utils.fromJSON(dz.variables('new_scheme_today').value)
        local tomorrow = dz.utils.fromJSON(dz.variables('new_scheme_tomorrow').value)

        local d_today = os.date('%Y-%m-%d')
        local d_tomorrow = os.date('%Y-%m-%d', os.time()+24*60*60)

        local today_str = ""
        local tomorrow_str = ""
        local Time = require('Time')
        local now = Time() -- current time
        --local cutover = tostring(now.hour) .. ":" .. tostring(now.minutes)
        local cutover = now.hour .. ":" .. now.minutes

        -- Local Functions go here =============
        local function makePlan(data, dStr)
            local day_str = ""
            local last_state = ""
            local v = {}
            hrs = { "00", "01", "02", "03", "04", "05", "06", "07", "08", "09", 
                    "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", 
                    "20", "21", "22", "23",
            }
            mins = {"00", "15", "30", "45"}
            --print("I have " .. #hrs ..".. hours and "..#mins.." minutes")
            for i = 1,#hrs,1
            do
                --print("hour is "..i)
                for y = 1,#mins,1
                do
                    --print(hrs[i]..":"..mins[y])
                    index = hrs[i]..":"..mins[y]
                    v = data[index]
    
                    --print("check index "..index.. " for value "..v.hour_type)
                    if (v.hour_type ~= last_state) then
                        if (last_state ~= "") then
                            -- Finish current line
                            day_str = day_str .. string.format(" -> %s (%.2f%%)", index, v.battery_capacity_percentage) .. "\n"
                        end
                        if (v.hour_type ~= "idle") then
                            day_str = day_str .. dStr .. string.format(": %s %s", index, v.hour_type)
                            last_state = v.hour_type
                        else
                            last_state = "";
                        end
                    end
                end
            end
            if (day_str == "") then
                if (dStr == "TD") then
                    day_str = '<font color="purple">Today no charge day...</font>'
                else
                    day_str = '<font color="purple">Tomorrow no charge day...</font>'
                end
            end
            return day_str
        end

        -- Main code goes here ================
        --print("BPT get started")
        if (today["status"] == true) then
            --print("BPT today status good")
            if (d_today == today["datum"]) then
                --print("making today string")
                today_str = makePlan(today, "TD")
            else
                today_str = string.format('<font color="red">Today has wrong data !?</font>, %s, %s', d_today, today["datum"])
                --today_str = '<font color="red">Today has wrong data !?</font>' .. d_today .. ', ' .. today["datum"]
            end
        else
            today_str = '<font color="red">No Today data !?</font>'
        end

        if (tomorrow["status"] == true) then
            --print("BPT tomorrow status good")
            if (d_tomorrow == tomorrow["datum"]) then
                tomorrow_str = makePlan(tomorrow, "TM")
            else
                tomorrow_str = '<font color="red">Tomorrow has wrong data !?</font>'
            end
        else
            -- Only alert when time is later than 3 PM (15:00)
            local hour = tonumber(os.date("%H"))
            if hour >= 15 then
                tomorrow_str = '<font color="red">No Tomorrow data !?</font>'
            end
        end

        local final_str = today_str;
        if (tomorrow_str ~= "") then
            if (final_str ~= "") then
                final_str = final_str .. "\n"
            end
            final_str = final_str .. tomorrow_str
        end
        dz.devices('Battery Plan').updateText(final_str)
	end
}
