local cjson = require "cjson"
local json = cjson.new()
local log_line = {}

log_line.request = {}
log_line.request.timestamp = ngx.var.time_iso8601
log_line.request.method = ngx.req.get_method()
log_line.request.url = {}
log_line.request.url.host = ngx.var.host
log_line.request.url.uri = ngx.var.request_uri
log_line.request.url.query = ngx.req.get_uri_args()
log_line.request.headers = ngx.req.get_headers()
log_line.request.body = ngx.encode_base64(ngx.var.request_body, true)



log_line.response = {}
log_line.response.status = ngx.status
log_line.response.headers = ngx.resp.get_headers()
log_line.response.body = ngx.encode_base64(ngx.var.response_body, true)
local encoded_json = json.encode(log_line)
ngx.var.log_line = encoded_json
