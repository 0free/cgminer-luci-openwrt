-- Model - CGMiner Status

f = SimpleForm("cgminerstatus", translate("CGMiner Status"))

f.reset = false
f.submit = false

function valuetodate(elapsed)
	if elapsed then
		local str
		local days
		local h
		local m
		local s = elapsed % 60;
		elapsed = elapsed - s
		elapsed = elapsed / 60
		if elapsed == 0 then
			str = string.format("%ds", s)
		else
			m = elapsed % 60;
			elapsed = elapsed - m
			elapsed = elapsed / 60
			if elapsed == 0 then
				str = string.format("%dm %ds", m, s);
			else
				h = elapsed % 24;
				elapsed = elapsed - h
				elapsed = elapsed / 24
				if elapsed == 0 then
					str = string.format("%dh %dm %ds", h, m, s)
				else
					str = string.format("%dd %dh %dm %ds", elapsed, h, m, s);
				end
			end
		end
		return str
	end
	return "date invalid"
end

-- Summary Table

function get_summary()
	local data = {}
	local summary = luci.util.execi("/usr/bin/cgminer-api -o summary | sed \"s/|/\\n/g\"")
	if not summary then
		return
	end
	local function num_commas(n)
		return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,"):gsub(",(%-?)$","%1"):reverse()
	end
	for line in summary do
		local elapsed, mhsav, foundblocks, getworks, accepted, rejected,
		hw, utility, stale, getfailures, remotefailures, networkblocks,
		totalmh, diffaccepted, diffrejected, diffstale, bestshare =
		line:match(".*," ..
			"Elapsed=(-?%d+)," ..
			"MHS av=(-?[%d%.]+)," ..
			".*," ..
			"Found Blocks=(-?%d+)," ..
			"Getworks=(-?%d+)," ..
			"Accepted=(-?%d+)," ..
			"Rejected=(-?%d+)," ..
			"Hardware Errors=(-?%d+)," ..
			"Utility=([-?%d%.]+)," ..
			".*," ..
			"Stale=(-?%d+)," ..
			"Get Failures=(-?%d+)," ..
			".-" ..
			"Remote Failures=(-?%d+)," ..
			"Network Blocks=(-?%d+)," ..
			"Total MH=(-?[%d%.]+)," ..
			".-" ..
			"Difficulty Accepted=(-?[%d]+)%.%d+," ..
			"Difficulty Rejected=(-?[%d]+)%.%d+," ..
			"Difficulty Stale=(-?[%d]+)%.%d+," ..
			"Best Share=(-?%d+)")
		if elapsed then
			data[#data+1] = {
				['elapsed'] = valuetodate(elapsed),
				['mhsav'] = num_commas(mhsav),
				['foundblocks'] = foundblocks,
				['getworks'] = num_commas(getworks),
				['accepted'] = num_commas(accepted),
				['rejected'] = num_commas(rejected),
				['hw'] = num_commas(hw),
				['utility'] = num_commas(utility),
				['stale'] = stale,
				['getfailures'] = getfailures,
				['remotefailures'] = remotefailures,
				['networkblocks'] = networkblocks,
				['totalmh'] = string.format("%e",totalmh),
				['diffaccepted'] = num_commas(diffaccepted),
				['diffrejected'] = num_commas(diffrejected),
				['diffstale'] = diffstale,
				['bestshare'] = num_commas(bestshare)
			}
		end
	end
	return data
end

local summary = get_summary()

t1 = f:section(Table, summary, translate("Summary"))

t1:option(DummyValue, "elapsed", translate("Elapsed"))

ghsav = t1:option(DummyValue, "mhsav", translate("GHSav"))

function ghsav.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section):gsub(",","")
	return string.format("%.2f", tonumber(v)/1000)
end

t1:option(DummyValue, "accepted", translate("Accepted"))
t1:option(DummyValue, "rejected", translate("Rejected"))
t1:option(DummyValue, "networkblocks", translate("NetworkBlocks"))
t1:option(DummyValue, "bestshare", translate("BestShare"))

