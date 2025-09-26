# Architecture Diagram

```
+---------------------------------------------------------------------------------------+
|                                  Kubernetes Cluster                                   |
|                                                                                       |
|      Node 1                          Node 2                          Node 3           |
|  +-----------------+           +-----------------+           +-----------------+      |
|  | [ Web App Pod ] |           | [ Web App Pod ] |           | [ Jenkins Pod ] |      |
|  | [ Another Pod ] |           | [ Jenkins Pod ] |           | [ Another Pod ] |      |
|  +-----------------+           +-----------------+           +-----------------+      |
|          |                             |                             |                |
|          v (writes to stdout/stderr)   v (writes to stdout/stderr)   v                |
|  +-----------------+           +-----------------+           +-----------------+      |
|  |  [ Log Files ]  |           |  [ Log Files ]  |           |  [ Log Files ]  |      |
|  | (/var/log/pods) |           | (/var/log/pods) |           | (/var/log/pods) |      |
|  +-----------------+           +-----------------+           +-----------------+      |
|          |                             |                             |                |
|          v (reads log files)           v (reads log files)           v                |
|  +-----------------+           +-----------------+           +-----------------+      |
|  | [OTEL Agent Pod]|           | [OTEL Agent Pod]|           | [OTEL Agent Pod]|      |
|  |   (DaemonSet)   |           |   (DaemonSet)   |           |   (DaemonSet)   |      |
|  +-----------------+           +-----------------+           +-----------------+      |
|                                                                                       |
+---------------------------------------------------------------------------------------+
         |                             |                             |
         |                             |   (Forwards Enriched Logs)  |
         +-----------------------------+-----------------------------+
                                       |
                                       v (via HEC)
                            +---------------------+
                            |  Splunk Enterprise  | (Running as standalone)
                            +---------------------+
```

---

# STEP 1

### SPLUNK OPERATOR (Needed for splunk to work in a k8s cluster)

1. install splunk operator helm repo
2. install splunk operator CRDs

   ```
   kubectl apply -f https://github.com/splunk/splunk-operator/releases/download/3.0.0/splunk-operator-crds.yaml --server-side
   ```

3. Configure needed values for the operator
4. Install/upgrade with custom values

   ```bash
   # Create dedicated operator namespace
   kubectl create namespace splunk-operator

   # Install splunk operator in the splunk-operator namespace
   helm install -f splunk-operator-values.yaml splunk-operator splunk/splunk-operator -n splunk-operator

   # Upgrade if custom values has been updated
   helm upgrade -f splunk-operator-values.yaml splunk-operator splunk/splunk-operator -n splunk-operator
   ```

5. Edit splunk operator controller manager deployment and add in env [(so splunk operator works)](https://splunk.github.io/splunk-operator/Install.html#install-operator-to-accept-the-splunk-general-terms)

   ```
       - name: SPLUNK_GENERAL_TERMS
         value: "--accept-sgt-current-at-splunk-com"
   ```

6. The splunk operator should now be installed and you are ready to install splunk enterprise!

---

# STEP 2

### SPLUNK ENTERPRISE

1. The splunk enterprise helm chart should already be installed since it comes with the splunk operator helm repo
2. Configure needed values
3. Install/upgrade with custom values

   ```bash
   # Install splunk enterprise inside the splunk-operator namespace
   helm install -f splunk-enterprise-values.yaml splunk-enterprise splunk/splunk-enterprise -n splunk-operator

   # Upgrade if custom values has changed (note that upgrading will reset the admin password)
   helm upgrade -f splunk-enterprise-values.yaml splunk-enterprise splunk/splunk-enterprise -n splunk-operator
   ```

4. Access the UI!

   ```yaml
   # Access the splunk web UI with
   kubectl port-forward -n splunk-operator svc/splunk-stdln-standalone-service 8000:8000
   ```

5. Get the admin password in the generated secret `(splunk-stdln-standalone-secret-v1)`

   ```yaml
   k get secret splunk-stdln-standalone-secret-v1 -n splunk-operator -o yaml

   # Data
   data:
     default.yml: <base64-encoded-value>
     idxc_secret: <base64-encoded-value>
     pass4SymmKey: <base64-encoded-value>
     password: <base64-encoded-value>
     shc_secret: <base64-encoded-value>

   # Decode these values to get what you need
   ```

6. From the splunk general settings:

   ```yaml
   default installation path: /opt/splunk
   default indexes location: /opt/splunk/var/lib/splunk
   ```

7. Add custom indexes [(or in indexes.conf)](https://help.splunk.com/en/splunk-enterprise/administer/manage-indexers-and-indexer-clusters/9.1/manage-indexes/create-custom-indexes#:~:text=index%20storage.-,Edit%20indexes.conf,a%20stanza%20to%20indexes.conf%20in%20%24SPLUNK_HOME/etc/system/local,-%2C%20identified%20by%20the)

   ```
   Note: These indexes have been configured inside our custom OTEL values so all we
   need to do now is create them.

   k8s_logs
   k8s_metrics
   ```

---

# STEP 3

### OTEL INSTALLATION (Our forwarder)

1. Add OTEL helm repo

   ```yaml
   helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
   ```

2. Configure the custom values for that chart
3. Install/Upgrade OTEL with custom values

   ```yaml
   # Create a dedicated namespace for the OTEL
   kubectl create namespace splunk-otel

   # For first time installation
   helm install my-splunk-otel-collector -f splunk-otel-values.yaml splunk-otel-collector-chart/splunk-otel-collector -n splunk-otel

   # Upgrade (if you added new configs for the HEC)
   helm upgrade my-splunk-otel-collector splunk-otel-collector-chart/splunk-otel-collector -f splunk-otel-values.yaml -n splunk-otel
   ```

4. Splunk has been setup with k8s!

---

### Troubleshooting

| Issue                    | Solution                                   |
| ------------------------ | ------------------------------------------ |
| No data in Splunk        | Check HEC token and endpoint configuration |
| OTel collector crashes   | Increase memory limits, reduce batch size  |
| Pods not starting        | Verify node resources and storage class    |
| Missing application logs | Ensure apps write to stdout/stderr         |
