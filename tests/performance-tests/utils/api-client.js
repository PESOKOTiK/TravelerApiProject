import http from 'k6/http';
import { check } from 'k6';
import { ENDPOINTS } from '../config/endpoints.js';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function makeRequest(method, url, body = null, tag = 'api') {
    const params = {
        headers: { 'Content-Type': 'application/json' },
        tags: { name: tag }
    };
    const payload = body ? JSON.stringify(body) : null;
    return http.request(method, url, payload, params);
}

export function checkHealth() {
    const res = http.get(ENDPOINTS.HEALTH, { tags: { name: 'health' } });
    check(res, {
        'health check status is 200': (r) => r.status === 200,
    });
    return res;
}

export function createTravelPlan(planData) {
    const response = makeRequest('POST', ENDPOINTS.TRAVEL_PLANS, planData, 'create_plan');
    check(response, {
        'plan created successfully (201)': (r) => r.status === 201,
        'plan has valid UUID': (r) => {
            if (r.status !== 201) return false;
            const body = r.json();
            return UUID_REGEX.test(body.id);
        },
        'plan initial version is 1': (r) => r.status === 201 && r.json().version === 1,
    });
    return response.status === 201 ? response.json() : null;
}

export function getTravelPlan(planId) {
    const response = makeRequest('GET', ENDPOINTS.TRAVEL_PLAN_BY_ID(planId), null, 'get_plan');
    check(response, {
        'plan fetched successfully (200)': (r) => r.status === 200,
    });
    return response.status === 200 ? response.json() : null;
}

export function updateTravelPlan(planId, planData, currentVersion) {
    const payload = Object.assign({}, planData, { version: currentVersion });
    const response = makeRequest('PUT', ENDPOINTS.TRAVEL_PLAN_BY_ID(planId), payload, 'update_plan');
    check(response, {
        'plan updated (200) or optimistic lock conflict (409)': (r) => r.status === 200 || r.status === 409,
        'plan version incremented on 200': (r) => r.status !== 200 || r.json().version === currentVersion + 1,
    });
    return response.status === 200 ? response.json() : null;
}

export function addLocation(planId, locationData) {
    const response = makeRequest('POST', ENDPOINTS.LOCATIONS_FOR_PLAN(planId), locationData, 'add_location');
    check(response, {
        'location added successfully (201)': (r) => r.status === 201,
        'location has visit_order >= 1': (r) => r.status === 201 && r.json().visit_order >= 1,
        'location initial version is 1': (r) => r.status === 201 && r.json().version === 1,
    });
    return response.status === 201 ? response.json() : null;
}

export function updateLocation(locationId, locationData, currentVersion) {
    // Lab 1 / Lab 2 Task 1.3: Optimistic locking version included in location update payload
    const payload = Object.assign({}, locationData, { version: currentVersion });
    const response = makeRequest('PUT', ENDPOINTS.LOCATION_BY_ID(locationId), payload, 'update_location');
    check(response, {
        'location updated (200) or optimistic lock conflict (409)': (r) => r.status === 200 || r.status === 409,
        'location version incremented on 200': (r) => r.status !== 200 || r.json().version === currentVersion + 1,
    });
    return response.status === 200 ? response.json() : null;
}

export function deleteTravelPlan(planId) {
    const response = makeRequest('DELETE', ENDPOINTS.TRAVEL_PLAN_BY_ID(planId), null, 'delete_plan');
    check(response, {
        'plan deleted successfully (204)': (r) => r.status === 204,
    });
    return response;
}
