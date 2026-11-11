#!/usr/bin/env zsh
set -eu

echo "=================================================================="
echo "  TravelerAPI - Lab 2: Native PostgreSQL + k6 Performance Suite"
echo "=================================================================="
echo "Mode: QUICK_MODE=${QUICK_MODE:-1} (Set QUICK_MODE=0 for full 60-min runs)"
export QUICK_MODE=${QUICK_MODE:-1}
export API_URL="http://localhost:5000"

# 0. Check required native tools (No Docker per Lab 2 rules!)
if ! command -v k6 >/dev/null 2>&1; then
  echo "ERROR: 'k6' is not installed. On Arch/CachyOS install via: sudo pacman -S k6"
  exit 1
fi

# Stop Docker postgres container if it's still holding port 5432 from Lab 1
if command -v docker >/dev/null 2>&1; then
  docker stop traveler_postgres >/dev/null 2>&1 || true
fi

fuser -k 5000/tcp >/dev/null 2>&1 || true

# 1. Ensure Native PostgreSQL service is running on host (No virtualization)
echo "[1/5] Checking native host PostgreSQL service (No Docker)..."
if ! systemctl is-active --quiet postgresql; then
  echo "Starting native postgresql.service..."
  sudo systemctl start postgresql
fi

# Configure database, user password, and apply schema.sql natively
echo "[2/5] Initializing 'traveler_db' and applying schema.sql on native PostgreSQL..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'traveler_db'" | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE traveler_db;"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgrespassword';" >/dev/null
PGPASSWORD=postgrespassword psql -h localhost -U postgres -d traveler_db -f ./db/schema.sql >/dev/null

# 2. Build and start ASP.NET Core API in Release mode with high connection pool
echo "[3/5] Building and starting TravelerAPI in Release mode on http://localhost:5000 ..."
export ConnectionStrings__DefaultConnection="Host=localhost;Port=5432;Database=traveler_db;Username=postgres;Password=postgrespassword;Maximum Pool Size=200"
dotnet build ./src/TravelerApi/TravelerApi.csproj -c Release -v quiet --nologo
dotnet run -c Release --no-build --project ./src/TravelerApi/TravelerApi.csproj --urls "http://localhost:5000" > api_lab2.log 2>&1 &
API_PID=$!

cleanup() {
  echo ""
  echo "[Cleanup] Stopping TravelerAPI (PID: $API_PID)..."
  kill $API_PID 2>/dev/null || true
}
trap cleanup EXIT

for i in {1..30}; do
  if curl -s -f "http://localhost:5000/api/health" >/dev/null 2>&1; then
    echo "API is online (Release build, native PostgreSQL)!"
    break
  fi
  sleep 1
done

mkdir -p ./results/lab2

# 3. Run all 5 k6 scenarios sequentially and save summaries
echo ""
echo "[4/5] Running k6 Performance Testing Scenarios..."

echo "------------------------------------------------------------------"
echo "  Task 1: Smoke Test (smoke-test.js)"
echo "------------------------------------------------------------------"
k6 run ./tests/performance-tests/smoke-test.js --summary-export=./results/lab2/01_smoke_summary.json | tee ./results/lab2/01_smoke.txt

echo "------------------------------------------------------------------"
echo "  Task 2: Load Test (load-test.js)"
echo "------------------------------------------------------------------"
k6 run ./tests/performance-tests/load-test.js --summary-export=./results/lab2/02_load_summary.json | tee ./results/lab2/02_load.txt

echo "------------------------------------------------------------------"
echo "  Task 3: Stress Test (stress-test.js)"
echo "------------------------------------------------------------------"
k6 run ./tests/performance-tests/stress-test.js --summary-export=./results/lab2/03_stress_summary.json | tee ./results/lab2/03_stress.txt

echo "------------------------------------------------------------------"
echo "  Task 4: Spike Test (spike-test.js)"
echo "------------------------------------------------------------------"
k6 run ./tests/performance-tests/spike-test.js --summary-export=./results/lab2/04_spike_summary.json | tee ./results/lab2/04_spike.txt

echo "------------------------------------------------------------------"
echo "  Task 5: Endurance / Soak Test (endurance-test.js)"
echo "------------------------------------------------------------------"
k6 run ./tests/performance-tests/endurance-test.js --summary-export=./results/lab2/05_endurance_summary.json | tee ./results/lab2/05_endurance.txt

echo ""
echo "[5/5] All 5 k6 test scenarios completed! Outputs saved in ./results/lab2/"
echo "=================================================================="
