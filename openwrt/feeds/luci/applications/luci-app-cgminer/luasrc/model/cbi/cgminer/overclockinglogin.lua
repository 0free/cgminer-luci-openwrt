--[[ Model - CGMiner OverClocking Login ]]--

require("luci.http")
require("luci.dispatcher")

login = SimpleForm("overclockinglogin", nil, nil)
login.reset = false
login.submit = translate("Login")

btn = login:field(Button, "")
btn.template = "overclockinglogin"

if luci.http.formvalue("cbi.submit") then
	pwd = luci.http.formvalue("password")
	if pwd == "canaan" then
		luci.http.redirect(luci.dispatcher.build_url("admin", "overclockingset"))
	else
		dummy = login:field(DummyValue, "dummy", "")
		dummy.template = "overclockingerror"
	end
end

return login
