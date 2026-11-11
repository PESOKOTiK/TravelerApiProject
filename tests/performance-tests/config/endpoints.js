export const BASE_URL = __ENV.API_URL || 'http://localhost:5000';

export const ENDPOINTS = {
    TRAVEL_PLANS: `${BASE_URL}/api/travel-plans`,
    TRAVEL_PLAN_BY_ID: (id) => `${BASE_URL}/api/travel-plans/${id}`,
    LOCATIONS_FOR_PLAN: (planId) => `${BASE_URL}/api/travel-plans/${planId}/locations`,
    LOCATION_BY_ID: (id) => `${BASE_URL}/api/locations/${id}`,
    HEALTH: `${BASE_URL}/api/health`,
};
