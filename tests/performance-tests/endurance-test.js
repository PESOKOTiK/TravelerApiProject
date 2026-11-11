import { executeUserJourney } from './workflow.js';

const isQuick = __ENV.QUICK_MODE === '1';

export const options = {
    stages: isQuick ? [
        { duration: '5s',  target: 100 }, // Наростання
        { duration: '30s', target: 100 }, // Тривале навантаження (прискорений режим)
        { duration: '5s',  target: 0 },   // Зниження
    ] : [
        { duration: '5m',  target: 100 }, // Наростання
        { duration: '30m', target: 100 }, // Тривале навантаження (30 хвилин згідно з лаб 2)
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
