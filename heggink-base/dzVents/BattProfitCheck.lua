--
-- script that controls the battery discharge based on
--   whether at th emoment of discharge, the current rate is still profitable
--
return {
	active = true,
	logging = { level = domoticz.LOG_NORMAL, marker = "BATTPROFITCHECK" },
	on = { 
		timer = { 'at *:01', }, 
	},
	execute = function(dz, dev)

		local tbm = dz.devices('Battery Mode')

		if tbm.state == 'Discharge' then 
			local bat_sp = dz.devices('ESS Setpoint')
			local price = dz.devices('Daily Electricity Price').counter
			local ir = dz.variables('batt_idle_rate').value
			local eff = dz.variables('batt_efficiency').value
			local dc_hr = dz.variables('DischargeToday')
			local batt_kwh = dz.variables('batt_kwh').value
			local hr = dz.time.hour

			if (price * eff) <= batt_kwh then
				if tonumber(string.sub(dc_hr.value,1,2)) == hr then 
					-- we start with a non profitable discharge so ensure that delay 1 hr
					if hr < 9 then
						hrstr = "0"..(hr+1)..":00"
						dc_hr.set(hrstr)
						print("Bat discharge starts unprofitable so delay "..(price * eff).." <= "..batt_kwh )
					else
						if hr == 23 then
							-- we are at midnight so option to move forward
							print("Bat discharge unprofitable at midnight "..(price * eff).." <= "..batt_kwh )
						else
							hrstr = (hr+1)..":00"
							dc_hr.set(hrstr)
							print("Bat discharge starts unprofitable so delay "..(price * eff).." <= "..batt_kwh )
						end
					end
				else
					dz.devices('ESS Setpoint').updateSetPoint(ir)
					tbm.switchSelector('Idle')
					tbm.switchSelector('Off').afterMin(10)
					tbm.switchOff().afterMin(10)
					print("Bat discharge no longer profitable so stop "..(price * eff).." <= "..batt_kwh )
				end
			end
		end
	end
}
