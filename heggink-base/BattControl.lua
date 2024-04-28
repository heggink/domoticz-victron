--
-- script that controls the battery based on
--   set timers in ChargeToday and DischargeToday
--   SOC changes (adjust if need be)
--   ESS mode(Bulk, Absorption and float)
--   Battery Mode changes (Charge, Discharge, Idle)
--
return {
	active = true,
	logging = { level = domoticz.LOG_NORMAL, marker = "BATTCONTROL" },
	on = {
		devices = { 'ESS Setpoint' , 'BattTest', 'Battery SOC', 'ESS Charge State', 'Battery Mode' },
		-- timer = { 'at 00:00', 'at 01:00', 'at 02:00', 'at 03:00', 'at 04:00', 'at 05:00', 'at 06:00', 
		--	  'at 07:00', 'at 08:00', 'at 09:00', 'at 10:00', 'at 11:00', 'at 12:00', 'at 13:00', 
		--	  'at 14:00', 'at 15:00', 'at 16:00', 'at 17:00', 'at 18:00', 'at 19:00', 'at 20:00', 
		--	  'at 21:00', 'at 22:00', 'at 23:00' } 
	},
	execute = function(dz, dev)

		local bat_sp = dz.devices('ESS Setpoint')
		local tbm = dz.devices('Battery Mode')
		local cr = dz.variables('batt_charge_rate').value
		local dr = dz.variables('batt_discharge_rate').value
		local ir = dz.variables('batt_idle_rate')
		local batt_min_soc = dz.variables('batt_min_soc').value
		local DischargeToday = dz.variables('DischargeToday').value
		local ChargeToday = dz.variables('ChargeToday').value
		local soc_target = dz.variables('today_soc_target').value
		local charge_kwh = dz.variables('today_charge_kwh').value
		local discharge_kwh = dz.variables('today_discharge_kwh').value
		local batt_kwh = dz.variables('batt_kwh').value
		local batt_soc = dz.devices('Battery SOC').percentage
		local new_batt_kwh = 0
		--if dev.isDevice then
			--print("called by "..dev.name)
		--end

		if (dev.isTimer or dev.name == 'BattTest') then 
			-- check every hour if we need to charge/discharge the batt according to the schedule in the variables
			if (tbm.state ~= 'Manual') then
				hr = os.date('%H')
				timestr = hr..':00'

				--print('Comparing ' ..timestr.. ' with CT '..ChargeToday.. ' and DT '..DischargeToday)
				if ChargeToday == timestr then
					if soc_target == 30 and batt_soc > 25 then
						print('No need to charge as target is 30% and we are already above 25%')
						tbm.switchOff()
					else
						tbm.switchSelector('Charge')
					end
				elseif DischargeToday == timestr then
					if batt_soc <= 30 then
						print('No need to discharge as we are already at 30%')
						tbm.switchOff()
					else
						tbm.switchSelector('Discharge')
					end
				end
			end
		elseif dev.name == 'Battery SOC' then
			-- manage situations on SOC change:
			--   1) below 10% up the net power to ensure it stays at 10% (Inverter should handle but still)
			--   2) when charging and reaching soc target, stop
			--   3) when going below batt_min_soc stop discharging
			if (dev.percentage <= batt_min_soc and tbm.state == 'Discharge') then
				-- reserve batt_min_soc% of the charge for home use (states Idle, Balance but ensure charging happens under batt_min_soc% as well)
				tbm.switchSelector('Idle')
				tbm.switchSelector('Off').afterMin(10)
				tbm.switchOff().aftermin(10)
			elseif (dev.percentage <= 10 and tbm.state ~= 'Idle') then
				print('Battery at minimum level, stopping further discharge by forcing idle @ 750W')
				ir.set(750)
				tbm.switchSelector('Idle')
			elseif (tbm.state == 'Charge' and dev.percentage > soc_target) then -- stop charging if we reached the target
				print('Battery at SOC target, stopping charge')
				tbm.switchSelector('Idle')
			end
		elseif dev.name == 'ESS Charge State' and dev.text == 'Float' and tbm.state == 'Charge' then 
			-- Batt finished absorpsion and has entered float state so charge is done
			print("We entered float so let's switch to idle state")
			ir.set(60)
			tbm.switchSelector('Off')
			tbm.switchOff()
		else
			-- action Battery Mode changes: Charge, Discharge and Idle. 
			-- Balance has a separate script (BattBalance) and Manual needs nothing
			if (dev.state == 'Charge') then 
				-- Mode Charge switched on
				bat_sp.cancelQueuedCommands()
				if (batt_soc < soc_target) then
					-- start the charging because the batt_soc is lower than the soc_target
					print('Charge setting ESS Setpoint to: '..cr)
					bat_sp.updateSetPoint(cr)
					new_batt_kwh = ((batt_soc/100) * batt_kwh) + ((soc_target - batt_soc) / 100) * charge_kwh
					print('Recalculated batt_kwh to: '..new_batt_kwh)
					dz.variables('batt_kwh').set(tonumber(string.format("%.4f", new_batt_kwh)))
				else -- the batt_soc is already above the soc_target so nothing to do
					print('Charge command ignored. Battery threshold already reached')
					tbm.switchSelector('Idle')
				end
			elseif (dev.state == 'Discharge') then 
				-- Mode Discharge switched on
				bat_sp.cancelQueuedCommands()
				if (batt_soc > batt_min_soc) then
					print('Discharge setting ESS Setpoint to: '..ir.value)
					bat_sp.updateSetPoint(drs)
					bat_sp.updateSetPoint(dr).afterMin(5)
				else
					print('SOC already at minimum threshold so ignore Discharge command')
					tbm.switchSelector('Idle')
				end
			elseif (dev.state == 'Idle') then 
				-- Mode Idle
				print('(Dis)charge OFF setting ESS Setpoint to '..ir.value)
				bat_sp.cancelQueuedCommands()
				bat_sp.updateSetPoint(ir.value)
			end
		end
	end
}
