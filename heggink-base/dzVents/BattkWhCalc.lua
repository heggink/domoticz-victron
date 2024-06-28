return {
	active = true,
	on = {
		devices = { 'testknop' },
		timer = { 'every hour'  }, -- every hour
	},
	logging = { level = domoticz.LOG_DEBUG, marker = 'BATTKWH', },
	data = { bsl = { initial = 30 } },
	execute = function(dz, item)
		
		local batt_soc_last = dz.data.bsl
		local batt_soc_now = dz.devices('Battery SOC').percentage
		local batt_kwh_value = dz.variables('batt_kwh').value
		local batt_kwh = dz.variables('batt_kwh')
		local delta = batt_soc_now - batt_soc_last
		local price = dz.devices('Daily Electricity Price').counter
		dz.log("batt_soc_last: "..batt_soc_last)
		dz.log("batt_soc_now: "..batt_soc_now)
		dz.log("delta: "..delta)
		dz.log("price: "..price)
		dz.log("batt_kwh: "..batt_kwh_value)
		if delta > 2 then -- at least 2% increase to assume this is a charge
			new_batt_kwh = (batt_kwh_value * batt_soc_last + price * delta) / batt_soc_now
			dz.log("new_batt_kwh: "..new_batt_kwh)
			dz.data.bsl = batt_soc_now
			batt_kwh.set(new_batt_kwh)
		end
	end
}

