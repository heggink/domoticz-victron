--
-- script that controls the battery minimum SOC
--
return {
	active = false, -- moved to node-red
	logging = { level = domoticz.LOG_NORMAL, marker = "BattMinSOC" },
	on = {
		devices = { 'Battery SOC' },
	},
	execute = function(dz, dev)

		local ir = dz.variables('batt_idle_rate')
		local bat_sp = dz.devices('ESS Setpoint')
		local tbm = dz.devices('Battery Mode')
		local batt_soc_floor = dz.variables('batt_soc_floor').value
		local batt_soc = dz.devices('Battery SOC').percentage

		if dev.name == 'Battery SOC' then
			-- manage situations on SOC change:
			--   1) below 10% up the net power to ensure it stays at 10% (Inverter should handle but still)
			--   2) when charging and reaching soc target, stop
			--   3) when going below batt_min_soc stop discharging
			if (dev.percentage <= batt_soc_floor and tbm.state ~= 'Idle') then
				-- reserve batt_min_soc% of the charge for home use (states Idle, Balance but ensure charging happens under batt_min_soc% as well)
				dz.log('Battery at minimum level, stopping further discharge by forcing idle @ 750W', dz.LOG_NORMAL)
				ir.set(750)
				tbm.switchSelector('Idle')
			end
		end
	end
}
