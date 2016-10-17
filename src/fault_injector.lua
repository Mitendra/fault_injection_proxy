-- A sample fault would look like
-- key: reuqest_id_abc_001
-- value: "{\"markdown\":{\"uri\":[\"users\"]},\"delay\":{\"books\":\"10\"}}";
-- As part of request processing, request will be inspected and few details wil be extracted like server port, request id and uri
-- Server port will be used to do load balancing if multiple instances of the upstream servers are running
-- By default it will be assumed that the servers are running on local machine
-- uri and port will be used to determine if there is any fault present
-- for markdown kind of faults, simply 500 will be retunred
-- for delays ngx.sleep will be used to insert a controlled delay
function has_value (tab, val)
	for index, value in ipairs (tab) do
		if value == val then
			return true
		end
	end
	return false
end
REDIS_HOST = "127.0.0.1"
REDIS_PORT = "6379"
DEFAULT_UPSTREAM_SERVER = "127.0.0.1"
local redis = require "resty.redis"
local red = redis:new()
red:set_timeout(1000) -- 1 second
local ok, err = red:connect(REDIS_HOST,REDIS_PORT)
if not ok then
	ngx.var.target = DEFAULT_UPSTREAM_SERVER
else
	local key = table.concat({"service_discovery", env }, ":")
	-- Services are idenified by the port they listen to. 
	-- Can also be identified by service name or any other information which can be extracted from the request
	local host_list_str, err = red:hmget(key, ngx.var.server_port)
	if not host_list_str or host_list_str[1] == ngx.null then
		ngx.var.target =  DEFAULT_UPSTREAM_SERVER
	else
		local hosts = {}
		local index = 1
		-- Comma seperated host list for a given service
		for value in string.gmatch(host_list_str[1], "[^,]+") do
			hosts[index] = value
			index = index + 1
		end
		-- Pick a random host, assuming randomness will also bring some form of roundrobin-ness
		ngx.var.target = hosts[math.random(#hosts)]
		ngx.log(ngx.ERR, "selected host is: " .. ngx.var.target)
	end
	-- Load balancing part ends here
	-- Fault  injection logic
	local headers = ngx.req.get_headers()
	local req_id =  headers["request-id"]
	-- Check fault injection information in redis for the request-id 
	if(req_id) then
		ngx.log(ngx.ERR, "request-id" .. req_id)
		local fault_details, err1 = red:hmget("faultinjection",req_id) 
		if not fault_details or fault_details[1] == ngx.null then
			ngx.log(ngx.ERR, "No fault details found")
		else
			#local operation = headers.operation
			local operation = ngx.var.uri
			ngx.log(ngx.ERR, "operation is: " .. operation)
			local cjson = require "cjson"
			local json = cjson.new()
			local faults = cjson.decode(fault_details[1])
			local markdowns = faults.markdown
			ngx.log(ngx.ERR, "First Markdown is: " .. markdowns.uri[1])
			if(has_value(markdowns.uri, operation)) then
				ngx.log(ngx.ERR, "Returning from markdown: ")
				ngx.exit(500)
			else
				ngx.log(ngx.ERR, "No markdown found for this uri continuing normally")
			end
			local delays = faults.delay
			if delays then
				 local request_delay = delays[operation]
				 if request_delay then
					 ngx.log(ngx.ERR, "Delaying the request")
					 ngx.sleep(tonumber(request_delay))
				 else
					 ngx.log(ngx.ERR, "No delay found for this uri continuing normally")
				 end
			else
				ngx.log(ngx.ERR, "No delay found")
			end
	end
end
