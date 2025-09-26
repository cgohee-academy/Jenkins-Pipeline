# Grafana Dashboards — Documentation

This folder contains exported Grafana dashboard JSON files. Each dashboard is documented below with purpose, key panels, and import instructions.

---

## 1. Kubernetes Cluster Dashboard

**Filename:** `Kubernetes Cluster Dashboard.json`  
**UID:** `3dd6a06d-a7ef-4305-a902-5fc38f26b7df`

**Purpose:**  
Provides cluster-level infrastructure and pod metrics (CPU, memory, pod usage, disk, etc.). Useful for monitoring cluster health and capacity.

### Key Panels (top panels in this dashboard):
- Cluster Health
- Cluster Pod Usage
- Cluster CPU Usage
- Cluster Memory Usage
- Cluster Disk Usage
- Cluster Pod Capacity
- Cluster Memory Capacity (GB)
- Cluster CPU Capacity
- Cluster Disk Capacity (bytes)
- Deployments
- Deployment Replicas - Up To Date
- Deployment Replicas

---

## 2. Jenkins: Performance and Health Dashboard

**Filename:** `Jenkins_ Performance and Health Dashboard.json`  
**UID:** `1d671434-4033-44a3-a5a1-6d63d9edd177`

**Purpose:**  
Shows Jenkins CI performance and health metrics (job counts, durations, successes/failures, node status). Useful for monitoring CI system reliability and throughput.

### Key Panels (top panels in this dashboard):
- Job/Project Created
- Job/Project Duration
- Total Jobs
- CPU Usage
- Jenkins Health
- Memory Usage
- Unstable Jobs
- JVM Uptime
- Jenkins nodes offline
- Failed Jobs
- Successful Jobs
- Aborted Jobs

---

## 3. Todo List Web App Dashboard

**Filename:** `Todo List Web App Dashboard.json`  
**UID:** `c0962e9e-43bd-4b62-9b88-a89dd2fe7a35`

**Purpose:**  
Shows application-level metrics for the TodoApp: request rate, availability, error rates, and latency.

### Key Panels (top panels in this dashboard):
- Total Request
- Availability
- Request Rate by Status
- Error Rate
- Latency (95th Percentile)
- Latency Histogram

# How to import this dashboard into Grafana
1. In Grafana, go to **Dashboards → Manage → Import**.
2. Upload the JSON file or paste its contents.
3. If prompted, choose a Prometheus datasource matching the `prometheus` datasource used in the JSON.
4. Adjust UID or folder if you want a separate copy; don’t overwrite an existing dashboard unless intended.


