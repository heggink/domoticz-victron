--
-- this script switches the Batterty State device based on ESS Setpoint
--

return {
        logging = { level = domoticz.LOG_DEBUG, marker = "batt_state" },
        on = { devices = {'ESS Setpoint'}, },
        execute = function(dz, dev)

		local min_soc_level = dz.variables('batt_min_soc_level').value
		local max_soc_level = dz.variables('batt_max_soc_level').value

		local batt_sp = dz.devices('ESS Setpoint')
		local batt_sp_value = batt_sp.setPoint
		local batt_mode = dz.devices('Battery Mode')
		local batt_state = dz.devices('Battery State')

		local idle_rate = dz.variables('batt_idle_rate').value

		if (batt_sp_value == 0) and (batt_state.state ~= 'Off') then
			--batt_state.switchSelector('Off')
		elseif (batt_sp_value == idle_rate) and (batt_state.state ~= 'Idle') then
			batt_state.switchSelector('Idle')
		elseif (batt_sp_value > idle_rate) and (batt_state.state ~= 'Charging') then
			batt_state.switchSelector('Charging')
		elseif (batt_sp_value < 0) and (batt_state.state ~= 'Discharging') then
			batt_state.switchSelector('Discharging')
		end
	end
}

