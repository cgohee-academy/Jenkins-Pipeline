# 📘 Runbook for TodoApp Alerts

This runbook provides step-by-step guidance for handling alerts defined in the `todoapp-alerts` PrometheusRule.  
It covers application, database, exporter, and logging/monitoring failures.

---

## 🔴 Critical Alerts

### 1. TodoApp-LowAvailability
**Trigger:** Success rate fell below 95% for 5 minutes.
   ```bash
       (
          1 -
          (
            sum(rate(todoapp_requests_total{namespace="todo-app", job="todoapp-service", exported_endpoint=~"simulate_.*"}[5m]))
            /
            sum(rate(todoapp_requests_total{namespace="todo-app", job="todoapp-service"}[5m]))
          )
        ) < 0.95
   ``` 
**Possible Causes:**
- Increased error responses (4xx/5xx)
- Application crash/restarts
- Dependency issues (DB/service down)

**Investigation Steps:**
1. Check Grafana/Splunk error rate panels.  
2. Inspect pod health:  
   ```bash
   kubectl get pods -n todo-app
   ```  
3. Check application logs:  
   ```bash
   kubectl logs <todoapp-pod>
   ```  

**Mitigation:**
- Restart deployment:  
  ```bash
  kubectl rollout restart deployment todoapp
  ```
- Roll back recent deployment if errors started after release.
- Ensure DB and dependencies are healthy.

**Escalation:** Notify App Dev Team.

---

### 2. TodoApp-HighCPU
**Trigger:** CPU usage > 80% for 5 minutes.  
   ```bash
        sum(
          rate(container_cpu_usage_seconds_total{
            namespace="todo-app",
            pod=~"todoapp-.*",
            container="todoapp"
          }[5m])
        * on(pod, namespace)
          group_left()
          kube_pod_status_phase{phase="Running", namespace="todo-app"}
        ) > 0.8
   ``` 
**Investigation:**
- View metrics in Grafana/Splunk CPU dashboard.
- Verify pod resource usage:  
  ```bash
  kubectl top pod -n todo-app
  ```
- Check logs for high load patterns.

**Mitigation:**
- Scale replicas:  
  ```bash
  kubectl scale deployment todoapp --replicas=3
  ```
- Increase CPU requests/limits in `todoapp-deployment.yaml`.
- Optimize code/queries causing CPU spikes.

---

### 3. TodoApp-HighMemory
**Trigger:** Memory usage > 500Mi for 5 minutes.  
   ```bash
     sum(
          container_memory_usage_bytes{
            namespace="todo-app",
            pod=~"todoapp-.*",
            container="todoapp"
          }
        * on(pod, namespace)
          group_left()
          kube_pod_status_phase{phase="Running", namespace="todo-app"}
        ) > 500 * 1024 * 1024
   ``` 
**Investigation:**
- `kubectl top pod -n todo-app`
- Inspect memory-intensive requests/logs.

**Mitigation:**
- Increase memory requests/limits.
- Optimize application memory usage.
- Scale replicas to distribute load.

---

### 4. TodoApp-OOM-Killed
**Trigger:** Container OOMKilled in last 10 min.  
   ```bash
   increase(kube_pod_container_status_last_terminated_reason{namespace="todo-app" , pod=~"todoapp-.*", reason="OOMKilled"}[10m]) > 0
   ``` 
**Investigation:**
- Describe pod for termination reason:  
  ```bash
  kubectl describe pod <todoapp-pod>
  ```
- Check container logs prior to crash.

**Mitigation:**
- Increase memory limits in deployment spec.
- Fix memory leaks in code.

**Escalation:** Notify App Dev Team.

---

### 5. TodoApp-HighError-Rate (5xx)
**Trigger:** >5% requests return 5xx in last 5 minutes.  
   ```bash
        (
          sum(
            rate(todoapp_requests_total{
              namespace="todo-app",
              job="todoapp-service",
              exported_endpoint="simulate_500"
            }[5m])
          * on(pod, namespace)
            group_left()
            kube_pod_status_phase{phase="Running", namespace="todo-app"}
          )
          /
          sum(
            rate(todoapp_requests_total{
              namespace="todo-app",
              job="todoapp-service"
            }[5m])
          * on(pod, namespace)
            group_left()
            kube_pod_status_phase{phase="Running", namespace="todo-app"}
          )
        ) > 0.05
   ``` 
