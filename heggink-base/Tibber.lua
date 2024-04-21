--
-- get energy rates from Tibber
-- devices
local idxMgdCounter="KWH rates"

-- user variables
return {
	on = {
		devices = 	{'tibberbutton'}, 	-- device to rerun
		timer = 	{'at 13:55'}, 		-- Timer to get new electricity prices.
		httpResponses = {'dayrates'}, 		-- function to call when rates are received
		--customEvents = 	{'tibberrerun'}, 	-- event to rerun in case no good rates were received
	},
	logging = { level = domoticz.LOG_NORMAL, marker = 'Tibber prices', },
	data = { retry = { initial = 0 }, },

	execute = function(dz, item)
		
		function round(num, numDecimalPlaces)
			return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
		end
		if (not item.isHTTPResponse) then -- button, timer or rerun event
			print("URL ") -- launch the URL
			dz.openURL({
				url = 'https://api.tibber.com/v1-beta/gql',  -- the API website
				method = 'POST',
				headers = { 
					['Authorization'] = "Bearer YOUR OWN TOKEN FOR THE TIBBER API", 
					['Content-Type'] = "application/json"
				},
				postData = '{ "query": "{viewer {homes {currentSubscription {priceInfo {current {total energy tax startsAt} today {total energy tax startsAt} tomorrow {total energy tax startsAt}}}}}}" }',
				callback = 'dayrates'
			})
		else -- item.isHTTPResponse: response to openURL received
			local hr = dz.time.hour
			local lr_d = 10000
			local lr_n = 10000
			local d_h = 25
			local n_h = 25
			local lowrate_night = 100
			if (item.ok) then
				if item.isJSON then
					for i = 1,24,1 do
						--print(item.json.data)
						if item.json.data.viewer.homes[1] == nil then
							if dz.data.retry < 5 then
								dz.notify('INFO', 'Tibber 1 issue with data for hour '..i)
								dz.log('Tibber issue with data for hour '..i, dz.LOG_ERROR)
								dz.emitEvent('tibberrerun').afterMin(20)
								dz.data.retry = dz.data.retry + 1
							end
							do return end
						elseif item.json.data.viewer.homes[1].currentSubscription == nil then
							if dz.data.retry < 5 then
								dz.notify('INFO', 'Tibber 2 issue with data for hour '..i)
								dz.log('Tibber issue with data for hour '..i, dz.LOG_ERROR)
								dz.emitEvent('tibberrerun').afterMin(20)
								dz.data.retry = dz.data.retry + 1
							end
							do return end
						elseif item.json.data.viewer.homes[1].currentSubscription.priceInfo == nil then
							if dz.data.retry < 5 then
								dz.notify('INFO', 'Tibber 3 issue with data for hour '..i)
								dz.log('Tibber issue with data for hour '..i, dz.LOG_ERROR)
								dz.emitEvent('tibberrerun').afterMin(20)
								dz.data.retry = dz.data.retry + 1
							end
							do return end
						elseif item.json.data.viewer.homes[1].currentSubscription.priceInfo.tomorrow[i] == nil then
							if dz.data.retry < 5 then
								dz.notify('INFO', 'Tibber 4 issue with data for hour '..i)
								dz.log('Tibber issue with data for hour '..i, dz.LOG_ERROR)
								dz.emitEvent('tibberrerun').afterMin(20)
								dz.data.retry = dz.data.retry + 1
							end
							do return end
						elseif item.json.data.viewer.homes[1].currentSubscription.priceInfo.tomorrow[i].startsAt == nil then
							if dz.data.retry < 5 then
								dz.notify('INFO', 'Tibber 5 issue with data for hour '..i)
								dz.log('Tibber issue with data for hour '..i, dz.LOG_ERROR)
								dz.emitEvent('tibberrerun').afterMin(20)
								dz.data.retry = dz.data.retry + 1
							end
							do return end
						else	-- workable data received
							dz.data.retry = 0
							hr=string.sub(item.json.data.viewer.homes[1].currentSubscription.priceInfo.tomorrow[i].startsAt, 12, 13)
							ymd=string.sub(item.json.data.viewer.homes[1].currentSubscription.priceInfo.tomorrow[i].startsAt, 1, 10)
							rate=item.json.data.viewer.homes[1].currentSubscription.priceInfo.tomorrow[i].total
							local datestr=ymd.." "..hr..":30:00"
							rate = rate * 10000
							if tonumber(hr) < 7 and rate < lr_n then
								lr_n = rate
								n_h = tonumber(hr)
							elseif tonumber(hr) >= 7 and rate < lr_d then
								lr_d = rate
								d_h = tonumber(hr)
							end
							local historystring=rate .. ";" .. rate 
							dz.log("dz.devices(idxMgdCounter).updateHistory(\"" .. datestr .. "\",\"" .. historystring .. "\")", dz.LOG_DEBUG)
							dz.devices(idxMgdCounter).updateHistory(datestr,historystring)
							--print("Hour "..hr.." has rate "..rate)
						end
					end
				end
				dz.emitEvent('TibberRatesUpdated').afterMin(1)
				-- save tomorrow's values in tomorrow's variable
				dz.variables('LEHD 1').set(d_h)
				dz.variables('LEHN 1').set(n_h)
				if d_h >= 22 then -- boiler warms up from 10pm ie too late so use the night slot
					dz.variables('BoilerWarmUpTomorrow').set(n_h)
				else
					dz.variables('BoilerWarmUpTomorrow').set(d_h)
				end
				dz.variables('LERD 1').set(lr_d)
				dz.variables('LERN 1').set(lr_n)
			else
				dz.log('Response not ok', dz.LOG_INFO)
				dz.log(item, dz.LOG_INFO)
			end
		end
	end
}

