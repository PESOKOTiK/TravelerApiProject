# Test 1: Health Check Endpoint
GET {{base_url}}/api/health
HTTP 200
[Asserts]
jsonpath "$.status" == "Healthy"
jsonpath "$.database" == "Connected"
