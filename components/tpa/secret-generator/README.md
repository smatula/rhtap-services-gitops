# TPA Secret Generator

This directory contains scripts and ArgoCD hooks to generate secrets and ConfigMaps for the TPA (Trusted Profile Analyzer) deployment.

## Overview

This replaces the old `create_secrets.sh` script with a declarative, GitOps-friendly approach. Secrets and ConfigMaps are generated dynamically based on the cluster's ingress domain.

## How It Works - ArgoCD/GitOps (Recommended)

When ArgoCD syncs the TPA application:

1. **PreSync Hook Runs**: The Job in argocd-hook.yaml executes before deployment
2. **Queries Cluster**: Gets the ingress domain from the IngressController
3. **Generates Secrets**: Creates all secrets with random passwords (or reuses existing ones)
4. **Creates ConfigMap**: Generates environment-specific values
5. **Main Sync**: ArgoCD then syncs the rest of the application

**Just commit and push** - ArgoCD handles the rest automatically!

## How It Works - Manual Deployment

If deploying without ArgoCD:

```bash
cd components/tpa
./secret-generator/generate-secrets.sh
kustomize build . | oc apply -f -
```

## Key Features

✅ **Fully automated** - No manual steps with ArgoCD
✅ **Environment-aware** - Auto-derives URLs from cluster ingress
✅ **Password preservation** - Reuses existing secrets across syncs
✅ **No secrets in git** - Everything generated at deployment time
✅ **Idempotent** - Safe to run multiple times

## Generated Resources

### Secrets (7 total):
1. `tpa-pgsql-user` - TPA database credentials
2. `keycloak-pgsql-user` - Keycloak database credentials
3. `tpa-realm-chicken-admin` (both namespaces) - Realm admin credentials
4. `tpa-realm-chicken-clients` (both namespaces) - OIDC client secrets
5. `tssc-trustification-integration` - Trustification config

### ConfigMap:
- `tpa-values-source` - Environment-specific URLs and domains

## Migration from create_secrets.sh

### Before:
```bash
source ./envfile
./create_secrets.sh  # Creates secrets via oc apply
yq -i '...' kustomization.yaml  # Manual edits
git commit  # Commit modified kustomization.yaml
```

### After (ArgoCD):
```bash
git commit  # Just commit your changes
git push    # ArgoCD PreSync hook generates everything
```

### After (Manual):
```bash
./secret-generator/generate-secrets.sh  # One command
kustomize build . | oc apply -f -
```

## Troubleshooting

### Check hook Job logs:
```bash
oc logs -n tssc-tpa job/tpa-generate-secrets
```

### Regenerate with new domain:
```bash
oc delete cm tpa-values-source -n tssc-tpa
# Trigger ArgoCD sync or re-run generate-secrets.sh
```

## Security

- ✅ No secrets stored in git
- ✅ Passwords generated in-cluster only
- ✅ Preserved across syncs (idempotent)
- ✅ RBAC-controlled generation
