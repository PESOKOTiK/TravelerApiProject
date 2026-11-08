# Test 2: Travel Plans CRUD and Input Validation (400, 404, 201, 200, 204)

# 2.1 Validation error on empty title -> 400 Bad Request
POST {{base_url}}/api/travel-plans
Content-Type: application/json
{
  "title": "   ",
  "budget": 1000,
  "currency": "EUR"
}
HTTP 400

# 2.2 Validation error on negative budget -> 400 Bad Request
POST {{base_url}}/api/travel-plans
Content-Type: application/json
{
  "title": "Negative Budget Trip",
  "budget": -50,
  "currency": "EUR"
}
HTTP 400

# 2.3 Validation error on end_date < start_date -> 400 Bad Request
POST {{base_url}}/api/travel-plans
Content-Type: application/json
{
  "title": "Invalid Dates Trip",
  "start_date": "2026-08-15",
  "end_date": "2026-08-01"
}
HTTP 400

# 2.4 Create valid Travel Plan -> 201 Created
POST {{base_url}}/api/travel-plans
Content-Type: application/json
{
  "title": "Європа",
  "description": "Summer Eurotrip",
  "start_date": "2026-07-01",
  "end_date": "2026-07-20",
  "budget": 2000.00,
  "currency": "EUR",
  "is_public": true
}
HTTP 201
[Captures]
plan_id: jsonpath "$.id"
initial_version: jsonpath "$.version"
[Asserts]
jsonpath "$.title" == "Європа"
jsonpath "$.version" == 1
jsonpath "$.budget" == 2000.00

# 2.5 Get created Travel Plan -> 200 OK
GET {{base_url}}/api/travel-plans/{{plan_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{plan_id}}
jsonpath "$.version" == 1

# 2.6 Non-existent Travel Plan -> 404 Not Found
GET {{base_url}}/api/travel-plans/00000000-0000-0000-0000-000000000999
HTTP 404
