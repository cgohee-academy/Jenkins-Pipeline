# TechWorms Observability: Monitoring & Logging Case Study
---
#  Documentations
- See the [K8s Documentation](k8s/README.md) for more details
- See the [Jenkins Documentation](Tools-Documentation/Jenkins/README.md) for more details
- See the [Prometheus & Grafana Documentation](Tools-Documentation/Prometheus-Grafana/README.md) for more details
- See the [Splunk Documentation](Tools-Documentation/Splunk/README.md) for more details
- See the [PagerDuty Documentation](PagerDuty/README.md) for more details
- See the [Grafana-Dashboard Documentation](Grafana-Dashboard/README.md) for more details
- See the [Splunk-Dashboard Documentation](Splunk-Dashboard/README.md) for more details

# Ops Simulation Runbook
- See the [Runbook Documentation](Runbook/README.md) for more details

# Todo WebApp (Flask)

This project is a **Flask-based Todo WebApp** with integrated **SQLAlchemy ORM**, **Prometheus metrics**, and **structured logging** for observability.  
It supports both **SQLite** and **MySQL** backends, and provides simulation endpoints for testing failures.

---

## 🚀 Features

- RESTful API for managing todos (CRUD)
- Database support (SQLite / MySQL via SQLAlchemy)
- Health check endpoint (`/health`)
- Prometheus metrics endpoint (`/metrics`)
- Structured logging for:
  - Requests (method, endpoint, latency, status code)
  - Business events (todo creation, update, deletion)
  - Database operations (INSERT, UPDATE, DELETE)
  - Error logging (database errors, 4xx/5xx)
- Simulation endpoints to test errors and latency

---

## ⚙️ Setup

### 1. Clone repository & install dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure environment variables
Create a `.env` file:
```env
DATABASE_TYPE=sqlite    # or mysql
DATABASE_URL=           # optional, overrides DATABASE_TYPE
SQLITE_FILE=todos.db    # only if sqlite
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=todoapp
MYSQL_PASSWORD=todoapp123
MYSQL_DATABASE=todoapp
FLASK_ENV=development
PORT=5000
```

### 3. Run the app
```bash
python app.py
```
App runs on `http://localhost:5000`

---

## 📡 API Endpoints

### Todos
- `GET /api/todos` → List all todos  
- `POST /api/todos` → Create a new todo  
- `PUT /api/todos/<id>` → Update a todo  
- `DELETE /api/todos/<id>` → Delete a todo  

### Health & Metrics
- `GET /health` → Returns application + DB health  
- `GET /metrics` → Prometheus metrics in text format  

### Simulation (for testing observability)
- `/simulate/404` → Simulated 404 error  
- `/simulate/500` → Simulated 500 error  
- `/simulate/timeout` → Simulated slow response (5s)  
- `/simulate/database-error` → Simulated DB failure  
- `/simulate/auth-error` → Simulated authentication error (401)  
- `/simulate/add-todo-error` → Simulated DB error on create  
- `/simulate/update-todo-error` → Simulated DB error on update  
- `/simulate/delete-todo-error` → Simulated DB error on delete  

---

## 📊 Observability

### 🔹 Prometheus Metrics
- **Counter**: `todoapp_requests_total`  
  Tracks request count by method and endpoint.  

- **Histogram**: `todoapp_request_duration_seconds`  
  Observes request latency distribution.  

### 🔹 Structured Logging
- **Request logs** → Every request is logged with method, endpoint, latency, and status code.  
- **Business events** → Logged for todo creation, update, delete, and simulations.  
- **Database operations** → Insert, Update, Delete success/fail states.  
- **Errors** → Logged with context for debugging and forwarded to Splunk/log aggregator.  

Logs are in **JSON structured format** for Kubernetes/Splunk compatibility.

---

## ✅ Health Monitoring

- `/health` checks database connectivity (`SELECT 1`)  
- Returns JSON with service status, DB status, timestamp, and version  

---

## 🔎 Example Log Output

```json
{
  "timestamp": "2025-09-24T12:34:56Z",
  "level": "INFO",
  "event": "todo_created",
  "todo_id": 1,
  "title": "Buy groceries",
  "completed": false
}
```

---

## 📌 Notes
- Use **Flask-Migrate** for DB schema management in production.  
- For metrics, point **Prometheus** to scrape `/metrics`.  
- For logs, configure **Splunk forwarder** or another aggregator to collect logs.

