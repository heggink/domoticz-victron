return {
	active = true,
	on = {
		devices = { 'testknop' },
		timer = { 'every hour'  }, -- every hour
	},
	logging = { level = domoticz.LOG_DEBUG, marker = 'BATTKWH', },
	data = { 
		bsl = { initial = 30 },		-- save the previous SOC so we can calculate the delta without having to calculate the last soc from history
		lp = { initial = 0 }, 	-- we need the energy price from last our as we get called top of the hour
	},
	execute = function(dz, item)
		
		local batt_soc_last = dz.data.bsl
		local last_price = dz.data.lp
		local batt_soc_now = dz.devices('Battery SOC').percentage
		local batt_kwh_value = dz.variables('batt_kwh').value
		local batt_kwh = dz.variables('batt_kwh')
		local delta = batt_soc_now - batt_soc_last
		local price = dz.devices('Daily Electricity Price').counter
		dz.log("batt_soc_last: "..batt_soc_last)
		dz.log("batt_soc_now: "..batt_soc_now)
		dz.log("delta: "..delta)
		dz.log("last price: "..last_price)
		dz.log("price: "..price)
		dz.log("batt_kwh: "..batt_kwh_value)
		if delta > 2 then -- at least 2% increase to assume this is a charge
			if last_price ~= 0 then -- 0 means we are starting fron scratch so no last enery price
				new_batt_kwh = (batt_kwh_value * batt_soc_last + last_price * delta) / batt_soc_now
				new_batt_kwh = math.floor(new_batt_kwh*10000)/10000
				dz.log("new_batt_kwh: "..new_batt_kwh)
				batt_kwh.set(new_batt_kwh)
			end
		end
		dz.data.bsl = batt_soc_now
		dz.data.lp = price
	end
}

