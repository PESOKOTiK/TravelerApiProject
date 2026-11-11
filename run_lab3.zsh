#!/usr/bin/env zsh
set -eu

echo "=================================================================="
echo "  TravelerAPI - Lab 3: Dockerization & Performance Comparison"
echo "=================================================================="
echo "Mode: QUICK_MODE=${QUICK_MODE:-1} (Set QUICK_MODE=0 for full 83-min k6 runs)"
export QUICK_MODE=${QUICK_MODE:-1}
export API_URL="http://localhost:5000"

# 0. Stop native PostgreSQL service & any local dotnet process on port 5000
echo "[1/6] Stopping host postgresql.service and freeing ports 5000/5432..."
if systemctl is-active --quiet postgresql; then
  sudo systemctl stop postgresql || true
fi
fuser -k 5000/tcp >/dev/null 2>&1 || true

# Ensure .env exists from .env.example
if [ ! -f .env ]; then
  cp .env.example .env
fi

mkdir -p ./results/lab3

# 1. Build and start full Docker Compose stack
echo "[2/6] Building and starting Docker Compose stack (postgres + web)..."
docker compose down -v >/dev/null 2>&1 || true
docker compose up -d --build

echo "[3/6] Waiting for containers to pass healthchecks..."
for i in {1..45}; do
  if curl -s -f "http://localhost:5000/api/health" >/dev/null 2>&1; then
    echo "Containerized TravelerAPI is online and healthy!"
    break
  fi
  sleep 1
done

# Apply schema explicitly to guarantee fresh tables
docker exec -i travel_planner_db psql -U postgres -d traveler_db < ./db/schema.sql >/dev/null

# 2. Stage 3 Monitoring Outputs (for Lab 3 Report Section 2)
echo ""
echo "=================================================================="
echo "  STAGE 3 MONITORING SNAPSHOT (Screenshot this for Report!)"
echo "=================================================================="
echo ">>> 1. docker compose ps"
docker compose ps | tee ./results/lab3/stage3_docker_ps.txt

echo ""
echo ">>> 2. docker compose logs --tail=20 web"
docker compose logs --tail=20 web | tee ./results/lab3/stage3_docker_logs.txt

echo ""
echo ">>> 3. docker stats --no-stream (Idle Baseline)"
docker stats --no-stream | tee ./results/lab3/stage3_docker_stats_idle.txt

# 3. Run Hurl Functional & Concurrency Tests (Lab 1 verification on Docker stack)
echo ""
echo "=================================================================="
echo "  [4/6] Running Lab 1 Hurl Tests against Dockerized Stack"
echo "=================================================================="
hurl --test ./tests/*.hurl --variables-file ./tests/variables.properties | tee ./results/lab3/hurl_docker_results.txt

# 4. Background sampler for `docker stats` during k6 load
(
  while true; do
    docker stats --no-stream >> ./results/lab3/docker_stats_under_load.log 2>/dev/null || true
    sleep 3
  done
) &
STATS_PID=$!

cleanup() {
  kill $STATS_PID 2>/dev/null || true
}
trap cleanup EXIT

# 5. Run k6 Performance Suite against Dockerized Stack
echo ""
echo "=================================================================="
echo "  [5/6] Running k6 Performance Tests against Docker Containers"
echo "=================================================================="

echo "--- 1. Smoke Test (Docker) ---"
k6 run ./tests/performance-tests/smoke-test.js --summary-export=./results/lab3/01_smoke_summary.json | tee ./results/lab3/01_smoke.txt

echo "--- 2. Load Test (Docker) ---"
k6 run ./tests/performance-tests/load-test.js --summary-export=./results/lab3/02_load_summary.json | tee ./results/lab3/02_load.txt

echo "--- 3. Stress Test (Docker) ---"
k6 run ./tests/performance-tests/stress-test.js --summary-export=./results/lab3/03_stress_summary.json | tee ./results/lab3/03_stress.txt

echo "--- 4. Spike Test (Docker) ---"
k6 run ./tests/performance-tests/spike-test.js --summary-export=./results/lab3/04_spike_summary.json | tee ./results/lab3/04_spike.txt

echo "--- 5. Endurance Test (Docker) ---"
k6 run ./tests/performance-tests/endurance-test.js --summary-export=./results/lab3/05_endurance_summary.json | tee ./results/lab3/05_endurance.txt

echo ""
echo ">>> Peak Container Resource Usage (docker stats under load):"
tail -n 6 ./results/lab3/docker_stats_under_load.log | tee ./results/lab3/stage3_docker_stats_peak.txt

echo ""
echo "[6/6] Lab 3 Docker verification & k6 benchmarks finished! Saved in ./results/lab3/"
echo "=================================================================="
