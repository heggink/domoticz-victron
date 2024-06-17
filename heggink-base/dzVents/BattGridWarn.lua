--
-- alert if the wattage is too high/low
-- as victron now manages it
--
return {
	active = true,
	logging = { level = domoticz.LOG_NORMAL, marker = "POWWARN" },
	on = {
		-- timer = { 'every minute' },
		devices = { 'Usage L*', 'Delivery L*' },
	},
	data = {
	    strike = { initial = 0 }
	},

	execute = function(dz, dev)

		local u1 = dz.devices('Usage L1').actualWatt
		local u2 = dz.devices('Usage L2').actualWatt
		local u3 = dz.devices('Usage L3').actualWatt
		local d1 = dz.devices('Delivery L1').actualWatt
		local d2 = dz.devices('Delivery L2').actualWatt
		local d3 = dz.devices('Delivery L3').actualWatt

		if (dev.actualWatt > 5750) then
			dz.data.strike = dz.data.strike + 1
			dz.log('Grid overload warning for phase '..dev.name, dz.LOG_NORMAL)
			if dz.data.strike > 2 then
				dz.notify('Warning', 'Grid overload warning for phase '..dev.name)
			end
		else
			dz.data.strike = 0
		end
	end
}
