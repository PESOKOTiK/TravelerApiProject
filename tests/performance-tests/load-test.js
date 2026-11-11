import { executeUserJourney } from './workflow.js';

const isQuick = __ENV.QUICK_MODE === '1';

export const options = {
    stages: isQuick ? [
        { duration: '10s', target: 100 }, // Ramp-up to 100 VUs
        { duration: '20s', target: 100 }, // Steady state at 100 VUs
        { duration: '5s',  target: 0 },   // Ramp-down
    ] : [
        { duration: '5m',  target: 100 }, // Наростання до 100 користувачів
        { duration: '10m', target: 100 }, // Утримання навантаження
        { duration: '5m',  target: 0 },   // Зниження
    ],
    thresholds: {
        http_req_duration: ['p(95)<200'],
        http_req_failed: ['rate<0.01'],
    },
};

export default function () {
    executeUserJourney();
}
