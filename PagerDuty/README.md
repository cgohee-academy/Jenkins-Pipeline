
# PagerDuty Integration with Alertmanager

This document explains how PagerDuty was integrated with Alertmanager in
the **Prometheus monitoring stack**.

---

# PagerDuty Setup Documentation

This guide provides a step-by-step process for setting up a new PagerDuty account and configuring a service that triggers incidents based on incoming emails, which then notifies the on-call developers via email.

## 1. User Profile and Notification Configuration

Before creating services, ensure the developer profiles are set up to receive email notifications.

### 1.1 Create Your PagerDuty Account

1. **Navigate** to the PagerDuty sign-up page (e.g., for a trial).
2. **Enter** your work email and required information to create your account and subdomain (e.g., `yourcompany.pagerduty.com`).
3. **Complete** the onboarding steps, which typically include creating your first user, service, and escalation policy.

### 1.2 Set Up Contact Methods (for Developers)

1. Log in to PagerDuty and navigate to **User Icon** > **My Profile**.
2. Go to the **Contact Information** tab.
3. **Add** or verify your work email address in the **Email** section.
4. Optionally, add other contact methods like phone numbers for SMS or voice calls.

### 1.3 Configure Notification Rules (for Developers)

1. In the **My Profile** section, go to the **Notification Rules** tab.
2. These rules determine *how* and *when* you are notified for incidents assigned to you.
3. **Ensure** you have a rule configured for a **High-Urgency** incident that specifies **Email** as the contact method. For example: "Notify me via **Email** immediately when an incident is assigned to me with **High** urgency."
4. Configure additional rules for subsequent notifications if the incident is not acknowledged.

---

## 2. Create an Escalation Policy

An **Escalation Policy** defines *who* gets notified and *in what order* when an incident is triggered.

1. Navigate to **People** > **Escalation Policies**.
2. Click **+ New Escalation Policy**.
3. **Name** the policy descriptively (e.g., `Frontend-Dev-Team-Escalation`).
4. **Add** a new escalation rule. In the **Notify** field, select the developer's user profile (or an on-call schedule if one is created).
5. Set the **wait time** (e.g., 15 minutes) before escalating to the next rule.
6. **Add** additional escalation rules if you have secondary responders or backup teams.
7. Click **Create Policy**.

---

## 3. Create a Service Directory Entry for Email Alerts

A **Service** in PagerDuty represents an application, component, or system you want to monitor. This step creates a Service with an email integration that listens for incoming emails to trigger an incident and use the policy created in Step 2.

1. Navigate to **Services** > **Service Directory**.
2. Click **+ New Service**.
3. **Name** the service descriptively (e.g., `Web-App-Alerts-Service`).
4. Add a brief **Description** explaining the service's role.
5. Under **Assign to escalation policy**, select the Escalation Policy you created in **Step 2**.
6. Under **Integrations**, choose the **Integration Type**: Search for and select **Email** from the list.
7. Click **Add Service** (or similar button).
8. You will be redirected to the service's **Integrations** tab.
9. **Locate** the new Email Integration and **copy the unique Integration Email address**. This is the email address you will configure your external monitoring tool to send alert emails to.
10. **(Optional) Configure Email Management Rules**: If your monitoring tool sends various types of emails, click the **Edit Integration** gear icon next to your email integration. In the **Email Management** section, you can set custom rules using subject/body matching to decide when to **trigger** an incident, **resolve** an incident, or **discard** the email. By default, any email sent to this address will trigger an incident.

### 3.1 Final Check for Email Alerts

- Any email sent to the unique **Integration Email address** will trigger an incident on this service.
- This incident will be assigned to the first user/team in the **Escalation Policy**.
- The assigned user will be immediately notified via their configured contact methods, including **Email**, as per their **Notification Rules**.

## 🔧 Steps to Configure PagerDuty with Alertmanager

### 1. Create the Alertmanager Configuration (`alertmanager.yaml`)

Here is the configuration used to send alerts to PagerDuty:

```yaml
global:
  resolve_timeout: 5m

inhibit_rules:
- equal:
  - namespace
  - alertname
  source_matchers:
  - severity = critical
  target_matchers:
  - severity =~ warning|info
- equal:
  - namespace
  - alertname
  source_matchers:
  - severity = warning
  target_matchers:
  - severity = info
- equal:
  - namespace
  source_matchers:
  - alertname = InfoInhibitor
  target_matchers:
  - severity = info
- target_matchers:
  - alertname = InfoInhibitor

receivers:
- name: "null"

- name: "pagerduty"
  pagerduty_configs:
  - service_key: "<PAGERDUTY_ROUTING_KEY>"   # Replace with your actual routing key
    severity: '{{ .CommonLabels.severity | default "error" }}'
    send_resolved: true

route:
  group_by: ["namespace"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: "pagerduty"

  routes:
  - matchers:
    - alertname = "Watchdog"
    receiver: "null"

templates:
- /etc/alertmanager/config/*.tmpl

```

---

### 2. Create the Kubernetes Secret

To apply this configuration to your cluster, create a **Kubernetes
Secret** in the `monitoring` namespace:

```bash
kubectl -n monitoring create secret generic alertmanager-prometheus-kube-prometheus-alertmanager   --from-file=alertmanager.yaml=alertmanager.yaml --dry-run=client -o yaml | kubectl apply -f -

```

---

### 3. Restart Alertmanager Pod

After applying the new secret, restart Alertmanager to reload the
configuration:

```bash
kubectl -n monitoring delete pod -l app.kubernetes.io/name=alertmanager

```

This will force Kubernetes to spin up a new pod with the updated
configuration.

---

### 4. Test PagerDuty Integration

Send a test alert to Alertmanager and verify it reaches PagerDuty:

```bash
kubectl -n monitoring exec -it <alertmanager-pod-name> --   curl -XPOST -H 'Content-Type: application/json'   -d '[{"labels": {"alertname": "PagerDutyTest", "severity": "critical", "namespace": "monitoring"}}]'   <http://localhost:9093/api/v2/alerts>

```

Check PagerDuty to confirm that the incident was created.

---

## ✅ Verification

- Run
`kubectl -n monitoring port-forward svc/alertmanager-operated 9093`\
- Visit [http://localhost:9093](http://localhost:9093/)\
- Confirm that PagerDuty is listed as a **receiver** under the
`/api/v2/alerts` endpoint.

---

## 📌 Notes

- Always use **Routing Key** from PagerDuty **Events API v2** service
integration.
- Use **Service Key** from PagerDuty **Events API v1** service
integration.
- Inhibitions are configured so that **critical alerts silence
warning/info alerts** of the same type.
- The `Watchdog` alert is muted (sent to `null` receiver).

---
