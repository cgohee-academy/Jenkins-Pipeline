# Splunk Dashboards — Documentation

This folder contains exported Splunk dashboard JSON files. Each dashboard is documented below with purpose, key panels, and detailed panel reference.

---

## K8s Dashboard by Events

**Filename:** `K8s Dashboard by Events_2025-09-25.json`  

**Title:** *K8s Dashboard by Events*  

**Purpose:**  
Provides visibility into Kubernetes events, helping identify issues by severity, namespace, container, and pod-level activity. Useful for tracking errors, warnings, and overall cluster event trends.


### Key Panels:

- Total Events
- Events by Severity
- Events Over Time
- Events by Namespace
- Top Event Reasons
- Top Pods with Most Events
- Pods with Failures
- Events by Container
- Top Error Reasons
- Recent Warning Events

---

## Detailed Panel Reference


### Cluster Overview

### **Total Events**
- **Visualization Type:** Single Value
- **Purpose:** Displays the total number of Kubernetes events in the selected time range.
- **SPL:** `index="k8s_logs" sourcetype="kube:events"
| stats count as total_events`

### **Events Over Time**
- **Visualization Type:** Line Chart
- **Purpose:** Shows event volume trends over time, segmented by severity.
- **SPL:** `index="k8s_logs" sourcetype="kube:events"
| timechart span=5m count by otel.log.severity.text`

### **Events by Severity**
- **Visualization Type:** Pie Chart
- **Purpose:** Breaks down the count of events by severity level (Info, Warning, Error).
- **SPL:** `index="k8s_logs" sourcetype="kube:events"
| stats count by otel.log.severity.text`


### Workload Analysis

### **Events by Namespace**
- **Visualization Type:** Bar Chart
- **Purpose:** Displays the distribution of events per Kubernetes namespace.
- **SPL:** `index="k8s_logs" sourcetype="kube:events" k8s.namespace.name!=""
| stats count by k8s.namespace.name
| sort - count`

### **Events by Container**
- **Visualization Type:** Column Chart
- **Purpose:** Counts the number of events grouped by container name.
- **SPL:** `index="k8s_logs" sourcetype="kube:events"
| stats count by container_name`

### **Top Pods with Most Events**
- **Visualization Type:** Bar Chart
- **Purpose:** Highlights the pods generating the highest number of events.
- **SPL:** `index="k8s_logs" sourcetype="kube:events"
| top limit=10 k8s.pod.name`


### Error Triage

### **Top Event Reasons**
- **Visualization Type:** Bar Chart
- **Purpose:** Shows the most common event reasons across the cluster.
- **SPL:** `index="k8s_logs" sourcetype="kube:events"
| stats count by k8s.event.reason
| sort - count`

### **Top Error Reasons**
- **Visualization Type:** Bar Chart
- **Purpose:** Identifies the most frequent Warning-level event reasons.
- **SPL:** `index="k8s_logs" sourcetype="kube:events" otel.log.severity.text="Warning"
| stats count by k8s.event.reason
| sort - count`

### **Pods with Failures**
- **Visualization Type:** Table
- **Purpose:** Lists pods with Warning or Error events along with the reasons.
- **SPL:** `index="k8s_logs" sourcetype="kube:events" (otel.log.severity.text="Warning" OR otel.log.severity.text="Error")
| stats count by k8s.pod.name, k8s.event.reason`

### **Recent Warning Events**
- **Visualization Type:** Table
- **Purpose:** Shows the most recent Warning events with namespace, pod, and reason details.
- **SPL:** `index="k8s_logs" sourcetype="kube:events" otel.log.severity.text="Warning"
| table _time k8s.namespace.name k8s.pod.name k8s.event.reason
| sort - _time`

---

## Error Rate and User Agents Over Time

**Filename:** `Error Rate and User Agents Over Time_2025-09-25.json`  

**Title:** *Error Rate and User Agents Over Time*  

