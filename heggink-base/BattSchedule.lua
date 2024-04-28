--
-- check dayrates to find the best slots for charging and discharging
-- assumes a 3hr slot for charge/discharge
-- saves in ChargeToday/ChargeTomorrow and DischargeToday/DischargeTomorrow 
-- saves (dis)charge_kwh in a user variable
-- determines SOC target: if difference in price after losses (20%) is < 0 then 30% (internal house usage) else 100% (buy and sell)
-- 
-- strategy is as follows:
-- 	assume the scrip has run before (initialise variables otherwise)
-- 	test  the remainder of today and tomorrow for best sets of charge/discharge
-- 	for today, this may be the second cycle but, if not optimal, it will get resolved during optimisation
-- 
return {
	active=true,
	on = {
		devices = {'BattScheduleRefresh'},
		--timer = { 'at 15:05', 'at 00:05' }, -- Timer to set charge and discharge schedule for the battery
		timer = { 'at 15:05' }, -- Timer to set charge and discharge schedule for the battery
		httpResponses = { 'domo_sched', },
		customEvents = { 'TibberRatesUpdated' },
		--customEvents = { 'TibberRatesUpdated', 'EnergyRatesUpdated' },
	},
	data = { hasrun = { initial = false } },
	logging = { level = domoticz.LOG_DEBUG, marker = 'BATTSCHEDULE', },
	execute = function(dz, item)
		
		local charge_today = "00:30"
		local discharge_today = "00:30"
		local charge_tomorrow = "00:30"
		local discharge_tomorrow = "00:30"
		local discharge = true
		local today = os.date('%Y-%m-%d')
		local LowRateThreshold = dz.variables('LowRateThreshold').value
		local batt_efficiency = dz.variables('batt_efficiency').value
		local DischargeToday = dz.variables('DischargeToday')
		local batt_min_soc = dz.variables('batt_min_soc').value
		local DischargeTomorrow = dz.variables('DischargeTomorrow')
		local ChargeToday = dz.variables('ChargeToday')
		local ChargeTomorrow = dz.variables('ChargeTomorrow')
		local batt_kwh = dz.variables('batt_kwh').value
		local today_soc_target = dz.variables('today_soc_target')
		local tomorrow_soc_target = dz.variables('tomorrow_soc_target')
		local today_charge_kwh = dz.variables('today_charge_kwh')
		local tomorrow_charge_kwh = dz.variables('tomorrow_charge_kwh')
		local today_discharge_kwh = dz.variables('today_discharge_kwh')
		local tomorrow_discharge_kwh = dz.variables('tomorrow_discharge_kwh')
		local rates2_idx = 9367 -- Evener electricity rates device
		local rates_idx = 4307 -- Evener electricity rates device
		local time_range=31 -- number of hours to take into account. This is as of 2pm so run the scipt before
		local ridx=0

                if (not item.isHTTPResponse) then
                        if item.isCustomEvent then
				dz.data.hasrun = false -- always run when rates are updated
                                if item.trigger == 'TibberRatesUpdated' then
                                        ridx=rates_idx
                                else
                                        ridx=rates2_idx
                                end
			elseif item.isTimer then -- timer trigger
				if dz.time.hour == 0 then -- reset the hasrun parameter at midnight so we will run again today
					dz.hasrun = false
					do return end
				else
					ridx=rates2_idx -- default to Enever on button or timer
				end
			elseif item.isDevice then -- button
				dz.data.hasrun = false -- always run when rates are updated
                                ridx=rates_idx -- default to Enever on button or timer
                        end
			if dz.data.hasrun == false then
				dz.openURL({
					url = 'http://127.0.0.1:8080/json.htm?type=command&param=graph&sensor=counter&idx='..ridx..'&range=day',
					method = 'GET',
					headers = { ['Content-Type'] = "application/json" },
					callback = 'domo_sched'
				})
			end
		else 
			--print("Received URL")
			if (item.ok) then
				dz.data.hasrun = true -- ensure we don't rerun today
				ChargeTomorrow.set('00.30')
				DischargeTomorrow.set('00.30')
				local rates = item.json.result
				local high_rate = 0
				local high_hr = 0
				local low_rate = 100
				local low_hr = 0
				local size = 0
				local y_n=os.date("%Y")
				local m_n=os.date("%m")
				local d_n=os.date("%d")
				local y_t=os.date("%Y",os.time()+24*60*60)
				local m_t=os.date("%m",os.time()+24*60*60)
				local d_t=os.date("%d",os.time()+24*60*60)

				for _ in pairs(rates) do size = size + 1 end
				print("Table has "..size.." entries, starting at "..rates[size-time_range-2].d)
				start_h = tonumber(string.sub(rates[size-time_range-2].d,12,13))
				start_d = tonumber(string.sub(rates[size-time_range-2].d,9,10))
				if tonumber(start_d) ~= tonumber(d_n) then
					print("That's weird: I have the wrong day. I got: "..start_d.." which should be "..d_n)
					dz.openURL({
						url = 'http://127.0.0.1:8080/json.htm?type=command&param=graph&sensor=counter&idx='..rates2_idx..'&range=day', 
						method = 'GET',
						headers = { ['Content-Type'] = "application/json" },
						callback = 'domo_sched'
					})
					--dz.notify('INFO', 'BattSchedule misses rates data. Exiting', dz.PRIORITY_NORMAL)
					do return end
				end
				-- 
				-- let's see if there are slots TODAY that are incremental to what we saw yesterday
				--
				for i = (size-time_range), size-time_range+10 do
					rate=(rates[i-2].v + rates[i-1].v + rates[i].v)/3
					hr=rates[i-2].d
					if (tonumber(string.sub(hr,9,10)) > start_d) then
						print("I have entered into the next day: "..hr)
						break
					end
					if (rate) > high_rate then
						high_rate = rate
						high_hr = hr
						print("found higher 3hr slot a with rate "..high_rate.." at "..high_hr)
					end
					if (rate) < low_rate then
						low_rate = rate
						low_hr = hr
						print("found lower 3hr slot a with rate "..low_rate.." at "..low_hr)
					end
				end
				--datestr=string.sub(low_hr,1,10)
				low_hr=string.sub(low_hr,12,13)
				high_hr=string.sub(high_hr,12,13)
				print('Found today low of '..low_hr..' and high '..high_hr)
				if (low_rate < (high_rate * batt_efficiency) and (tonumber(low_hr) < tonumber(high_hr))) then 
					-- profitable slot for a Charge - discharge
					charge_today = low_hr..":00"
					discharge_today = high_hr..":00"
					ctdr = low_rate
					dtdr = high_rate
				else
					print('No profitable set of charge/discharge so exclude these')
					ctdr=1000
					dtdr=1
				end

				--
				-- now let's do tomorrow
				--
				local high_rate = 0
				local high_hr = 0
				local low_rate = 100
				local low_hr = 0
				print("Starting tomorrow at "..rates[size-23].d)
				for i = (size-23), size do
					rate=(rates[i-2].v + rates[i-1].v + rates[i].v)/3
					hr=rates[i-2].d
					if (rate) > high_rate then
						high_rate = rate
						high_hr = hr
						--print("found higher 3hr slot a with rate "..high_rate.." at "..high_hr)
					end
					if (rate) < low_rate then
						low_rate = rate
						low_hr = hr
						--print("found lower 3hr slot a with rate "..low_rate.." at "..low_hr)
					end
				end

				low_hr=string.sub(low_hr, 12,13)
				high_hr=string.sub(high_hr, 12,13)
				print('Found tomorrow low of '..low_hr..' and high '..high_hr)
				if (low_rate < (high_rate * batt_efficiency) and (tonumber(low_hr) < tonumber(high_hr))) then 
					-- profitable slot for a Charge - discharge
					charge_tomorrow=low_hr..":00"
					discharge_tomorrow=high_hr..":00"
				else
					print('No profitable set of charge/discharge so exclude these')
				end

				--dz.notify('INFO', 'Opladen thuisbatterij gepland voor '..low_hr, dz.PRIORITY_NORMAL)
				--datestr=string.sub(high_hr, 1,10)

				ctmr = tonumber(string.format("%.4f", low_rate))
				dtmr = tonumber(string.format("%.4f", high_rate))

				h=tonumber(string.sub(charge_today,1,2))
				dt = {year=y_n, month=m_n, day=d_n, hour=h, min=0, sec=0 }
				d1=os.time(dt)

				h=tonumber(string.sub(discharge_today,1,2))
				dt = {year=y_n, month=m_n, day=d_n, hour=h, min=0, sec=0 }
				d2=os.time(dt)

				h=tonumber(string.sub(low_hr,1,2))
				dt = {year=y_t, month=m_t, day=d_t, hour=h, min=0, sec=0 }
				d3=os.time(dt)

				h=tonumber(string.sub(high_hr,1,2))
				dt = {year=y_t, month=m_t, day=d_t, hour=h, min=0, sec=0 }
				d4=os.time(dt)


				t = {
				   { soc = 0, td = "today",    ds = charge_today,        dn = d1, mode = "C", rate = ctdr, use = true },
				   { soc = 0, td = "today",    ds = discharge_today,     dn = d2, mode = "D", rate = dtdr, use = true },
				   { soc = 0, td = "tomorrow", ds = charge_tomorrow,     dn = d3, mode = "C", rate = ctmr, use = true },
				   { soc = 0, td = "tomorrow", ds = discharge_tomorrow,  dn = d4, mode = "D", rate = dtmr, use = true }
				}

				t_size = 4
				print("Pre-sort")
				for i,v in ipairs(t) do
					print("date "..v.ds.." when: "..v.td.." mode "..v.mode.." rate "..tostring(v.rate))
				end

				-- remove unprofitable discharge entries in the current schedule (if any)
				for i,v in ipairs(t) do
					if string.sub(v.ds, 4,5) == "30" then
						-- non-profitable, skipped discharge so remove
						table.remove(t,i)
						t_size = t_size - 1
					end
				end

				table.sort(t, function (k1, k2) return k1.dn < k2.dn end )
				print("Post-sort")
				for i,v in ipairs(t) do
					print("date "..v.ds.." when: "..v.td.." mode "..v.mode.." rate "..tostring(v.rate))
				end
				-- now we have a table with sorted charge/discharge times for the next 34 hours, Let's make sense of it
				-- we can support 2 charge/discharge cycles if need be
				-- let's check if we have consecutive charges/discharges and eliminate those if need be (find the optimal one)
				-- we can ignore the batt start position (charge what is full is no problem, discharge empty, same thing)
				--

				print("optimise table to remove useless doubles")
				if t[1].mode == t[2].mode then
					if t[1].mode == 'C' then -- charge so look for the lowest rate to retain
						if t[1].rate < t[2].rate then
							-- disable t[2] entry
							t[2].use = false
						else
							-- remove t[1] entry
							t[1].use = false
						end
					else -- discharge so look for the highest rate to retain
						if t[1].rate > t[2].rate then
							-- remove t[2] entry
							t[2].use = false
						else
							-- remove t[1] entry
							t[1].use = false
						end
					end
				end
				if t[2].mode == t[3].mode then
					if t[2].mode == 'C' then -- charge so look for the lowest rate to retain
						if t[2].rate < t[3].rate then
							-- disable t[2] entry
							t[3].use = false
						else
							-- remove t[1] entry
							t[2].use = false
						end
					else -- discharge so look for the highest rate to retain
						if t[2].rate > t[3].rate then
							-- remove t[2] entry
							t[3].use = false
						else
							-- remove t[1] entry
							t[2].use = false
						end
					end
				end
				if t_size > 3 then
					if t[3].mode == t[4].mode then
						if t[3].mode == 'C' then -- charge so look for the lowest rate to retain
							if t[3].rate < t[4].rate then
								-- disable t[2] entry
								t[4].use = false
							else
								-- remove t[1] entry
								t[3].use = false
							end
						else -- discharge so look for the highest rate to retain
							if t[3].rate > t[4].rate then
								-- remove t[2] entry
								t[4].use = false
							else
								-- remove t[1] entry
								t[3].use = false
							end
						end
					end
				end

				print("Post-optimise")
				for i,v in ipairs(t) do
					print("date "..v.ds.." when: "..v.td.." mode "..v.mode.." rate "..v.rate.." use: "..tostring(v.use) )
				end

				-- now de/refine the charge strategy
				-- determine the SOC goal for the a charge: Keep at batt_min_soc (unprofitable cycle) or go for 100% because it's profitable
				-- since we removed doubles, we can now only have the following types of cycles:
				-- C-D-C
				-- D-C-D
				-- C-D-C-D
				-- D-C-D-C
				-- so first, remove any row that is a double (can only be one)
				-- then count how many:
				-- 	if 4 rows then 2 cycles so treat each cycle separately
				-- 	if 3 then check from one state to the other
				for i,v in ipairs(t) do
					if v.use == false then
						print("Remove entry "..i.." from the table")
						table.remove(t, i)
						break
					end
				end

				num_states=0
				print("Post-rationalise")
				for i,v in ipairs(t) do
					print("date "..v.ds.." when: "..v.td.." mode "..v.mode.." rate "..tostring(v.rate).." use: "..tostring(v.use) )
					num_states = num_states+1
				end

				print("I have "..num_states.." states so check profitable charges")

				if num_states == 4 then -- check 2 cycles
					if t[1].mode == 'C' then
						if t[1].rate < t[2].rate * batt_efficiency then -- cycle 1
							--print("profitable charge so soc is 100%")
							t[1].soc=100
						else
							--print("unprofitable charge so soc is batt_min_soc")
							t[1].soc=batt_min_soc
						end
						if t[3].rate < t[4].rate * batt_efficiency then -- cycle 2
							--print("profitable charge so soc is 100%")
							t[3].soc=100
						else
							if (t[3].rate < LowRateThreshold) then 
								t[3].soc=100
								discharge = false
							else
								--print("unprofitable charge so soc is batt_min_soc")
								t[3].soc=batt_min_soc
							end
						end
					else -- we start with a discharge so check the next one to be profitable
						if t[2].rate < t[3].rate * batt_efficiency then
							--print("profitable charge so soc is 100%")
							t[2].soc=100
						else
							if (t[2].rate < LowRateThreshold) then 
								t[2].soc=100
								discharge = false
							else
								--print("unprofitable charge so soc is batt_min_soc")
								t[2].soc=batt_min_soc
							end
						end
					end
				else -- 1 full cycle (2 or 3 states) so check the charge bit
					if t[1].mode == 'C' then
						if t[1].rate < t[2].rate * batt_efficiency then
							--print("profitable charge so soc is 100%")
							t[1].soc=100
						else
							if (t[1].rate < LowRateThreshold) then 
								t[1].soc=100
								discharge = false
							else
								--print("unprofitable charge so soc is batt_min_soc")
								t[1].soc=batt_min_soc
							end
						end
						if num_states == 3 then -- CDC
							t[3].soc=100 -- let's set t3 (must be a charge or would have been eliminated) to 100 so we check tomorrow
						end
					else -- we start with a discharge so check the next one to be profitable
						if num_states == 3 then -- DCD
							if t[2].rate < t[3].rate * batt_efficiency then
								--print("profitable charge so soc is 100%")
								t[2].soc=100
							else
								if (t[2].rate < LowRateThreshold) then 
									t[2].soc=100
									discharge = false
								else
									--print("unprofitable charge so soc is batt_min_soc")
									t[2].soc=batt_min_soc
								end
							end
						else -- DC
							t[2].soc=100 -- let's set t2 (must be a charge or would have been eliminated) to 100 so we check tomorrow
						end
					end
				end

				--print("Post-everything: set all variables: hour, soc and kwh price")
				for i,v in ipairs(t) do
					print("date "..v.ds.." when "..v.td.." mode "..v.mode.." rate "..v.rate.." soc target: "..v.soc )
					local hr = string.sub(v.ds,1,2)
					if v.td == 'today' then
						if v.mode == 'C' then
							print("CT, date "..v.ds.." mode "..v.mode.." rate "..v.rate.." soc target: "..v.soc )
							url="127.0.0.1:8080/json.htm?type=command&param=addtimer&idx=9531&active=true&persistent=true&timertype=5&hour="..hr.."&min=0&date="..y_n.."-"..m_n.."-"..d_n.."&randomness=false&command=0&level=20&days=1234567"
							--print("URL is: "..url)
							dz.openURL(url)
							ChargeToday.set(v.ds)
							today_charge_kwh.set(v.rate)
							today_soc_target.set(v.soc)
						else
							print("DT, date "..v.ds.." mode "..v.mode.." rate "..v.rate.." soc target: "..v.soc )
							url="127.0.0.1:8080/json.htm?type=command&param=addtimer&idx=9531&active=true&persistent=true&timertype=5&hour="..hr.."&min=0&date="..y_n.."-"..m_n.."-"..d_n.."&randomness=false&command=0&level=30&days=1234567"
							--print("URL is: "..url)
							dz.openURL(url)
							DischargeToday.set(v.ds)
							today_discharge_kwh.set(v.rate)
						end
					else -- tomorrow
						if v.mode == 'C' then
							print("CM, date "..v.ds.." mode "..v.mode.." rate "..v.rate.." soc target: "..v.soc )
							url="127.0.0.1:8080/json.htm?type=command&param=addtimer&idx=9531&active=true&persistent=true&timertype=5&hour="..hr.."&min=0&date="..y_t.."-"..m_t.."-"..d_t.."&randomness=false&command=0&level=20&days=1234567"
							--print("URL is: "..url)
							dz.openURL(url)
							ChargeTomorrow.set(v.ds)
							tomorrow_charge_kwh.set(v.rate)
							tomorrow_soc_target.set(v.soc)
						else
							--print("DM, date "..v.ds.." mode "..v.mode.." rate "..v.rate.." soc target: "..v.soc )
							if discharge then
								DischargeTomorrow.set(v.ds)
								min_t="00"
							else
								DischargeTomorrow.set(string.sub(v.ds, 1, 3).."30")
								min_t="30"
							end
							url="127.0.0.1:8080/json.htm?type=command&param=addtimer&idx=9531&active=true&persistent=true&timertype=5&hour="..hr.."&min="..min_t.."&date="..y_t.."-"..m_t.."-"..d_t.."&randomness=false&command=0&level=30&days=1234567"
							print("URL is: "..url)
							dz.openURL(url)
							tomorrow_discharge_kwh.set(v.rate)
						end
					end
				end
			end
		end
	end
}

