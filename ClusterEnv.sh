#!/bin/bash
set -euo pipefail
# Branch
BRANCH="tpa3-no-cmp"

# Get cluster ingress domain
INGRESS_DOMAIN=$(oc -n openshift-ingress-operator get ingresscontrollers.operator.openshift.io default -o jsonpath='{.status.domain}' 2>/dev/null || echo "apps.example.com")

# Set namespace variables
TPA_NAMESPACE="tssc-tpa"
REALM="chicken"

# Derive values
APP_DOMAIN_URL="-${TPA_NAMESPACE}.${INGRESS_DOMAIN}"
KEYCLOAK_HOST="sso.${INGRESS_DOMAIN}"
OIDC_ISSUER_URL="https://sso.${INGRESS_DOMAIN}/realms/${REALM}"

# Output to components/tpa/config/cluster.env
cat <<EOF > ./components/tpa/config/cluster.env
APP_DOMAIN_URL="${APP_DOMAIN_URL}"
OIDC_ISSUER_URL="${OIDC_ISSUER_URL}"
KEYCLOAK_HOSTNAME="${KEYCLOAK_HOST}"
REDIRECT_URI1="https://server${APP_DOMAIN_URL}"
REDIRECT_URI2="https://server${APP_DOMAIN_URL}/*"
REDIRECT_URI3="https://sbom${APP_DOMAIN_URL}"
REDIRECT_URI4="https://sbom${APP_DOMAIN_URL}/*"
EOF

git switch "$BRANCH"
git commit \
    --all \
    --message "chore: update components/tpa/cluster.env $BRANCH"
git push --set-upstream origin "$BRANCH"
