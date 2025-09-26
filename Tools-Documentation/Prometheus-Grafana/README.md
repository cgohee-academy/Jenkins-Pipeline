# Architecture Diagram

This diagram illustrates how the components of the monitoring stack interact within the Kubernetes cluster. Prometheus discovers and scrapes metrics from various sources, Grafana queries Prometheus to visualize this data, and Alertmanager handles alerts.

```yaml
+---------------------------------------------------------------------------------------------------------+
|                                           Kubernetes Cluster                                            |
|                                                                                                         |
| +-----------------------------------------------+  +--------------------------------------------------+ |
| | Namespace: default, jenkins, etc.             |  | Namespace: monitoring                            | |
| |                                               |  |                                                  | |
| | +-----------------+   +---------------------+ |  |                                                  | |
| | |  Application    |   |   Jenkins Pod       | |  |                                                  | |
| | |  Pod (expose    |   |   (expose /metrics) | |  |                                                  | |
| | |  /metrics)      |   +---------------------+ |  |                                                  | |
| | +-----------------+                           |  |                                                  | |
| +-----------------------------------------------+  |                                                  | |
| +-----------------------------------------------+  | +-----------------+         +------------------+ | |
| | Node 1                                        |  | | Prometheus      |-------->| Alertmanager     | | |
| | +------------------+                          |  | | (scrapes        |<------->| (sends alerts)   | | |
| | | Node Exporter    | Scrape <-----------------+  | |  targets)       |         +------------------+ | |
| | | (DaemonSet)      |                          |  | +-------+---------+                              | |
| | +------------------+                          |  |         |                                        | |
| +-----------------------------------------------+  |         | (queries data via PromQL)              | |
| +-----------------------------------------------+  |         |                                        | |
| | Node N                                        |  |         v                                        | |
| | +------------------+                          |  | +-------+-------+         +------------------+   | |
| | | Node Exporter    | Scrape <-----------------+  | | Grafana       |<------->| User's Browser   |   | |
| | | (DaemonSet)      |                          |  | | (visualizes   |         |(views dashboards)|   | |
| | +------------------+                          |  | |     metrics)  |         +------------------+   | |
| +-----------------------------------------------+  | +---------------+                                | |
|                                                    |                                                  | |
|                                                    +--------------------------------------------------+ |
+---------------------------------------------------------------------------------------------------------+
```

---

# STEP 1

### Prerequisites & Namespace Setup

Before installing the charts, you need to create a dedicated namespace for monitoring components and add the necessary Helm repositories.

1. Create the `monitoring` namespace. This isolates all monitoring components.

   ```yaml
   kubectl create namespace monitoring
   ```

2. Label the namespace. This is a best practice for applying network policies later.

   ```yaml
   kubectl label namespace monitoring name=monitoring --overwrite
   ```

3. Add the required Helm chart repositories for Prometheus and Grafana.

   ```yaml
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo add grafana https://grafana.github.io/helm-charts
   ```

4. Update your local Helm chart repository cache to fetch the latest chart information.

   ```yaml
   helm repo update
   ```

---

# STEP 2

### Configure & Install Prometheus Stack

The `kube-prometheus-stack` chart deploys Prometheus, Alertmanager, Node Exporter, and other essential components. We'll configure it using a `values.yaml` file.

1. Create a file named `prometheus-values.yaml`.
2. Paste the following configuration into the file. This configuration is optimized for managed Kubernetes clusters by disabling components you don't control (like `etcd`, `scheduler`) and setting reasonable resource limits.YAML
3. Install the chart into the `monitoring` namespace using your custom values file. The `-wait` flag ensures Helm waits until all resources are in a ready state.

   ```yaml
   helm install prometheus prometheus-community/kube-prometheus-stack \
   --namespace monitoring \
   --values prometheus-values.yaml \
   --wait \
   --timeout 10m
   ```

---

# STEP 3

### Configure & Install Grafana

