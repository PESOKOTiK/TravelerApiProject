import { executeUserJourney } from './workflow.js';

const isQuick = __ENV.QUICK_MODE === '1';

export const options = {
    stages: isQuick ? [
        { duration: '8s',  target: 100 },  // Нормальний рівень
        { duration: '10s', target: 800 },  // Швидкий сплеск
        { duration: '8s',  target: 0 },    // Швидке зниження
    ] : [
        { duration: '2m', target: 100 },  // Нормальний рівень
        { duration: '2m', target: 2000 }, // Швидкий сплеск
        { duration: '1m', target: 0 },    // Швидке зниження
    ],
    thresholds: {
        http_req_failed: ['rate<0.10'],
    },
};

export default function () {
    executeUserJourney();
}
