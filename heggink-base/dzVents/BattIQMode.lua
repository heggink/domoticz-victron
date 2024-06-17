return {
	logging = { level = domoticz.LOG_NORMAL, marker = "batt_iq_mode" },
	on = {
		devices = {
			'BattTest', 'Battery Mode' },
		timer = { 'every hour' } 
	},
	execute = function(dz, dev)
		local batt_mode = dz.devices('Battery Mode')

		if (batt_mode.state ~= 'IQ Smart Mode') then
			do return end
		end

		local min_soc_level = dz.variables('batt_min_soc_level').value
		local max_soc_level = dz.variables('batt_max_soc_level').value
		
		local idle_rate = dz.variables('batt_idle_rate').value
		local charge_rate = dz.variables('batt_charge_rate').value
		local discharge_rate = dz.variables('batt_discharge_rate').value
		
		local batt_soc = dz.devices('Battery SOC').percentage
		local batt_sp = dz.devices('ESS Setpoint')
		local batt_sp_value = batt_sp.setPoint

		local charge_scheme = dz.variables('charge_scheme_today').value
		
		local today = os.date('%Y-%m-%d')
		local act_hour = tonumber(os.date('%H'))

		local jtable = dz.utils.fromJSON(charge_scheme)

		if (jtable["status"] ~= true) then
			dz.log('Invalid Scheme! (status)')
			do return end
		end
		if (today ~= jtable["datum"]) then
			 dz.log('Invalid Scheme! (datum)')
			 do return end
		end

		local tHour = nil
		local hour_type = "idle"

		local size = 0
		for th, v in pairs(jtable["data"]) do
			if (v.iHour == act_hour) then
			  tHour = v
			end
			size = size + 1
		end
		
		if (size ~= 24) then
			 dz.log('Invalid Scheme! (number of items)')
			 do return end
		end

		if (tHour == nil) then
			 dz.log('Invalid Scheme! (act hour not found!?)')
			 do return end
		end

		hour_type = tHour.hour_type
		--dz.log(tHour.hour_price)
		local new_setpoint = idle_rate
		if (hour_type == "charge") then
			new_setpoint = charge_rate
		elseif (hour_type == "discharge") then
			new_setpoint = discharge_rate
		end
		
		--dz.log("action: " .. hour_type .. ", SP=" .. new_setpoint)

		if ((new_setpoint < 0) and (batt_soc <=min_soc_level)) or ((new_setpoint > 0) and (batt_soc >= max_soc_level)) then
			--nothing to do, soc min/max reached
			do return end
		end

		if (new_setpoint ~= batt_sp_value) then
			dz.log("IQ Mode: Setting setpoint to " .. new_setpoint .. "(" .. hour_type .. ")")
			batt_sp.cancelQueuedCommands()
			batt_sp.updateSetPoint(new_setpoint)
		end
	end
}
