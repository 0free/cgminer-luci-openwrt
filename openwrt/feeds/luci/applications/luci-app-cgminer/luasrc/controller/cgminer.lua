-- Controller - CGMiner

module("luci.controller.cgminer", package.seeall)

function index()
	entry( { "admin", "services", "cgminerstatus" }, cbi("cgminer/cgminerstatus"), _("CGMiner Status"), 1 )
	entry( { "admin", "services", "cgminer" }, cbi("cgminer/cgminer"), _("CGMiner Configuration"), 2 )
	entry( { "admin", "services", "cgminerapi" }, call("action_cgminerapi"), _("CGMiner API Log"), 3 )
	entry( { "admin", "services", "mmupgrade" }, call("action_mmupgrade"), _("CGMiner MM Upgrade"), 4 )
	entry( { "admin", "services", "overclocking" }, cbi("cgminer/overclocking"), _("CGMiner OverClocking"), 5 )
	entry( { "admin", "services", "cgminerstatus", "ctrl" }, call("action_cgminerctrl") ).leaf = true
	entry( { "admin", "services", "set_miningmode" }, call("action_setminingmode") ).leaf = true
	entry( { "admin", "services", "checkupgrade" }, call("action_checkupgrade") ).leaf = true
	entry( { "admin", "services", "cgminerdebug" }, call("action_cgminerdebug") ).leaf = true
end

function action_cgminerctrl(args)
	if args then
		luci.util.exec("/etc/init.d/cgminer " .. args)
		if args == "stop" then
			luci.util.exec("[ ! -e /root/.cron ] && crontab -l | grep cgminer-monitor > /root/.cron")
			luci.util.exec("sed -i -e '/.*cgminer-monitor/d' /etc/crontabs/root")
		else
			luci.util.exec("[ -e /root/.cron ] && sed -i -e '/.*cgminer-monitor/d' /etc/crontabs/root")
			luci.util.exec("[ -e /root/.cron ] && cat /root/.cron >> /etc/crontabs/root")
		end
		luci.http.redirect(luci.dispatcher.build_url("admin", "services", "cgminerstatus"))
	else
		return
	end
end

function action_cgminerapi()
	local pp = io.popen("/usr/bin/cgminer-api stats|sed 's/ =>/:/g'|sed 's/\\] /\\]\\n /g'|sed 's/:/ =>/g'")
	local data = pp:read("*a")
	pp:close()
	luci.template.render("cgminerapi", {api=data})
end

function action_cgminerdebug()
	luci.util.exec("cgminer-api \"debug|D\"")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "cgminerapi"))
end


function action_setminingmode()
	local uci = luci.model.uci.cursor()
	local mmode = luci.http.formvalue("mining_mode")
	local modetab = {
			customs = " ",
			normal = "-c /etc/config/a4.normal",
			eco = "-c /etc/config/a4.eco",
			turbo = "-c /etc/config/a4.turbo"
			}
	if modetab[mmode] then
		uci:set("cgminer", "default", "mining_mode", modetab[mmode])
		uci:save("cgminer")
		uci:commit("cgminer")
		if mmode == "customs" then
			luci.http.redirect(luci.dispatcher.build_url("admin", "services", "cgminer"))
		else
			luci.http.redirect(luci.dispatcher.build_url("admin", "services", "cgminerstatus", "ctrl", "restart"))
		end
	end
end

function action_mmupgrade()
	local mm_tmp = "/tmp/mm.mcs"
	local finish_flag = "/tmp/mm_finish"
	local function mm_upgrade_avail()
		if nixio.fs.access("/usr/bin/mm-tools") then
			return true
		end
		return nil
	end
	local function mm_supported()
		local mm_tmp = "/tmp/mm.mcs"
		if not nixio.fs.access(mm_tmp) then
			return false
		end
		local filesize = nixio.fs.stat(mm_tmp).size
		-- check mm.mcs format
		if filesize == 0 then
			return false
		end
		return true
	end
	local function mm_checksum()
		return (luci.sys.exec("md5sum %q" % mm_tmp):match("^([^%s]+)"))
	end
	local function storage_size()
		local size = 0
		if nixio.fs.access("/proc/mtd") then
			for l in io.lines("/proc/mtd") do
				local d, s, e, n = l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+"([^%s]+)"')
				if n == "linux" or n == "firmware" then
					size = tonumber(s, 16)
					break
				end
			end
		elseif nixio.fs.access("/proc/partitions") then
			for l in io.lines("/proc/partitions") do
				local x, y, b, n = l:match('^%s*(%d+)%s+(%d+)%s+([^%s]+)%s+([^%s]+)')
				if b and n and not n:match('[0-9]') then
					size = tonumber(b) * 1024
					break
				end
			end
		end
		return size
	end
	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and meta.name == "image" then
					fp = io.open(mm_tmp, "w")
				end
			end
			if chunk then
				fp:write(chunk)
			end
			if eof and fp then
				fp:close()
			end
		end
	)
	local function fork_exec(command)
		local pid = nixio.fork()
		if pid > 0 then
			return
		elseif pid == 0 then
			-- change to root dir
			nixio.chdir("/")
			-- patch stdin, out, err to /dev/null
			local null = nixio.open("/dev/null", "w+")
			if null then
				nixio.dup(null, nixio.stderr)
				nixio.dup(null, nixio.stdout)
				nixio.dup(null, nixio.stdin)
				if null:fileno() > 2 then
					null:close()
				end
			end
			-- replace with target command
			nixio.exec("/bin/sh", "-c", command)
		end
	end
	if luci.http.formvalue("image") or luci.http.formvalue("step") then
		-- Check firmware
		local step = tonumber(luci.http.formvalue("step") or 1)
		if step == 1 then
			if mm_supported() == true then
				luci.template.render("mmupgrade", {
					checksum = mm_checksum(),
					storage = storage_size(),
					size = nixio.fs.stat(mm_tmp).size,
				})
			else
				nixio.fs.unlink(mm_tmp)
				luci.template.render("mmupload", {
					mm_upgrade_avail = mm_upgrade_avail(),
					mm_image_invalid = true
				})
			end
		-- Upgrade firmware
		elseif step == 2 then
			luci.template.render("mmapply")
			fork_exec("mmupgrade;touch %q;" %{ finish_flag })
		elseif step == 3 then
			nixio.fs.unlink(finish_flag)
			luci.template.render("mmapply", { finish = 1 })
		end
	else
		luci.template.render("mmupload", { mm_upgrade_avail = mm_upgrade_avail() })
	end
end

function action_checkupgrade()
	local status = {}
	local finish_flag = "/tmp/mm_finish"
	if not nixio.fs.access(finish_flag) then
		status.finish = 0
	else
		status.finish = 1
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json(status)
end

