import http from 'k6/http'
import { check, sleep } from 'k6'
import { Rate } from 'k6/metrics'

// Custom metrics
const errorRate = new Rate('errors')
const successRate = new Rate('success')

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 50 }, // Ramp up to 50 users
    { duration: '5m', target: 50 }, // Stay at 50 users
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 0 } // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.1'], // Error rate must be below 10%
    errors: ['rate<0.05'] // Custom error rate below 5%
  }
}

const BASE_URL = 'http://app.local'

export default function () {
  // Test different endpoints with weights
  const endpoints = [
    { url: '/', weight: 0.1 },
    { url: '/api/version', weight: 0.3 },
    { url: '/api/info', weight: 0.3 },
    { url: '/health/ready', weight: 0.2 },
    { url: '/demo/slow?delay=1', weight: 0.1 }
  ]

  // Select endpoint based on weight
  const random = Math.random()
  let accumulator = 0
  let selectedEndpoint

  for (const endpoint of endpoints) {
    accumulator += endpoint.weight
    if (random <= accumulator) {
      selectedEndpoint = endpoint
      break
    }
  }

  // Make request
  const response = http.get(`${BASE_URL}${selectedEndpoint.url}`)

  // Check response
  const success = check(response, {
    'status is 200': r => r.status === 200,
    'response time < 500ms': r => r.timings.duration < 500,
    'response has body': r => r.body.length > 0
  })

  // Record metrics
  errorRate.add(!success)
  successRate.add(success)

  // Think time
  sleep(1)
}

export function handleSummary (data) {
  return {
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
    'load-test-results.json': JSON.stringify(data)
  }
}
