
--
-- set the remote ESS mode according to the ESS Contrl Mode device
--
return {
	active = false,
	on = {
		devices = { 'Battery SOC' }
	},
	execute = function(domoticz, dev)

		print('Batt SOC: '..dev.percentage)
	end
}