-- Devices Table

function get_devs()
	local data = {}
	local devs = luci.util.execi("/usr/bin/cgminer-api -o edevs | sed \"s/|/\\n/g\"")
	if not devs then
		return
	end
	for line in devs do
		local asc, name, id, enabled, status, temp,
		mhsav, mhs5s, mhs1m, mhs5m, mhs15m, lvw, dh =
		line:match("ASC=(%d+)," ..
			"Name=([%a%d]+)," ..
			"ID=(%d+)," ..
			"Enabled=(%a+)," ..
			"Status=(%a+)," ..
			"Temperature=(-?[%d]+).%d+," ..
			"MHS av=(-?[%.%d]+)," ..
			"MHS 5s=(-?[%.%d]+)," ..
			"MHS 1m=(-?[%.%d]+)," ..
			"MHS 5m=(-?[%.%d]+)," ..
			"MHS 15m=(-?[%.%d]+)," ..
			".*," ..
			"Last Valid Work=(-?%d+)," ..
			"Device Hardware%%=(-?[%.%d]+)")
		if lvw == "0" then
			lvw_date = "Never"
		else
			lvw_date = os.date("%c", lst)
		end
		if asc then
			data[#data+1] = {
				['name'] = "ASC" .. asc .. "-" .. name .. "-" .. id,
				['enable'] = enabled,
				['status'] = status,
				['temp'] = temp,
				['mhsav'] = mhsav,
				['mhs5s'] = mhs5s,
				['mhs1m'] = mhs1m,
				['mhs5m'] = mhs5m,
				['mhs15m'] = mhs15m,
				['lvw'] = lvw_date
			}
		end
	end
	return data
end

local devs = get_devs()

t2 = f:section(Table, devs, translate("Avalon Devices"))

t2:option(DummyValue, "name", translate("Device"))
t2:option(DummyValue, "enable", translate("Enabled"))
t2:option(DummyValue, "status", translate("Status"))
t2:option(DummyValue, "lvw", translate("LastValidWork"))

ghsav = t2:option(DummyValue, "mhsav", translate("GHSav"))
ghs5s = t2:option(DummyValue, "mhs5s", translate("GHS5s"))
ghs1m = t2:option(DummyValue, "mhs1m", translate("GHS1m"))
ghs5m = t2:option(DummyValue, "mhs5m", translate("GHS5m"))
ghs15m = t2:option(DummyValue, "mhs15m", translate("GHS15m"))

function ghsav.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

function ghs5s.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

function ghs1m.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

function ghs5m.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

function ghs15m.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

-- Stats Table