---

# How to access Prometheus, Grafana, Alertmanager, Jenkins, Todo List Web App & Splunk

```bash
# Commands to access
kubectl port-forward -n monitoring svc/grafana 3000:80
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
kubectl port-forward -n splunk-operator svc/splunk-stdln-standalone-service 8000:8000

# Access all three:
# http://localhost:3000 (Grafana)
# http://localhost:9090 (Prometheus)  
# http://localhost:9093 (AlertManager)
# [http://localhost:](http://localhost:9093)8000 (Splunk)

# Stop all background processes
killall kubectl
```

# 🎯 Access Guide: Prometheus, Grafana, Alertmanager & Splunk

This guide explains how to access your monitoring stack components using the **port-forward method** - the most reliable and secure approach for admin tools.

---

## 🎭 Why Port-Forward Instead of NodePort?

**Port-forward creates a secure tunnel:**

```
Your Browser → [localhost](http://localhost):port → kubectl → K8s API → Pod
```

**Advantages:**

- ✅ **No firewall issues** (uses kubectl authentication)
- ✅ **More secure** (no external exposure to internet)
- ✅ **Always works** (bypasses network policies)
- ✅ **Encrypted tunnel** through Kubernetes API
- ✅ **No NodePort management** needed

**When to use NodePort instead:**

- Multiple users need simultaneous access
- External applications/CI-CD need to connect
- Permanent external access required

---

## 🎨 Grafana Dashboard Access

### Step 1: Start Port-Forward

```bash
# Forward Grafana to your local machine
kubectl port-forward -n monitoring svc/grafana 3000:80
```

### Step 2: Access Dashboard

- **URL**: http://localhost:3000
- **Username**: `admin`
- **Password**: `Gr@fana`

### Step 3: Explore Pre-configured Dashboards

Once logged in, you'll find these dashboards ready to use:

- **Kubernetes Cluster Overview** - Overall cluster health
- **Node Exporter Metrics** - Server hardware metrics
- **Kubernetes Pods** - Pod performance and status
- **Jenkins Performance** - Jenkins-specific monitoring

### Alternative Local Port (if 3000 is busy)

```bash
# Use port 3001 locally instead
kubectl port-forward -n monitoring svc/grafana 3000:80
kubectl port-forward -n monitoring svc/grafana 3000:80 -v=8
# Access: http://localhost:3001
```

---

## 📊 Prometheus Metrics & Queries

### Step 1: Start Port-Forward

```bash
# Forward Prometheus to your local machine
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 -v=8
```

### Step 2: Access Prometheus UI

- **URL**: http://localhost:9090
- **No authentication required**

### Step 3: Useful Prometheus Queries

### Basic System Queries

```
# Check which services are up
up

# CPU usage by node
rate(node_cpu_seconds_total[5m])

# Available memory
node_memory_MemAvailable_bytes

# Disk usage
node_filesystem_avail_bytes
```

### Kubernetes-Specific Queries

```
# Pod status across cluster
kube_pod_status_phase

# Container memory usage
container_memory_usage_bytes

# Deployment replica status
kube_deployment_status_replicas

# Node conditions
kube_node_status_condition
```

### Jenkins Monitoring Queries

```
# Jenkins health score
jenkins_health_check_score

# Total number of builds
jenkins_builds_total

# Build queue size
jenkins_queue_size_value

# Build duration
jenkins_builds_duration_milliseconds_summary
```

### Step 4: Check Monitoring Targets

1. Go to **Status → Targets**
2. Verify all services show as "UP"
3. Look for:
    - Kubernetes API Server
    - Node Exporter
    - Jenkins
    - Kube State Metrics

---

## Jenkins

**URL**: http://139.144.127.16

---

## Todo List Web App

**URL**: http://139.144.127.15

---
## 📊 Splunk

### Step 1: Start Port-Forward

```bash
# Forward splunk to your local machine
kubectl port-forward -n splunk-operator svc/splunk-stdln-standalone-service 8000:8000
```

---

### Step 2: Access Dashboard