**Investigation:**
- Review Grafana/Splunk error dashboards.  
- Logs:  
  ```bash
  kubectl logs <todoapp-pod>
  ```  
- Check DB/service dependencies.

**Mitigation:**
- Restart pods if unhealthy.  
- Roll back deployment if regression.  
- Verify DB/network connectivity.

---

### 6. TodoApp-HighError-Rate (4xx)
**Trigger:** >5% requests return 4xx in last 5 minutes.  
   ```bash
        (
          sum(
            rate(todoapp_requests_total{
              namespace="todo-app",
              job="todoapp-service",
              exported_endpoint="simulate_404"
            }[5m])
          * on(pod, namespace)
            group_left()
            kube_pod_status_phase{phase="Running", namespace="todo-app"}
          )
          /
          sum(
            rate(todoapp_requests_total{
              namespace="todo-app",
              job="todoapp-service"
            }[5m])
          * on(pod, namespace)
            group_left()
            kube_pod_status_phase{phase="Running", namespace="todo-app"}
          )
        ) > 0.05
   ``` 
**Investigation:**
- Inspect logs for error patterns (401/403/404).  
- Verify API gateway rules and client requests.

**Mitigation:**
- Fix misconfigured clients.  
- Ensure correct auth tokens/secrets.  
- Communicate with API consumers.

---

### 7. TodoApp-WebUI-Down
**Trigger:** App pod not responding.  
   ```bash
   kube_pod_container_status_running{pod=~"todoapp-.*"} == 0
   ``` 
**Investigation:**
- `kubectl get pods -n todo-app`  
- `kubectl describe pod <todoapp-pod>`  

**Mitigation:**
- Restart deployment.  
- Investigate crash logs.  
- Ensure node is healthy.

---

### 8. Database-Down
**Trigger:** MySQL pod not responding.  
   ```bash
   kube_pod_container_status_running{pod=~"mysql-.*"} == 0
   ``` 
**Investigation:**
- `kubectl get pods -n todo-app`  
- Check MySQL pod logs.  

**Mitigation:**
- Restart MySQL pod.  
- Verify persistent volume claims.  
- Restore backup if corrupted.

**Escalation:** Notify DB Admin Team.

---

### 9. Prometheus-Exporter-Down
**Trigger:** Node exporter pod not responding.  
   ```bash
   kube_pod_container_status_running{pod=~"prometheus-prometheus-node-exporter-.*"} == 0
   ``` 
**Investigation:**
- `kubectl get pods -n monitoring`  
- Check exporter pod logs.  
- Verify Prometheus `/targets` page.

**Mitigation:**
- Restart exporter pod:  
  ```bash
  kubectl delete pod <exporter-pod> -n monitoring
  ```
- Reapply exporter DaemonSet if needed.

---

### 10. Splunk-UI-Down
**Trigger:** Splunk enterprise pod not running.  
   ```bash
   kube_pod_container_status_running{container="splunk"} == 0
   ``` 
**Investigation:**
- `kubectl describe pod <splunk-pod>`  
- Logs:  
  ```bash
  kubectl logs <splunk-pod> -c splunk
  ```

**Mitigation:**
- Fix config/secret issues.  
- Restart pod.  
- Roll back image if broken.

---

### 11. Splunk-OTEL-Collector-Down
**Trigger:** Splunk OTEL collector pod not responding.  
   ```bash
   kube_pod_container_status_running{pod=~"my-splunk-otel-collector-.*"}
   ``` 
**Investigation:**
- `kubectl get pods -n monitoring`  
- Logs:  
  ```bash
  kubectl logs <otel-pod>
  ```

**Mitigation:**
- Restart pod.  
- Verify configs and secrets.  
- Check network connectivity to Splunk.

---

## 🟡 Warning Alerts

These indicate potential issues but are not immediately critical.

- **High CPU (TodoApp-HighCPU)**  
- **High Memory (TodoApp-HighMemory)**  

Recommended action: Monitor closely and take proactive scaling measures.

---

## 📌 Escalation Matrix
- **App Issues (5xx, OOM, availability, 4xx)** → Application Dev Team  
- **Database Issues** → Database Admin Team  
- **Exporter / Prometheus Issues** → SRE / Monitoring Team  
- **Splunk Issues** → Logging/Observability Team  

---