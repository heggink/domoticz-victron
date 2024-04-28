--
-- set the ESS setpoint so total enery consumption is close to 0
--   if negative then try to charge the battery
--   if positive then compensate for usage with batt
-- when battery is in Balance mode
-- and more than 250W difference
--
return {
	active = true,
	logging = { level = domoticz.LOG_NORMAL, marker = "BATTBALANCE" },
	on = {
		devices = { 'Battery Mode', 'Power' },
		--timer = { 'Every minute' } 
	},
	execute = function(dz, dev)

		local bms = dz.devices('Battery Mode').state

		if (bms == 'Balance') then
			power=dz.devices('Power').usage - dz.devices('Power').usageDelivered
			if (math.abs(power) > 250) then 
				-- check if we need to adjust power
				--print('Power is '..power)
				local bm = dz.devices('Battery Mode')
				local ess_sp = dz.devices('ESS Setpoint')
				local sp = dz.devices('ESS Setpoint').setPoint
				local bat_sp = dz.devices('ESS Setpoint')
				local batt_soc = dz.devices('Battery SOC').percentage
				local idle_rate = dz.variables('batt_idle_rate').value

				if power > 0 then
					new_sp = sp - power/3
					--print('ESS Setpoint needs adjusting, power: '..power..' from: '..sp..' to '..new_sp)
					ess_sp.updateSetPoint(new_sp)
					if (batt_soc <= 10) then -- stop compensating if we are approaching the last 10% SOC
						bm.switchSelector('Idle')
					end
				else
					if sp < 0 then -- batt is returning power but we are also returning to the net so reduce batt return
						new_sp = sp - power/3
						--print('ESS Setpoint needs adjusting, power: '..power..' from: '..sp..' to '..new_sp)
						ess_sp.updateSetPoint(new_sp)
					else
						-- this is where we keep the net close to 0 to redirect solar energy into the batt if there is capacity left
						if batt_soc < 100 then
							new_sp = sp + math.abs(power)/3
							--print('ESS Setpoint needs adjusting, power: '..power..' from: '..sp..' to '..new_sp)
							ess_sp.updateSetPoint(new_sp)
						else
							-- battery is full then switch to idle_rate
							ess_sp.updateSetPoint(idle_rate)
						end
					end
				end
			end
		end
	end
}
