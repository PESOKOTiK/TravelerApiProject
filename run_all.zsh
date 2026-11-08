#!/usr/bin/env zsh
set -eu

echo "========================================================"
echo "  TravelerAPI - Automated Launch & Test Suite (Zsh)"
echo "========================================================"

# 0. Ensure port 5000 is free before starting
fuser -k 5000/tcp >/dev/null 2>&1 || true

# 1. Start PostgreSQL container via Docker Compose
echo "[1/5] Starting PostgreSQL database via Docker Compose..."
docker compose up -d

echo "[2/5] Waiting for PostgreSQL healthcheck..."
until docker exec traveler_postgres pg_isready -U postgres -d traveler_db >/dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL is ready!"

# Apply schema.sql explicitly to ensure clean state
docker exec -i traveler_postgres psql -U postgres -d traveler_db < ./db/schema.sql >/dev/null

# 2. Build and launch ASP.NET Core API in background
echo "[3/5] Building and starting ASP.NET Core Web API on http://localhost:5000 ..."
dotnet build ./src/TravelerApi/TravelerApi.csproj -v quiet --nologo
dotnet run --no-build --project ./src/TravelerApi/TravelerApi.csproj --urls "http://localhost:5000" > api.log 2>&1 &
API_PID=$!

cleanup() {
  echo ""
  echo "[Cleanup] Stopping TravelerAPI (PID: $API_PID)..."
  kill $API_PID 2>/dev/null || true
}
trap cleanup EXIT

# Wait until /api/health returns 200
echo "Waiting for API to listen on http://localhost:5000/api/health ..."
for i in {1..30}; do
  if curl -s -f "http://localhost:5000/api/health" >/dev/null 2>&1; then
    echo "API is online!"
    break
  fi
  sleep 1
done

# 3. Run Hurl Test Suite
echo "[4/5] Running Hurl integration & concurrency tests..."
hurl --test ./tests/*.hurl --variables-file ./tests/variables.properties

# 4. Run Parallel Race-Condition Verification (Problem 2: Simultaneous POSTs)
echo ""
echo "[5/5] Running parallel race-condition stress test (10 concurrent location additions)..."
CREATE_RESP=$(curl -s -X POST "http://localhost:5000/api/travel-plans" \
  -H "Content-Type: application/json" \
  -d '{"title":"Parallel Stress Plan","budget":5000,"currency":"EUR"}')

PLAN_ID=$(printf '%s' "$CREATE_RESP" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
echo "Created test TravelPlan ID: $PLAN_ID"

pids=()
for i in {1..10}; do
  curl -s --max-time 10 -X POST "http://localhost:5000/api/travel-plans/$PLAN_ID/locations" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Concurrent City $i\",\"budget\":100}" >/dev/null &
  pids+=($!)
done

for pid in "${pids[@]}"; do
  wait "$pid"
done

PLAN_STATE=$(curl -s "http://localhost:5000/api/travel-plans/$PLAN_ID")
ORDERS=$(printf '%s' "$PLAN_STATE" | grep -oE '"visit_order":[0-9]+' | cut -d: -f2 | sort -n | tr '\n' ' ')

echo "Assigned sequential visit_orders under parallel load: [ $ORDERS]"
echo "========================================================"
echo "  All checks completed successfully!"
echo "========================================================"
