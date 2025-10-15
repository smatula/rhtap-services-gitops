#!/bin/bash

source ./envfile

# Create namespaces where the secret will be
#oc new-project hive
#oc new-project artifactory
oc new-project ${TPA_NAMESPACE}
oc new-project rhbk-operator
oc new-project tssc-keycloak

# TPA - Grant Security Context Constraints (SCCs): Grant the non-root MinIO and PostgreSQL components the ability to run in the application namespaces.
#oc adm policy add-scc-to-user anyuid -z default -n minio-operator
#oc adm policy add-scc-to-user anyuid -z minio-operator -n minio-operator
#oc adm policy add-scc-to-user anyuid -z default -n ${TPA_NAMESPACE}


# Secret 1: TPA DB Connection Details 
cat <<EOF | oc apply -f - -n $TPA_NAMESPACE
apiVersion: v1
kind: Secret
type: Opaque
metadata:   
  name: tpa-pgsql-user
  namespace: $TPA_NAMESPACE 
stringData:
  dbname: tpa
  host: tpa-pgsql.tssc-tpa.svc
  user: tpa   
  port: "5432"
  password: "$TPA_USER_DB_PASS"
EOF

# Secret 2: Keycload DB Connection Details
cat <<EOF | oc apply -f - -n $KEYCLOAK_NAMESPACE
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: keycloak-pgsql-user
  namespace: $KEYCLOAK_NAMESPACE
stringData:
  dbname: keycloak
  host: keycloak-pgsql.tssc-keycloak.svc
  user: keycloak
  port: "5432"
  password: "$KEYCLOAK_USER_DB_PASS"
EOF

# Secret 3: Realm admin secret
cat <<EOF | oc apply -f - -n $TPA_NAMESPACE
apiVersion: v1
kind: Secret
metadata:
  annotations:
    helm.sh/resource-policy: keep
  labels:
    app: keycloak
  namespace: $TPA_NAMESPACE
  name: tpa-realm-chicken-admin
type: Opaque
data:
  username: $REALM_USER_B64
  password: $REALM_ADMIN_PASS_B64
EOF

# Secret 4: OIDC Client Secrets (oidc cli, manager, user)
cat <<EOF | oc apply -f - -n $TPA_NAMESPACE
apiVersion: v1
kind: Secret
metadata:
  annotations:
    helm.sh/resource-policy: keep
  labels:
    app: keycloak
  namespace: $TAP_NAMESPACE
  name: tpa-realm-chicken-clients
type: Opaque
data:
  cli: $PASS_CLI_B64
  testingManager: $PASS_MANAGER_B64
  testingUser: $PASS_USER_B64
EOF

# Secret 5: trustification integration
cat <<EOF | oc apply -f - -n $TPA_NAMESPACE
apiVersion: v1
kind: Secret
metadata:
  labels:
    app: keycloak
  namespace: $TPA_NAMESPACE
  name: tssc-trustification-integration
  annotations:
    helm.sh/resource-policy: keep
type: Opaque
stringData:
  bombastic_api_url: https://server$APP_DOMAIN_URL
  oidc_issuer_url: https://sso.$INGRESS_URL/realms/chicken
  oidc_client_id: cli
  oidc_client_secret: $PASS_CLI_B64
  supported_cyclonedx_version: "1.4"
EOF

# TPA - Update parameters of TPA app-of-apps 
yq -i '(.spec.sources[0].kustomize.parameters[] | select(.name == "KEYCLOAK_HOSTNAME").value) = env(KEYCLOAK_HOST)' app-of-apps/tpa.yaml
yq -i '(.spec.sources[0].kustomize.parameters[] | select(.name == "SEED_STRING").value) = env(SEED_STRING)' app-of-apps/tpa.yaml
yq -i '(.spec.sources[1].helm.parameters[] | select(.name == "appDomain").value) = env(APP_DOMAIN_URL)' app-of-apps/tpa.yaml
yq -i '(.spec.sources[1].helm.parameters[] | select(.name == "oidc.issuerUrl").value) = env(OIDC_ISSUER_URL)' app-of-apps/tpa.yaml

echo "NOTE: Parameters updated in app-of-apps/tpa.yaml. Check in changes before running bootstrap.sh"

# Create secrets
#echo "Creating Pull Secret"
#oc create secret generic global-pull-secret --type=kubernetes.io/dockerconfigjson --from-literal=.dockerconfigjson="$PULL_SECRET" -n hive

#echo "Creating AWS creds secret"
#oc create secret generic hive-aws-creds -n hive --from-literal=aws_access_key_id="$AWS_ACCESS_KEY_ID" --from-literal=aws_secret_access_key="$AWS_SECRET_ACCESS_KEY"

