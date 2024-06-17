--
-- script that controls the battery based on
--   SOC changes (adjust if need be)
--   ESS mode(Bulk, Absorption and float)
--   Battery Mode changes (Charge, Discharge, Idle)
--
return {
	active = true,
	logging = { level = domoticz.LOG_NORMAL, marker = "BATTCONTROL" },
	on = {
		devices = { 'ESS Setpoint' , 'BattTest', 'Battery SOC', 'ESS Charge State', 'Battery Mode', 'Battery State' },
	},
	execute = function(dz, dev)

                local batt_sp = dz.devices('ESS Setpoint')
                local batt_sp_value = batt_sp.setPoint
                local batt_mode = dz.devices('Battery Mode')
                local batt_state = dz.devices('Battery State')
                local idle_rate = dz.variables('batt_idle_rate').value
                local charge_rate = dz.variables('batt_charge_rate').value
                local discharge_rate = dz.variables('batt_discharge_rate').value

		local cr = dz.variables('batt_charge_rate').value
		local dr = dz.variables('batt_discharge_rate').value
		local ir = dz.variables('batt_idle_rate')
		local batt_min_soc = dz.variables('batt_min_soc').value
		local soc_target = dz.variables('today_soc_target').value
		local charge_kwh = dz.variables('today_charge_kwh').value
		local discharge_kwh = dz.variables('today_discharge_kwh').value
		local batt_kwh = dz.variables('batt_kwh').value
		local batt_soc = dz.devices('Battery SOC').percentage
		local new_batt_kwh = 0
		--if dev.isDevice then
			--print("called by "..dev.name)
		--end

		if dev.name == 'Battery SOC' then
			-- manage situations on SOC change:
			--   1) below 10% up the net power to ensure it stays at 10% (Inverter should handle but still)
			--   2) when charging and reaching soc target, stop
			--   3) when going below batt_min_soc stop discharging
			if (dev.percentage <= batt_min_soc and batt_state.state == 'Discharging') then
				-- reserve batt_min_soc% of the charge for home use (states Idle, Balance but ensure charging happens under batt_min_soc% as well)
				batt_sp.cancelQueuedCommands()
				batt_sp.updateSetPoint(idle_rate)
				batt_state.switchSelector('Idle')
				--batt_state.switchSelector('Off').afterMin(10)
				--batt_state.switchOff().afterMin(10)
			elseif (batt_mode.state == 'Charge' and dev.percentage > soc_target) then -- stop charging if we reached the target
				print('Battery at SOC target, stopping charge')
				batt_state.switchSelector('Idle')
			end
		elseif dev.name == 'ESS Charge State' and dev.text == 'Float' and batt_state.state == 'Charging' then 
			-- Batt finished absorpsion and has entered float state so charge is done
			print("We entered float so let's switch to idle state")
			batt_sp.updateSetPoint(ir.value)
			--batt_state.switchSelector('Off')
			--batt_state.switchOff()
		elseif dev.name == 'Battery Mode' then
			-- action Battery State changes: Charge, Discharge and Idle. 
			-- Balance has a separate script (BattBalance) and Manual needs nothing
			if (dev.state == 'Charge') then 
				-- Mode Charge switched on
				batt_sp.cancelQueuedCommands()
				if (batt_soc < soc_target) then
					-- start the charging because the batt_soc is lower than the soc_target
					print('Charge setting ESS Setpoint to: '..cr)
					batt_sp.updateSetPoint(cr)
					new_batt_kwh = ((batt_soc/100) * batt_kwh) + ((soc_target - batt_soc) / 100) * charge_kwh
					print('Recalculated batt_kwh to: '..new_batt_kwh)
					dz.variables('batt_kwh').set(tonumber(string.format("%.4f", new_batt_kwh)))
				else -- the batt_soc is already above the soc_target so nothing to do
					print('Charge command ignored. Battery threshold already reached')
					batt_mode.switchSelector('Idle')
				end
			elseif (dev.state == 'Discharge') then 
				-- Mode Discharge switched on
				batt_sp.cancelQueuedCommands()
				if (batt_soc > batt_min_soc) then
					print('Discharge setting ESS Setpoint to: '..ir.value)
					batt_sp.updateSetPoint(drs)
					batt_sp.updateSetPoint(dr).afterMin(5)
				else
					print('SOC already at minimum threshold so ignore Discharge command')
					batt_mode.switchSelector('Idle')
				end
			elseif (dev.state == 'Idle') then 
				-- Mode Idle
				print('(Dis)charge OFF setting ESS Setpoint to '..ir.value)
				batt_sp.cancelQueuedCommands()
				batt_sp.updateSetPoint(ir.value)
			end
		end
	end
}
