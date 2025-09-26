# Architecture Diagram

```
+---------------------------------------------------------------------------------------------------------+
|                                           Kubernetes Cluster                                            |
|                                                                                                         |
|  +-------------------------------------------------+     +------------------------------------------+   |
|  | Namespace: jenkins                              |     | External Services                        |   |
|  |                                                 |     |                                          |   |
|  | +-----------------+   (launches on demand)      |     |  +------------------+                    |   |
|  | | Jenkins Agent   | <-------------------------+ |     |  | Source Control   | (e.g., GitHub)     |   |
|  | | Pod (ephemeral) |                           | | <-> |  | (git clone/pull) |                    |   |
|  | +-----------------+                           | |     |  +------------------+                    |   |
|  |       ^                                       | |     |                                          |   |
|  |       | (executes build)                      | |     |  +------------------+                    |   |
|  | +-----+-----------+   +-------------------+   | |---> |  |Container Registry| (docker push)      |   |
|  | | Jenkins Cont.   |---| Persistent Volume |   | |     |  | (e.g., DockerHub)|                    |   |
|  | | (master) Pod    |   | (PVC)             |   | |     |  +------------------+                    |   |
|  | +-----------------+   +-------------------+   | |     +------------------------------------------+   |
|  |        ^                                        |                                                    |
|  +--------|----------------------------------------+                                                    |
|           |                                                                                             |
| +---------+---------+                                                                                   |
| | LoadBalancer      |                                                                                   |
| | Service           |                                                                                   |
| +---------+---------+                                                                                   |
|           ^                                                                                             |
+-----------|---------------------------------------------------------------------------------------------+
            |
    +-------+--------+
    | User's Browser |
    | (manages jobs) |
    +----------------+
```

---

# STEP 1

### Prerequisites & Namespace Setup

First, you'll prepare your cluster by creating a dedicated namespace and adding the official Jenkins Helm repository.

1. Create the `jenkins` namespace to isolate the Jenkins components.

   ```yaml
   kubectl create namespace jenkins
   ```

2. Add the Jenkins Helm chart repository.

   ```yaml
   helm repo add jenkins https://charts.jenkins.io
   ```

3. Update your local Helm chart repository cache.

   ```yaml
   helm repo update
   ```

---

# STEP 2

### Configure & Install Jenkins Controller

Next, you'll create a configuration file (`values.yaml`) for the Jenkins Helm chart and install the controller. This configuration defines resources, persistence, and service settings but omits plugins and agent configuration, which will be handled manually.

1. Create a file named `jenkins-values.yaml`.
2. Paste the following configuration into the file. It includes optimizations for resource usage, JVM performance, and sets the service type to `LoadBalancer` for external access.
3. Install the Jenkins chart into the `jenkins` namespace using your custom values file.

   ```yaml
   helm install jenkins jenkins/jenkins \
   --namespace jenkins \
   --values jenkins-values.yaml
   ```

---

# STEP 3

### Access Jenkins & Get Credentials

Once the installation is complete, you need to get the external IP address and the admin password to log in.

1. Wait for the `LoadBalancer` to be assigned an external IP. This may take a few minutes. Check the status with:

   ```yaml
   kubectl get svc jenkins -n jenkins --watch
   ```

   Look for the `EXTERNAL-IP` to be populated.

2. The admin password is set to `admin123` in the `values.yaml`. You can now access Jenkins at `http://<EXTERNAL-IP>:8080` and log in.

   For reference, if a password wasn't set, you could retrieve the auto-generated one with this command:

   ```yaml
   kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/chart-admin-password && echo
   ```

---

# STEP 4

### Install Essential Plugins

With Jenkins running, the next step is to install the plugins required for Kubernetes integration, pipeline visualization, and monitoring.

1. In the Jenkins UI, navigate to **Manage Jenkins** > **Plugins**.
2. Go to the **Available Plugins** tab.
3. Use the search bar to find and select the checkbox for each of the following plugins:
   - **Kubernetes Integration:**
     - `kubernetes`
     - `kubernetes-cli`
     - `kubernetes-credentials-provider`
   - **Pipeline & SCM:**
     - `workflow-aggregator`
     - `git`
     - `docker-workflow`
   - **UI & Visualization:**
     - `blueocean`
     - `pipeline-stage-view`
   - **Utilities:**
     - `credentials`
     - `prometheus`
