# Test 3: Concurrency & Race Conditions (Problems 1, 2, 3)

# Setup: Create Travel Plan for concurrency tests
POST {{base_url}}/api/travel-plans
Content-Type: application/json
{
  "title": "Європа",
  "budget": 2000.00,
  "currency": "EUR"
}
HTTP 201
[Captures]
plan_id: jsonpath "$.id"
plan_v1: jsonpath "$.version"

# ==========================================================
# PROBLEM 1: Concurrent Plan Updates (Optimistic Locking)
# ==========================================================
# User A updates budget to 2500 with version 1 -> Succeeds, version becomes 2
PUT {{base_url}}/api/travel-plans/{{plan_id}}
Content-Type: application/json
{
  "title": "Європа",
  "budget": 2500.00,
  "currency": "EUR",
  "version": {{plan_v1}}
}
HTTP 200
[Asserts]
jsonpath "$.version" == 2
jsonpath "$.budget" == 2500.00

# User B tries to update title to "Супер Європа" using stale version 1 -> 409 Conflict!
PUT {{base_url}}/api/travel-plans/{{plan_id}}
Content-Type: application/json
{
  "title": "Супер Європа",
  "budget": 2000.00,
  "currency": "EUR",
  "version": {{plan_v1}}
}
HTTP 409
[Asserts]
jsonpath "$.current_version" == 2

# ==========================================================
# PROBLEM 2: Sequential Location Auto-Ordering
# ==========================================================
# Add 1st Location: Paris -> auto-assigned visit_order = 1
POST {{base_url}}/api/travel-plans/{{plan_id}}/locations
Content-Type: application/json
{
  "name": "Paris",
  "budget": 500.00,
  "notes": "Eiffel Tower"
}
HTTP 201
[Captures]
loc_paris_id: jsonpath "$.id"
loc_paris_v1: jsonpath "$.version"
[Asserts]
jsonpath "$.visit_order" == 1
jsonpath "$.version" == 1

# Add 2nd Location: Rome -> auto-assigned visit_order = 2
POST {{base_url}}/api/travel-plans/{{plan_id}}/locations
Content-Type: application/json
{
  "name": "Rome",
  "budget": 400.00
}
HTTP 201
[Captures]
loc_rome_id: jsonpath "$.id"
[Asserts]
jsonpath "$.visit_order" == 2

# Add 3rd Location: Madrid -> auto-assigned visit_order = 3
POST {{base_url}}/api/travel-plans/{{plan_id}}/locations
Content-Type: application/json
{
  "name": "Madrid",
  "budget": 350.00
}
HTTP 201
[Captures]
loc_madrid_id: jsonpath "$.id"
[Asserts]
jsonpath "$.visit_order" == 3

# ==========================================================
# PROBLEM 3 ("І в раю муха сяде"): Concurrent Location Updates
# ==========================================================
# User A updates Paris budget 50 -> 75 with version 1 -> 200 OK (version becomes 2)
PUT {{base_url}}/api/locations/{{loc_paris_id}}
Content-Type: application/json
{
  "name": "Paris",
  "budget": 75.00,
  "notes": "Book tickets",
  "version": {{loc_paris_v1}}
}
HTTP 200
[Asserts]
jsonpath "$.version" == 2
jsonpath "$.budget" == 75.00

# User B attempts to update Paris notes with stale version 1 -> 409 Conflict!
PUT {{base_url}}/api/locations/{{loc_paris_id}}
Content-Type: application/json
{
  "name": "Paris",
  "budget": 50.00,
  "notes": "Tickets booked!",
  "version": {{loc_paris_v1}}
}
HTTP 409
[Asserts]
jsonpath "$.current_version" == 2

# Cleanup: Cascade Delete Travel Plan -> 204 No Content
DELETE {{base_url}}/api/travel-plans/{{plan_id}}
HTTP 204

# Verify deletion -> 404 Not Found
GET {{base_url}}/api/travel-plans/{{plan_id}}
HTTP 404
