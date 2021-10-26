--[[ Model - CGMiner OverClocking ]]--

require("luci.http")
require("luci.dispatcher")
require("luci.sys")

login = SimpleForm("login", nil, nil)
login.reset = false
login.submit = translate("Login")

btn = login:field(Button, "")
btn.template = "overclockinglogin"

if luci.http.formvalue("cbi.submit") then
	pwd = luci.http.formvalue("password")
	if pwd == "canaan" then
		luci.http.redirect(luci.dispatcher.build_url("admin", "services", "overclocking"))
	else
		dummy = login:field(DummyValue, "dummy", "")
		dummy.template = "overclockingerror"
	end
	return login
end

f = SimpleForm("ohr", nil, nil)
f.reset = false
f.submit = translate("Enter")

set_list = f:field(ListValue, "set", translate("Overclocking Setting:"))
set_list:value("disable", translate("Disable"))
set_list:value("enable", translate("Enable"))

if luci.http.formvalue("cbi.submit") then
	flag = f:formvalue("cbid.ohr.1.set")
	i = 0
	while ( i < 4 ) do
		if flag == "disable" then
			cmd = "/usr/bin/cgminer-api " .. "\'ascset|" .. i .. ',overclocking,' .. '0' .. "\'"
		elseif flag == "enable" then
			cmd = "/usr/bin/cgminer-api " .. "\'ascset|" .. i .. ',overclocking,' .. '1' .. "\'"
		end
		luci.sys.exec(cmd)
		i = i + 1
	end
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "overclocking"))
end

dummy = f:field(DummyValue,"dumm", "")
dummy.template = "overclockingwarn"

return f
