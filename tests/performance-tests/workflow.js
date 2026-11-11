import { sleep } from 'k6';
import { generateTravelPlan, generateLocation } from './utils/data-generator.js';
import {
    checkHealth,
    createTravelPlan,
    getTravelPlan,
    updateTravelPlan,
    addLocation,
    updateLocation,
    deleteTravelPlan
} from './utils/api-client.js';

export function executeUserJourney() {
    checkHealth();

    const plan = createTravelPlan(generateTravelPlan(1));
    if (!plan) return;

    const loc1 = addLocation(plan.id, generateLocation(1));
    const loc2 = addLocation(plan.id, generateLocation(1));

    if (loc1) {
        const updatedLocData = generateLocation(loc1.version);
        updatedLocData.budget = 250;
        updatedLocData.notes = 'Updated via k6 with optimistic locking version';
        updateLocation(loc1.id, updatedLocData, loc1.version);
    }

    const fetched = getTravelPlan(plan.id);
    if (fetched) {
        const updatedPlanData = generateTravelPlan(fetched.version);
        updatedPlanData.budget = 3200;
        updateTravelPlan(plan.id, updatedPlanData, fetched.version);
    }

    deleteTravelPlan(plan.id);
    sleep(0.5);
}
