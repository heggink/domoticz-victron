--
-- put the charge and discharge times in a text variable
--
return {
	active = true,
	on = { variables = { 'ChargeToday', 'DischargeToday', 'ChargeTomorrow', 'DischargeTomorrow' } },

	execute = function(dz, dev)

		local tdsoc = dz.variables('today_soc_target').value
		local tmsoc = dz.variables('tomorrow_soc_target').value
		local cn = dz.variables('ChargeToday').value
		local dn = dz.variables('DischargeToday').value
		local ct = dz.variables('ChargeTomorrow').value
		local dt = dz.variables('DischargeTomorrow').value
		local td_pre=''
		local td_post=''
		local tm_pre=''
		local tm_post=''
		if tdsoc == 100 then
			td='<FONT COLOR="RED">Chrg TD: '..cn..'</FONT>'..'\nDisch TD: '..dn
		else
			td='Chrg TD: '..cn..'\nDisch TD: '..dn..''
		end
		if tmsoc == 100 then
			tm='<FONT COLOR="RED">Chrg TM: '..ct..'</FONT>'..'\nDisch TM: '..dt
		else
			tm='Chrg TM: '..ct..'\nDisch TM: '..dt
		end
		dz.devices('Battery Plan').updateText(td..'\n'..tm)
	end
}