We install Grafana separately for more granular control over its configuration, datasources, and dashboards.

1. Create a file named `grafana-values.yaml`.
2. Paste the following configuration. This sets up persistence, default credentials, the Prometheus datasource, and pre-loads several useful dashboards.YAML
3. Install the Grafana chart into the `monitoring` namespace.

   ```yaml
   helm install grafana grafana/grafana \
   --namespace monitoring \
   --values grafana-values.yaml \
   --wait \
   --timeout 5m
   ```

---

# STEP 4

### Post-Installation & Verification

After installation, verify that all pods are running and apply additional configurations for security and service discovery.

1. **Verify Pod Status**: Check that all pods in the `monitoring` namespace are in the `Running` state.

   ```yaml
   kubectl get pods -n monitoring
   ```

2. **Configure Jenkins Monitoring**: Create a `ServiceMonitor` to allow Prometheus to dynamically discover and scrape the Jenkins service.
   - Create a file named `jenkins-servicemonitor.yaml`:
     ```yaml
     # jenkins-servicemonitor.yaml
     apiVersion: monitoring.coreos.com/v1
     kind: ServiceMonitor
     metadata:
       name: jenkins
       namespace: monitoring
       labels:
         app: jenkins
     spec:
       selector:
         matchLabels:
           app.kubernetes.io/name: jenkins
       namespaceSelector:
         matchNames:
           - jenkins
       endpoints:
         - port: http
           path: /prometheus
           interval: 60s
           scrapeTimeout: 30s
     ```
   - Apply the manifest:
     `kubectl apply -f jenkins-servicemonitor.yaml`
3. **Apply Network Policy**: Create a `NetworkPolicy` to control traffic flow into the monitoring namespace, allowing ingress primarily from itself and from the `jenkins` namespace.
   - Create a file named `monitoring-networkpolicy.yaml`:
     ```yaml
     # monitoring-networkpolicy.yaml
     apiVersion: networking.k8s.io/v1
     kind: NetworkPolicy
     metadata:
       name: monitoring-network-policy
       namespace: monitoring
     spec:
       podSelector: {}
       policyTypes:
         - Ingress
         - Egress
       ingress:
         - from:
             - namespaceSelector:
                 matchLabels:
                   name: monitoring
             - namespaceSelector:
                 matchLabels:
                   name: jenkins
             - podSelector: {} # Allow intra-namespace traffic
       egress:
         - {} # Allow all egress
     ```
   - Apply the manifest:
     ```yaml
     kubectl apply -f monitoring-networkpolicy.yaml
     ```
4. **Access Services**: Use `kubectl port-forward` to access the UIs from your local machine.
   - **Prometheus UI**:
     ```yaml
     kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
     # Access at: http://localhost:9090
     ```
   - **Grafana Dashboard**:
     ```yaml
     kubectl port-forward -n monitoring svc/grafana 3000:80
     # Access at: http://localhost:3000
     # (User: admin, Pass: admin123)
     ```
   - **AlertManager UI**:
     ```yaml
     kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
     # Access at: http://localhost:9093
     ```

---

### Troubleshooting

| Issue                                        | Solution                                                                                                                                                                                |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Prometheus targets are down (red)**        | Check `ServiceMonitor` labels match the service's labels. Verify network policies aren't blocking traffic. Ensure pods are running and exposing a metrics endpoint.                     |
| **Grafana can't connect to Prometheus**      | Verify the datasource URL in `grafana-values.yaml` is correct (`http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090`). Ensure the Prometheus pod is running. |
| **Pods are `Pending` or `CrashLoopBackOff`** | Use `kubectl describe pod <pod-name> -n monitoring` to inspect events. Check for insufficient node resources (CPU/memory) or PersistentVolumeClaim (PVC) binding issues.                |
| **Data not appearing for an application**    | Ensure the application correctly exposes metrics in Prometheus format. Create a `ServiceMonitor` or `PodMonitor` that correctly selects the application's service or pods.              |
