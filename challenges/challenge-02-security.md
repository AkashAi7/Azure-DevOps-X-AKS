# Challenge 02: Blue-Green Deployment for Production

**Difficulty:** ⭐⭐⭐ (Advanced)  
**Estimated time:** 60-90 minutes  
**Take-home challenge**

---

## Scenario

Your SLA for the InventoryAPI in production requires **zero downtime** during deployments. The current rolling update strategy is good, but your ops team wants to implement a **blue-green deployment pattern** to:

1. Allow instant traffic switch instead of gradual rollout
2. Enable instant rollback by switching traffic back (not waiting for pods)
3. run the old version alongside the new one for validation

---

## Understanding Blue-Green

```
Current State (Blue = active):
┌────────────────────────────────┐
│  Ingress ──→ Service          │
│              (selector: blue)  │
│                                │
│  Blue Pods (v1.0) ← ACTIVE    │
│  Green Pods      ← IDLE       │
└────────────────────────────────┘

After Deploy (Green = active):
┌────────────────────────────────┐
│  Ingress ──→ Service          │
│              (selector: green) │
│                                │
│  Blue Pods (v1.0) ← IDLE      │
│  Green Pods (v1.1) ← ACTIVE   │
└────────────────────────────────┘
```

---

## Tasks

### Task 1: Create Blue and Green Deployments

Create `k8s/overlays/production/blue-green/blue-deployment.yaml`:
- Named `inventory-api-blue`
- Labels: `app: inventory-api`, `slot: blue`
- Initially 3 replicas

Create `k8s/overlays/production/blue-green/green-deployment.yaml`:
- Named `inventory-api-green`
- Labels: `app: inventory-api`, `slot: green`
- Initially 0 replicas (inactive)

### Task 2: Create the Traffic Management Service

Modify the production Service to use a slot selector:

```yaml
# k8s/overlays/production/blue-green/service-active.yaml
apiVersion: v1
kind: Service
metadata:
  name: inventory-api
  namespace: production
spec:
  selector:
    app: inventory-api
    slot: blue           # ← THIS IS WHAT YOU CHANGE to switch traffic
  ports:
    - port: 80
      targetPort: 3000
```

### Task 3: Create the Switch Script

Create a shell script `scripts/blue-green-switch.sh` that:
1. Detects which slot is currently active (blue/green)
2. Scales up the inactive slot with the new image
3. Waits for the new pods to be ready
4. Switches the service selector
5. Scales down the old slot

```bash
#!/bin/bash
# blue-green-switch.sh
# Usage: ./blue-green-switch.sh <new-image-tag>

NEW_TAG=$1
NAMESPACE="production"

# 1. Detect active slot
ACTIVE_SLOT=$(kubectl get service inventory-api -n $NAMESPACE \
  -o jsonpath='{.spec.selector.slot}')
echo "Active slot: $ACTIVE_SLOT"

# 2. Determine new slot
if [ "$ACTIVE_SLOT" = "blue" ]; then
  NEW_SLOT="green"
  OLD_SLOT="blue"
else
  NEW_SLOT="blue"  
  OLD_SLOT="green"
fi

echo "Deploying to $NEW_SLOT slot, then switching traffic from $OLD_SLOT"

# YOUR CODE HERE:
# 3. Update the new slot deployment with the new image
# 4. Scale up the new slot to 3 replicas
# 5. Wait for rollout to complete
# 6. Run health check against new slot (use pod IP directly, not service)
# 7. Switch service selector to new slot
# 8. Wait 30 seconds (traffic draining)
# 9. Scale down old slot to 0 replicas
```

### Task 4: Integrate with Azure DevOps CD Pipeline

Modify `cd-pipeline.yml` (production stage) to:
1. Use `strategy: blueGreen` OR call the switch script
2. Run smoke tests against the inactive slot before switching traffic
3. Only switch traffic after smoke tests pass

The Azure DevOps `strategy: blueGreen` built-in:
```yaml
strategy:
  blueGreen:
    deploy:
      steps: [...]           # Deploy to inactive slot
    routeTraffic:
      steps: [...]           # Switch traffic
    postRouteTraffic:
      steps: [...]           # Verify
    on:
      failure:
        steps: [...]         # Roll back traffic switch
      success:
        steps: [...]         # Clean up old slot
```

### Task 5: Test the Blue-Green Switch

1. Deploy v1.0 to the blue slot
2. Run a test: `watch -n 1 curl http://api.inventory.workshop.io/health`
3. Deploy v1.1 to the green slot
4. Watch the slot switch happen — verify no dropped requests
5. Practice rollback: switch traffic back to blue

---

## Acceptance Criteria

- [ ] Blue and green deployments exist in the production namespace
- [ ] Service selector controls which slot receives traffic
- [ ] `blue-green-switch.sh` script works correctly
- [ ] Azure DevOps production stage uses blue-green strategy
- [ ] Traffic switch completes with 0 request failures during transition
- [ ] Instant rollback works by re-running switch to old slot

---

## Bonus Challenge

Modify your Ingress to support **canary deployment** as an alternative:
- Send 10% of traffic to the new green slot
- Gradually increase to 100%
- Use NGINX ingress annotations for traffic splitting:

```yaml
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-weight: "10"
```
