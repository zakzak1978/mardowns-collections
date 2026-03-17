### Install ks
```
wget https://github.com/grafana/k6/releases/download/v0.52.0/k6-v0.52.0-linux-amd64.tar.gz
tar -xzf k6-v0.52.0-linux-amd64.tar.gz
sudo mv k6-v0.52.0-linux-amd64/k6 /usr/local/bin/
k6 version
```

### Steps to Deploy and Run
#### Create loadtest.js:

```javascript
# Contents of loadtest.js file

import http from 'k6/http';
import { check, sleep } from 'k6';

// Simple UUID generator
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  }).replace(/-/g, '');  // Remove dashes for hex string
}

// Config: Adjust for your env
const OTLP_ENDPOINT = 'http://tempo-scaasdev-distributor.tempo-scaasdev.svc.cluster.local:4318';  // Internal Tempo distributor service
const OTLP_PATH = '/v1/traces';
const HEADERS = {
  'Content-Type': 'application/json',
  'User-Agent': 'k6/0.0.0[](https://k6.io/)',
  // Add auth if needed (e.g., 'Authorization': 'Basic xxx')
};

// Generate a simple trace payload (OTEL format)
function generateTrace() {
  const traceId = generateUUID();
  const now = Date.now();
  const timestamp = Math.floor(now / 1000 * 1e9);  // Nanoseconds

  const parentSpanId = generateUUID().slice(0, 16);

  const resourceSpans = [{
    resource: {
      attributes: [{ key: 'service.name', value: { stringValue: `test-service-${__VU}` } }]
    },
    scopeSpans: [{
      scope: { name: 'k6-test', version: '1.0' },
      spans: [
        // Parent span
        {
          traceId,
          spanId: parentSpanId,  // Use the defined parentSpanId
          parentSpanId: '',  // Root
          name: '/user/request',
          kind: 0,  // SPAN_KIND_INTERNAL
          startTimeUnixNano: timestamp,
          endTimeUnixNano: timestamp + 10000000,  // 10ms duration
          status: { code: 0 },  // OK
          attributes: [{ key: 'http.method', value: { stringValue: 'GET' } }]
        },
        // Child span 1: DB query
        {
          traceId,
          spanId: generateUUID().slice(0, 16),
          parentSpanId: parentSpanId,  // Link to parent
          name: 'db.query',
          kind: 3,  // SPAN_KIND_CLIENT
          startTimeUnixNano: timestamp + 1000000,
          endTimeUnixNano: timestamp + 5000000,
          status: { code: 0 },
          attributes: [{ key: 'db.statement', value: { stringValue: 'SELECT * FROM users' } }]
        },
        // Child span 2: API call
        {
          traceId,
          spanId: generateUUID().slice(0, 16),
          parentSpanId: parentSpanId,
          name: 'api.call',
          kind: 3,
          startTimeUnixNano: timestamp + 6000000,
          endTimeUnixNano: timestamp + 9000000,
          status: { code: 0 },
          attributes: [{ key: 'http.url', value: { stringValue: 'https://api.example.com' } }]
        }
      ]
    }]
  }];

  return JSON.stringify({ resourceSpans });
}

// Define the test configuration
export const options = {
  // Define a scenario for gradual ramp-up to test scaling
  scenarios: {
    ramp_up_load: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '2m', target: 50 },    // Ramp up to 50 VUs over 2 minutes
        { duration: '5m', target: 500 },    // Ramp up to 500 VUs over 5 minutes
        { duration: '3m', target: 1000 },   // Ramp up to 1000 VUs over 3 minutes
        { duration: '5m', target: 1000 },   // Stay at 1000 VUs for 5 minutes
        { duration: '3m', target: 0 },      // Ramp down to 0 VUs over 3 minutes
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'], // Less than 1% of requests should fail
    http_req_duration: ['p(95)<1000'], // 95% of requests should complete within 1s
  },
};

export default function () {
  const payload = generateTrace();
  const params = { headers: HEADERS, timeout: '30s' };

  const res = http.post(OTLP_ENDPOINT + OTLP_PATH, payload, params);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'trace accepted': (r) => !r.json().errors || r.json().errors.length === 0,  // OTLP response check
  });

  sleep(1);  // Throttle to ~1 trace/sec per VU (adjust for load)
}

```

#### Create a config map file using the loadtest.js file
```cmd
#### Run this command from whereever the loadtest.js file is located or adjust the path to loadtest.js file.
kubectl create configmap k6-script --from-file=loadtest.js -n tempo-scaasdev
```

#### Create a job file, configure this job to use the config map file.
To load test Tempo, we have to run this from inside the cluster.  To achieve this, create a job first. Save the YAML above as k6-job.yaml in your Cloud Shell and then apply it.  We are not using locally installed k6, but directly using k6 image from Grafana.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: k6-loadtest
  namespace: tempo-scaasdev  # Match your namespace; adjust if different
spec:
  template:
    spec:
      containers:
      - name: k6
        image: grafana/k6:latest  # Uses latest k6 image; compatible with v0.52.0
        command: ["k6", "run", "/scripts/loadtest.js"]
        volumeMounts:
        - name: script-volume
          mountPath: /scripts
      volumes:
      - name: script-volume
        configMap:
          name: k6-script  # ConfigMap to hold loadtest.js
      restartPolicy: Never
  backoffLimit: 1
```

#### Apply the job file
```
kubectl apply -f ~/k6/k6-job.yaml -n tempo-scaasdev
```

#### Monitor the job and the logs
```
kubectl get jobs -n tempo-scaasdev
kubectl logs -f job/k6-loadtest -n tempo-scaasdev
```