**Purpose:**  
Monitors application-level metrics for request errors, performance trends, and user demographics (browsers/clients). Useful for tracking availability, debugging issues, and understanding traffic sources.


### Key Panels:

- Error Rate Over Time
- Current Error Rate
- Log Level Distribution
- Unique Users Over Time
- Top Endpoints by Traffic
- Errors by Status Code
- Users by User Agent (Browser/Client)
- Request Volume Trend
- Success vs Error Breakdown
- Response Time Trend

---

## Detailed Panel Reference


### Error Monitoring

### **Error Rate Over Time**
- **Visualization Type:** Line Chart
- **Purpose:** Tracks the percentage of failed requests (status >= 400) over time.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| timechart span=15m count as total_requests, count(eval(status_code >= 400)) as error_count
| eval error_rate=round(error_count/total_requests * 100, 2)
| fields _time, error_rate`

### **Current Error Rate**
- **Visualization Type:** Radial Gauge
- **Purpose:** Displays the latest calculated error rate percentage.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| bin _time span=15m
| stats count as total_requests, count(eval(status_code >= 400)) as error_count by _time
| eval error_rate = round(error_count / total_requests * 100, 2)
| tail 1
| table error_rate`

### **Errors by Status Code**
- **Visualization Type:** Pie Chart
- **Purpose:** Shows the distribution of errors grouped by HTTP status code.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp" status_code!=200
| eval is_error = if(status_code >= 400, 1, 0)
| eventstats count as total_requests, sum(is_error) as error_count
| where error_count > 0 AND status_code >= 400
| stats count by status_code
| sort -count`

### **Success vs Error Breakdown**
- **Visualization Type:** Column Chart
- **Purpose:** Compares successful vs failed requests.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| eval outcome = if(status_code < 400, "Success", "Error")
| timechart span=15m count by outcome`


### User Behavior

### **Unique Users Over Time**
- **Visualization Type:** Line Chart
- **Purpose:** Tracks unique users identified by user-agent across time windows.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| timechart span=15m dc(user_agent) as unique_users`

### **Users by User Agent (Browser/Client)**
- **Visualization Type:** Bar Chart
- **Purpose:** Identifies unique users segmented by browser/client type.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| eval browser = case(
    like(user_agent, "%Chrome%"), "Chrome",
    like(user_agent, "%Firefox%"), "Firefox",
    like(user_agent, "%Safari%"), "Safari",
    like(user_agent, "%Edge%"), "Edge",
    like(user_agent, "%MSIE%") OR like(user_agent, "%Trident%"), "Internet Explorer",
    true(), "Other")
| stats dc(user_agent) as unique_users by browser
| sort -unique_users`

### **Top Endpoints by Traffic**
- **Visualization Type:** Bar Chart
- **Purpose:** Ranks the most accessed endpoints by request count.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| stats count as request_count by url
| sort -request_count
| head 10`

### **Request Volume Trend**
- **Visualization Type:** Line Chart
- **Purpose:** Monitors traffic trends over time, split by event type.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp" event_type!="NULL"
| timechart span=15m count by event_type`


### System Logs & Performance

### **Log Level Distribution**
- **Visualization Type:** Pie Chart
- **Purpose:** Breaks down logs by severity level (INFO, WARN, ERROR, etc.).
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| stats count by level`

### **Response Time Trend**
- **Visualization Type:** Line Chart
- **Purpose:** Displays average and 95th percentile response times.
- **SPL:** `index="k8s_logs" sourcetype="kube:container:todoapp"
| timechart span=15m avg(duration_seconds) as avg_response p95(duration_seconds) as p95_response`


---

# How to Import These Dashboards into Splunk

1. In Splunk, go to **Dashboards → Create New Dashboard**.  

2. Choose **Import**, then upload the JSON file (or paste the JSON content).  

3. Save the dashboard with your preferred title and permissions.  

4. Adjust the time range input or search indexes if your environment differs.  