- **URL**: [http://localhost:](http://localhost:3000)8000
- **Username:** `admin`
- **Password:** `T3chw0rms!`

## 🚨 AlertManager (Optional)

### Step 1: Start Port-Forward

```bash
# Forward AlertManager to your local machine
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

### Step 2: Access AlertManager UI

- **URL**: http://localhost:9093
- **No authentication required**

### Step 3: What You Can Do

- View active alerts
- Check alert rules
- Configure notification channels
- Silence alerts temporarily

---

## 🚀 Advanced Access Methods

### Multiple Port-Forwards Simultaneously

```bash
# Run in background with &
kubectl port-forward -n monitoring svc/grafana 80:80 &
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093 &
kubectl port-forward -n splunk-operator svc/splunk-stdln-standalone-service 8000:8000 &

# Access all three:
# http://localhost:3000 (Grafana)
# http://localhost:9090 (Prometheus)  
# http://localhost:9093 (AlertManager)
# [http://localhost:](http://localhost:9093)8000 (Splunk)

# Stop all background processes
killall kubectl
```

```bash
# Powershell
Start-Job -ScriptBlock { kubectl port-forward -n monitoring svc/grafana 80:80 }
Start-Job -ScriptBlock { kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 }
Start-Job -ScriptBlock { kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093 }
Start-Job -ScriptBlock { kubectl port-forward -n splunk-operator svc/splunk-stdln-standalone-service 8000:8000 }

# Kill all
Get-Job | Stop-Job
```

### Access from Other Machines on Your Network

```bash
# Bind to all interfaces (0.0.0.0)
kubectl port-forward --address 0.0.0.0 -n monitoring svc/grafana 3000:3000

# Then access from other machines:
# http://YOUR_PC_IP:3000
```

---

## 🔧 Troubleshooting

### Port-Forward Fails

```bash
# Check if services exist
kubectl get svc -n monitoring

# Check if pods are running
kubectl get pods -n monitoring

# Check pod logs if issues
kubectl logs -n monitoring -l [app.kubernetes.io/name=grafana](http://app.kubernetes.io/name=grafana)
kubectl logs -n monitoring -l [app.kubernetes.io/name=prometheus](http://app.kubernetes.io/name=prometheus)
```

### Can't Access [Localhost](http://Localhost) URLs

1. **Check port-forward is running**: Look for kubectl process
2. **Try different port**: Use `3001` instead of `3000`
3. **Check firewall**: Ensure [localhost](http://localhost) connections allowed
4. **Browser cache**: Try incognito/private mode

### Service Not Responding

```bash
# Test internal service connectivity
kubectl exec -n monitoring deployment/grafana -- curl -I http://localhost:3000
kubectl exec -n monitoring $(kubectl get pod -n monitoring -l [app.kubernetes.io/name=prometheus](http://app.kubernetes.io/name=prometheus) -o name) -- wget -q -O- http://localhost:9090/api/v1/status/buildinfo
```

### Reset Grafana Admin Password

```bash
# If you forgot the password
kubectl exec -n monitoring deployment/grafana -- grafana-cli admin reset-admin-password newpassword123
```

---

## 📚 Quick Reference Commands

### Status Check Commands

```bash
# Check all monitoring services
kubectl get svc -n monitoring

# Check all monitoring pods
kubectl get pods -n monitoring

# Check storage usage
kubectl get pvc -n monitoring

# Check endpoints
kubectl get endpoints -n monitoring
```

### Service Information

```bash
# Get detailed service info
kubectl describe svc grafana -n monitoring
kubectl describe svc prometheus-kube-prometheus-prometheus -n monitoring

# Check service selectors match pods
kubectl get pods -n monitoring --show-labels
```

---

## 💡 Pro Tips

- **Keep port-forward running**: Open in a dedicated terminal
- **Use screen/tmux**: For persistent sessions
- **Bookmark [localhost](http://localhost) URLs**: Quick access to dashboards
- **Learn PromQL**: Essential for custom Prometheus queries
- **Explore Grafana**: Create custom dashboards for your apps
- **Set up alerts**: Use AlertManager for proactive monitoring

---

## 🔐 Security Notes

✅ **Port-forward is secure because:**

- Uses your kubectl authentication
- Creates encrypted tunnel through K8s API
- No external network exposure
- Automatically closes when kubectl stops

⚠️ **Never expose monitoring tools directly to internet:**

- Contains sensitive cluster information
- No built-in authentication for Prometheus
- Use VPN or bastion hosts for remote access

# Developers
- Rigel Kent Canonigo
- Perry Bernal
- Joseph Roda Lacao-Lacao
- Cherish Gohee
