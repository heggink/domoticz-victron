--
-- adjust the ESS setpoint for Charge/Discharge modes, if the grid power is too high/low
-- recalculate every minute to achieve max grid usage
-- assumes a 3 phase setup to prevent single phase overload
--
return {
	active = false,
	logging = { level = domoticz.LOG_NORMAL, marker = "POWCONTROL" },
	on = {
		timer = { 'every minute' },
		devices = { 'Battery State', 'Battery SOC' },
	},
	data = {
	    adjusted = { initial = 0 }
	},

	execute = function(dz, dev)

		local u1 = dz.devices('Usage L1').actualWatt
		local u2 = dz.devices('Usage L2').actualWatt
		local u3 = dz.devices('Usage L3').actualWatt
		local d1 = dz.devices('Delivery L1').actualWatt
		local d2 = dz.devices('Delivery L2').actualWatt
		local d3 = dz.devices('Delivery L3').actualWatt
		local cr = dz.variables('batt_charge_rate').value
		local dr = dz.variables('batt_discharge_rate').value

		local ess_sp = dz.devices('ESS Setpoint')
		local state = dz.devices('Battery State').state

		if (dev.isDevice) then
			if (dev.name == 'Battery State' and (dev.state == 'Charging' or dev.state == 'Discharging')) then
				-- we just started a (dis)charge cycle so reset the adjusted flag
				dz.data.adjusted = 0
				print('Power control: set adjusted to 0 as per Batt Mode')
			else -- SOC
				if (dev.name == 'Battery SOC' and dev.percentage > 97.4 and state == 'Charging' and dz.data.adjusted ~= 0) then
					-- we are at the end of a charge cycle so power will be managed externally. Let's not interfere
					dz.data.adjusted = 0
					print('Power control: set adjusted to 0 as we reached 90% SOC')
				end
			end
		elseif (state == 'Charging') then
			if (u1 > 5500 or u2 > 5500 or u3 > 5500) then 
				-- charging but power too high, let's reduce our setpoint
				dz.data.adjusted = 1
				hp=math.max(u1,u2,u3)
				pow_diff=hp-5500
				print('Reducing charge power to not overload the grid: '..u1..' , '..u2..' , '..u3..' so '..pow_diff*3)
				sp = ess_sp.setPoint - pow_diff*3
				--sp = ess_sp.setPoint - 1000
				if (sp < 0) then
					-- dz.data.adjusted = 0
					sp = 300
				end
				ess_sp.updateSetPoint(sp)
			else -- check if we can increase power
				if (u1 < 4900 and u2 < 4900 and u3 < 4900 and dz.data.adjusted == 1 and ess_sp.setPoint < cr) then
					hp=math.max(u1,u2,u3)
					pow_diff=5200-hp
					sp = math.min(ess_sp.setPoint + pow_diff*3,cr)
					print('Increase adjusted charge power to maximise the grid: '..u1..' , '..u2..' , '..u3..' to '..sp)
					ess_sp.updateSetPoint(sp)
				else
					print('Grid load within acceptable parameters '..u1..' , '..u2..' , '..u3)
				end
			end
		elseif (state == 'Discharging') then
			if (d1 > 5500 or d2 > 5500 or d3 > 5500) then 
				-- discharging but power too high, let's reduce our setpoint
				dz.data.adjusted = 1
				hp=math.max(d1,d2,d3)
				pow_diff=hp-5500
				print('Reducing discharge power to not overload the grid: '..d1..' , '..d2..' , '..d3..' so '..pow_diff*3)
				sp = ess_sp.setPoint + pow_diff*3
				if (sp > 0) then
					dz.data.adjusted = 0
					sp = 60
				end
				ess_sp.updateSetPoint(sp)
			else -- check if we can increase return power
				if (d1 < 4900 and d2 < 4900 and d3 < 4900 and dz.data.adjusted == 1 and ess_sp.setPoint > dr) then
					hp=math.max(d1,d2,d3)
					pow_diff=5200-hp
					sp = math.max(ess_sp.setPoint - pow_diff*3,dr)
					print('Adjust discharge power to maximise the grid: '..d1..' , '..d2..' , '..d3..' to '..sp)
					-- sp = ess_sp.setPoint - 500
					ess_sp.updateSetPoint(sp)
				else
					print('Grid discharge within acceptable parameters '..d1..' , '..d2..' , '..d3)
				end
			end
		end
	end
}
