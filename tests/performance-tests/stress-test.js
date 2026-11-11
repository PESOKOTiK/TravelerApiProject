import { executeUserJourney } from './workflow.js';

const isQuick = __ENV.QUICK_MODE === '1';

export const options = {
    stages: isQuick ? [
        { duration: '8s',  target: 100 },
        { duration: '8s',  target: 200 },
        { duration: '8s',  target: 400 },
        { duration: '8s',  target: 600 }, // Критичне навантаження
        { duration: '10s', target: 0 },   // Відновлення
    ] : [
        { duration: '2m',  target: 100 },
        { duration: '2m',  target: 200 },
        { duration: '2m',  target: 400 },
        { duration: '2m',  target: 600 }, // Критичне навантаження
        { duration: '10m', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.05'],
    },
};

export default function () {
    executeUserJourney();
}
