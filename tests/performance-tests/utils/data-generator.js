const ADJECTIVES = ['Amazing', 'Sunny', 'Historic', 'Epic', 'Relaxing', 'Cultural', 'Alpine', 'Nordic'];
const CITIES = ['Paris', 'Rome', 'Madrid', 'Berlin', 'Warsaw', 'Kyiv', 'Oslo', 'Vienna', 'Prague', 'Lisbon'];
const CURRENCIES = ['EUR', 'USD', 'PLN', 'UAH'];

function randomItem(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

export function generateTravelPlan(version = 1) {
    const adjective = randomItem(ADJECTIVES);
    const city = randomItem(CITIES);
    const duration = randomInt(3, 14);
    return {
        title: `${adjective} ${city} Trip`,
        description: `A ${duration}-day adventure in ${city}`,
        start_date: '2026-07-01',
        end_date: '2026-07-15',
        budget: randomInt(500, 5000),
        currency: randomItem(CURRENCIES),
        is_public: true,
        version: version
    };
}

export function generateLocation(version = 1) {
    const city = randomItem(CITIES);
    return {
        name: `${city} Central Landmark`,
        address: `${randomInt(1, 200)} Main Street, ${city}`,
        latitude: Number((Math.random() * 80 - 40).toFixed(6)),
        longitude: Number((Math.random() * 160 - 80).toFixed(6)),
        arrival_date: '2026-07-02T10:00:00Z',
        departure_date: '2026-07-03T18:00:00Z',
        budget: randomInt(50, 500),
        notes: 'Check museum opening hours and book tickets',
        version: version
    };
}