function get_stats()
	local data = {}
	local stats = luci.util.execi("/usr/bin/cgminer-api -o estats | sed \"s/|/\\n/g\" | grep AV9")
	if not stats then
		return
	end
	for line in stats do
		local id =
		line:match(".*" ..
		"ID=AV9([%d]+),")
		if id then
			local istart, iend = line:find("MM ID")
			while (istart) do
				local istr = line:sub(istart)
				local idname
				local index, idn, dnan, elapsedn, lwn, dhn, tempn, tempm,
				fann, fanr, ghsmm, wun, pgn, ledn, echu, ecmm, crc =
				istr:match("MM ID(%d+)=" ..
					"Ver%[([%+%-%d%a]+)%]" ..
					".-" ..
					"DNA%[(%x+)%]" ..
					".-" ..
					"Elapsed%[(-?%d+)%]" ..
					".-" ..
					"LW%[(-?%d+)%]" ..
					".-" ..
					"DH%[(-?[%.%d%%]+)%]" ..
					".-" ..
					"Temp%[(-?%d+)%]" ..
					".-" ..
					"TMax%[(-?%d+)%]" ..
					".-" ..
					"Fan%[(-?%d+)%]" ..
					".-" ..
					"FanR%[(-?%d+%%)%]" ..
					".-" ..
					"GHSmm%[(-?[%.%d]+)%]" ..
					".-" ..
					"WU%[(-?[%.%d]+)%]" ..
					".-" ..
					"PG%[(%d+)%]" ..
					".-" ..
					"Led%[(%d)%]" ..
					".-" ..
					"ECHU%[(%d+%s%d+%s%d+%s%d+)%]" ..
					".-" ..
					"ECMM%[(%d+)%]" ..
					".-" ..
					"CRC%[(%d+%s%d+%s%d+%s%d+)%]")
				if idn ~= nil then
					idname = 'A' .. string.sub(idn, 1, 3) .. 'S-'
					data[#data+1] = {
						['devid'] = id,
						['moduleid'] = tostring(index),
						['id'] = idname .. id .. '-' .. tostring(index),
						['mm'] = idn,
						['dna'] = string.sub(dnan, -4, -1),
						['elapsed'] = valuetodate(elapsedn),
						['lw'] = lwn or '0',
						['dh'] = dhn or '0',
						['temp'] = (tempn or '0') .. ' / ' .. (tempm or '0'),
						['fan'] = (fann or '0') .. 'RPM / ' .. (fanr or '0'),
						['ghsmm'] = ghsmm or '0',
						['wu'] = wun or '0',
						['pg'] = pgn or '0',
						['led'] = ledn or '0',
						['echu'] = echu or '0',
						['ecmm'] = ecmm or '0',
						['crc'] = crc or '0'
					}
				end
				istart, iend = line:find("MM ID", iend + 1)
			end
		end
	end
	return data
end

local stats = get_stats()

t3 = f:section(Table, stats, translate("Avalon Devices Status"))

indicator = t3:option(Button, "_indicator", translate("Indicator"))

function indicator.render(self, section, scope)
	if stats[section].led == '0' then
		self.title = translate("LED OFF")
	else
		self.title = translate("LED ON")
	end
	Button.render(self, section, scope)
end

function indicator.write(self, section)
	cmd = "/usr/bin/cgminer-api " .. "\'ascset|" .. stats[section].devid .. ',led,' .. stats[section].moduleid .. "\'"
	luci.util.execi(cmd)
	if stats[section].led == '0' then
		stats[section].led = '1'
	else
		stats[section].led = '0'
	end
end

reboot = t3:option(Button, "_reboot", translate("Reboot"))

function reboot.write(self, section)
	cmd = "/usr/bin/cgminer-api " .. "\'ascset|" .. stats[section].devid .. ',reboot,' .. stats[section].moduleid .. "\'"
	luci.util.execi(cmd)
end

t3:option(DummyValue, "elapsed", translate("Elapsed"))
t3:option(DummyValue, "id", translate("<abbr title=\"Device ID\">Device</abbr>"))
t3:option(DummyValue, "mm", translate("<abbr title=\"MM Version\">MM</abbr>"))
t3:option(DummyValue, "dna", translate("<abbr title=\"MM DNA\">DNA</abbr>"))
t3:option(DummyValue, "lw", translate("LocalWorks"))
t3:option(DummyValue, "dh", translate("<abbr title=\"Device Hardware Error\">DH</abbr>"))
t3:option(DummyValue, "ghsmm", translate("GHSasc"))
t3:option(DummyValue, "wu", translate("WU"))
t3:option(DummyValue, "temp", translate("<abbr title=\"Inflow/Outflow\">Temperature(C)</abbr>"))
t3:option(DummyValue, "fan", translate("<abbr title=\"RPM/Percentage\">Fan</abbr>"))
t3:option(DummyValue, "pg", translate("<abbr title=\"Power Good\">PG</abbr>"))

-- Pools Table