4. Click the **Install** button to install all selected plugins. Jenkins will download and install them, after which it's ready for the final configuration step.

---

# STEP 5

### Configure Dynamic Kubernetes Agents

This final step configures Jenkins to dynamically launch agent pods in Kubernetes to run your builds. This is the manual equivalent of the `JCasC` configuration.

1. Navigate to **Manage Jenkins** > **Nodes and Clouds** > **Clouds**.
2. Click **Add a new cloud** and select **Kubernetes**.
3. Fill in the main Kubernetes cloud details:
   - **Name:** `kubernetes` (or another descriptive name)
   - **Kubernetes URL:** Leave this blank. The plugin will automatically use the in-cluster service account.
   - **Kubernetes Namespace:** `jenkins`
   - **Jenkins URL:** `http://jenkins.jenkins.svc.cluster.local:8080`
   - Click **Test Connection**. You should see a "Connection successful" message.
4. Scroll down to **Pod Templates** and click **Add Pod Template...** > **Pod Template**.
5. Configure the pod template details:
   - **Name:** `kaniko-agent`
   - **Namespace:** `jenkins`
   - **Labels:** `kaniko` (This label is used in your `Jenkinsfile` to select this agent).
   - **Usage:** Select `Use this node as much as possible`.
6. In the **Containers** section of the pod template, click **Add Container**. You will add two containers to this pod.
   - **First Container (Kaniko):**
     - **Name:** `kaniko`
     - **Docker image:** `gcr.io/kaniko-project/executor:debug`
     - **Command to run:** `sleep`
     - **Arguments to pass to the command:** `99d`
   - **Second Container (kubectl):**
     - Click **Add Container** again.
     - **Name:** `kubectl`
     - **Docker image:** `bitnami/kubectl:latest`
     - **Command to run:** `sleep`
     - **Arguments to pass to the command:** `99d`
7. Click **Save** to apply the cloud configuration. Jenkins is now fully configured to run builds on dynamic agents.

---

# STEP 6

## Using it in your `Jenkinsfile`

You can now reference the pre-configured template using a single line.

- **With this simplified version:**
  ```yaml
  agent {
  label 'kaniko'
  }
  ```

## Add the Docker Secret to the Pod Template

To allow Kaniko to push to your private registry, you must add your Docker secret to the agent template in the UI.

1. Navigate back to **Manage Jenkins** > **Nodes and Clouds** > **Clouds** and configure your **Kubernetes** cloud.
2. Find your `kaniko-agent` **Pod Template**.
3. Scroll to the **Volumes** section and click **Add Volume** > **Secret Volume**.
   - **Secret Name:** `docker-registry-config-kent`
4. Now, scroll up to the `kaniko` **Container Template** within that pod template.
5. Click **Add Volume Mount**.
   - **Volume:** Select the secret you just defined (`Secret docker-registry-config-kent`).
   - **Mount Path:** `/kaniko/.docker/config.json` (This mounts the secret as a file).
   - **Sub Path:** `.dockerconfigjson` (This specifies which key from the secret to use).
   - Check the **Read Only** box.
6. Click **Save**. Your agent template is now fully configured and ready for use.

---

### Troubleshooting

| Issue                                             | Solution                                                                                                                                                                                                                                                                        |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Jenkins pod is `Pending`**                      | Check PVC status with `kubectl get pvc -n jenkins`. If it's unbound, your cluster may not have a default `StorageClass`. Also, check `kubectl describe pod` for resource exhaustion on nodes.                                                                                   |
| **Cannot access Jenkins UI via LoadBalancer**     | Ensure the service has an `EXTERNAL-IP` with `kubectl get svc jenkins -n jenkins`. Check cloud provider firewall rules or security groups that might be blocking port 8080.                                                                                                     |
| **Builds are stuck "waiting for executor"**       | Go to **Manage Jenkins** > **Nodes and Clouds** > **Clouds**, select your Kubernetes cloud, and click **Test Connection**. Check the Jenkins controller logs for any errors related to pod creation permissions.                                                                |
| **Agent pod fails to start (`CrashLoopBackOff`)** | Find the agent pod name (`kubectl get pods -n jenkins`). Use `kubectl describe pod <agent-pod-name> -n jenkins` and `kubectl logs <agent-pod-name> -n jenkins -c <container-name>` to debug. Common issues are incorrect image names or permission errors within the container. |
