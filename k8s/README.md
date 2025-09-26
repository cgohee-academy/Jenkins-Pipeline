# 📘 Kubernetes Manifests Documentation

This documentation explains the purpose and configuration of each file inside the `k8s` directory for the **TodoApp** project.

---

## 1. `todoapp-alerts.yaml`

This file defines **Prometheus alerting rules** using the `PrometheusRule` custom resource.

### Key Alerts Defined:
- **TodoApp-LowAvailability** → Triggers if availability drops below 95% in 5 minutes.  
- **TodoApp-HighCPU** → Alerts if CPU usage exceeds 80% for 5 minutes.  
- **TodoApp-HighMemory** → Alerts if memory usage exceeds **500Mi**.  
- **TodoApp-OOM-Killed** → Detects when containers are OOMKilled.  
- **TodoApp-HighError-Rate(5xx/4xx)** → Fires if 5%+ of requests return errors.  
- **TodoApp-WebUI-Down** → Checks if the TodoApp web UI is down.  
- **Database-Down** → Ensures MySQL database is running.  
- **Prometheus-Exporter-Down** → Ensures Prometheus Node Exporter is alive.  
- **Splunk-UI-Down** → Checks if Splunk UI crashed or failed to start.  
- **Splunk-OTEL-Collector-Down** → Ensures Splunk OTEL Collector is running.  

📌 These alerts help maintain **application reliability, performance, and observability**.

---

## 2. `todoapp-deployment.yaml`

This file defines the **Deployment** resource for the TodoApp.

### Configuration:
- **Replicas:** 3 (ensures high availability).  
- **Container:** Runs `todoapp:latest` image.  
- **Ports:** Exposes container port `5000`.  
- **Environment Variables:**
  - `FLASK_ENV` → Set to production.  
  - `DATABASE_URL` → Retrieved from Kubernetes Secret.  
  - `PORT` → Exposed at `5000`.  
- **Health Probes:**
  - **Liveness Probe:** Checks `/health` after 60s, every 300s.  
  - **Readiness Probe:** Checks `/health` after 30s, every 300s.  
- **Resource Requests & Limits:**
  - Requests → 128Mi memory, 100m CPU  
  - Limits → 256Mi memory, 200m CPU  

📌 Ensures the app auto-restarts on failure and only routes traffic to **healthy pods**.

---

## 3. `todoapp-secret.yaml`

This file defines **Kubernetes Secrets** for the TodoApp.

### Configuration:
- **Name:** `todoapp-secrets`  
- **Type:** Opaque (generic secret).  
- **Stored Data:**
  - `database-url` → Encoded MySQL connection string:  
    ```
    mysql+pymysql://todoapp:todoapp123@mysql-service.todo-app:3306/todoapp
    ```

📌 Prevents exposing database credentials in plain text inside deployments.

---

## 4. `todoapp-service.yaml`

This file defines a **Service** to expose the TodoApp deployment.

### Configuration:
- **Type:** NodePort (accessible externally).  
- **Selector:** `app: todoapp` (routes traffic to pods with this label).  
- **Ports:**
  - Service Port → `80`  
  - Target Port → `5000` (application port inside container).  

📌 Provides a stable endpoint (`todoapp-service`) to access the TodoApp.

---

## 5. `todoapp-servicemonitor.yaml`

This file defines a **ServiceMonitor** for Prometheus Operator.

### Configuration:
- **Name:** `todoapp-monitor`  
- **Selector:** Matches `app: todoapp` service.  
- **Endpoints:**
  - Port → `http`  
  - Path → `/metrics`  
  - Interval → Every 30 seconds  
  - Scrape Timeout → 10 seconds  

📌 Ensures Prometheus scrapes **metrics from the TodoApp** for monitoring and alerting.

---

# ✅ Summary

- `todoapp-alerts.yaml` → Defines Prometheus alerting rules.  
- `todoapp-deployment.yaml` → Deploys and manages TodoApp pods.  
- `todoapp-secret.yaml` → Stores sensitive DB credentials.  
- `todoapp-service.yaml` → Exposes TodoApp to the cluster/external users.  
- `todoapp-servicemonitor.yaml` → Enables Prometheus monitoring of the app.  

Together, these manifests provide **deployment, security, monitoring, and observability** for the TodoApp in Kubernetes.

# MySQL Kubernetes Manifests

This directory contains the Kubernetes manifests for deploying a **MySQL database** to be used by the `todoapp`. Each YAML file defines a different resource needed for database configuration, storage, and connectivity.

---

## 1. mysql-secret.yaml

**Kind:** `Secret`  
**Purpose:** Stores sensitive information such as database passwords in base64-encoded form.

### Key Details:
- `MYSQL_ROOT_PASSWORD`: The root password for the MySQL server (`rootpassword123` encoded in base64).
- `MYSQL_PASSWORD`: The application user’s password (`todoapp123` encoded in base64).
- Defined as `type: Opaque`, meaning it stores arbitrary key-value data securely.

This ensures that database credentials are not stored in plaintext inside deployment manifests.

---

## 2. mysql-service.yaml

**Kind:** `Service`  
**Purpose:** Exposes the MySQL database to other pods within the cluster.

### Key Details:
- `port: 3306` → Default MySQL port.
- `selector: app: mysql` → Targets pods labeled `app: mysql`.
- `clusterIP: None` → Defines a **headless service**, which is required for `StatefulSet` to provide stable DNS names for MySQL pods.

This service allows other applications (like `todoapp`) to access MySQL at `mysql-service:3306`.

---

## 3. mysql-statefulset.yaml

**Kind:** `StatefulSet`  
**Purpose:** Deploys a **MySQL database pod** with persistent storage.

### Key Details:
- **Replicas:** `1` → Ensures a single instance of MySQL runs.
- **Service Name:** `mysql-service` → Ties the StatefulSet to the headless service for stable DNS.
- **Environment Variables:**  
  - `MYSQL_ROOT_PASSWORD` (from secret)  
  - `MYSQL_DATABASE: todoapp` → Database created at startup.  
  - `MYSQL_USER: todoapp` → Application user created.  
  - `MYSQL_PASSWORD` (from secret)  
- **Persistent Storage:**  
  - `volumeClaimTemplates` requests `5Gi` of storage using `linode-block-storage-retain`.  
  - Data is stored under `/var/lib/mysql` inside the container.

This setup ensures data persistence even if the MySQL pod is restarted or rescheduled.

---

## Summary

- `mysql-secret.yaml` → Stores database credentials securely.  
- `mysql-service.yaml` → Provides stable network access for the database.  
- `mysql-statefulset.yaml` → Manages MySQL deployment with persistence and stable identity.

Together, these files define a production-ready MySQL setup on Kubernetes.