function get_pools()
	local data = {}
	local pools = luci.util.execi("/usr/bin/cgminer-api -o pools | sed \"s/|/\\n/g\"")
	if not pools then
		return
	end
	for line in pools do
		local pi, url, st, pri, quo, lp, gw, a, r, sta, gf, rf,
		user, lst, ds, da, dr, dsta, lsd, hs, sa, sd, hg =
		line:match("POOL=(-?%d+)," ..
			"URL=(.*)," ..
			"Status=(%a+)," ..
			"Priority=(-?%d+)," ..
			"Quota=(-?%d+)," ..
			"Long Poll=(%a+)," ..
			"Getworks=(-?%d+)," ..
			"Accepted=(-?%d+)," ..
			"Rejected=(-?%d+)," ..
			".*," ..
			"Stale=(-?%d+)," ..
			"Get Failures=(-?%d+)," ..
			"Remote Failures=(-?%d+)," ..
			"User=(.*)," ..
			"Last Share Time=(-?%d+)," ..
			"Diff1 Shares=(-?%d+)," ..
			".*," ..
			"Difficulty Accepted=(-?%d+)[%.%d]+," ..
			"Difficulty Rejected=(-?%d+)[%.%d]+," ..
			"Difficulty Stale=(-?%d+)[%.%d]+," ..
			"Last Share Difficulty=(-?%d+)[%.%d]+," ..
			".-," ..
			"Has Stratum=(%a+)," ..
			"Stratum Active=(%a+)," ..
			".-," ..
			"Stratum Difficulty=(-?%d+)[%.%d]+," ..
			"Has GBT=(%a+)")
		if pi then
			if lst == "0" then
				lst_date = "Never"
			else
				lst_date = os.date("%c", lst)
			end
			data[#data+1] = {
				['pool'] = pi,
				['url'] = url,
				['status'] = st,
				['priority'] = pri,
				['quota'] = quo,
				['longpoll'] = lp,
				['getworks'] = gw,
				['accepted'] = a,
				['rejected'] = r,
				['stale'] = sta,
				['getfailures'] = gf,
				['remotefailures'] = rf,
				['user'] = user,
				['lastsharetime'] = lst_date,
				['diff1shares'] = ds,
				['diffaccepted'] = da,
				['diffrejected'] = dr,
				['diffstale'] = dsta,
				['lastsharedifficulty'] = lsd,
				['hasstratum'] = hs,
				['stratumactive'] = sa,
				['stratumdifficulty'] = sd,
				['hasgbt'] = hg
			}
		end
	end
	return data
end

local pools = get_pools()

t4 = f:section(Table, pools, translate("Pools"))

t4:option(DummyValue, "pool", translate("Pool"))
t4:option(DummyValue, "url", translate("URL"))
t4:option(DummyValue, "stratumactive", translate("StratumActive"))
t4:option(DummyValue, "user", translate("User"))
t4:option(DummyValue, "status", translate("Status"))
t4:option(DummyValue, "stratumdifficulty", translate("StratumDifficulty"))
t4:option(DummyValue, "getworks", translate("GetWorks"))
t4:option(DummyValue, "accepted", translate("Accepted"))
t4:option(DummyValue, "rejected", translate("Rejected"))
t4:option(DummyValue, "stale", translate("Stale"))
t4:option(DummyValue, "lastsharetime", translate("LST"))
t4:option(DummyValue, "lastsharedifficulty", translate("LSD"))

-- Controls Table

t5 = f:section(Table, {{}}, translate("CGminer Control"))

start = t5:option(Button, "_start", translate("Start"))
restart = t5:option(Button, "_restart", translate("Restart"))
stop = t5:option(Button, "_stop", translate("Stop"))

function start.write(self, section)
	luci.dispatcher.build_url("admin", "services", "cgminerstatus", "ctrl", "start")
end

function restart.write(self, section)
	luci.dispatcher.build_url("admin", "services", "cgminerstatus", "ctrl", "restart")
end

function stop.write(self, section)
	luci.dispatcher.build_url("admin", "services", "cgminerstatus", "ctrl", "stop")
end

return f

