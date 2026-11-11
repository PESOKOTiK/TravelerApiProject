import { executeUserJourney } from './workflow.js';

export const options = {
    vus: 5,
    duration: __ENV.QUICK_MODE ? '10s' : '30s',
    thresholds: {
        http_req_duration: ['p(95)<200'],
        http_req_failed: ['rate<0.01'],
    },
};

export default function () {
    executeUserJourney();
}
