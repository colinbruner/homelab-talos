# 1Password Connect Server + Operator

https://developer.1password.com/docs/connect/get-started/?deploy-type=kubernetes&deploy=kubernetes#step-2-deploy-1password-connect-server

## Deploying
```bash
# op connect token list
# ID=token
$ read -s OP_CONNECT_TOKEN && export OP_CONNECT_TOKEN=<token>

# Create deployment namespace
$ kubectl apply -k .

# Add helm repo
$ helm repo add 1password https://1password.github.io/connect-helm-charts/

# Download 1password-credentials.json from 1password entry
$ helm install connect 1password/connect \
  --namespace secrets-system \
  --set-file connect.credentials=/location/to/password-credentials.json \
  --set operator.create=true \
  --set operator.token.value=$OP_CONNECT_TOKEN

# Upgrading
$ helm upgrade connect 1password/connect \
  --namespace secrets-system \
  --set-file connect.credentials=/location/to/password-credentials.json \
  --set operator.create=true \
  --set operator.token.value=$OP_CONNECT_TOKEN
```

## Reading a Secret
The following provides an example of reading a secret from locally deployed connect server

```yaml
apiVersion: onepassword.com/v1
kind: OnePasswordItem
metadata:
  # Create k8s secret called 'some-secret'
  name: some-secret
spec:
  # Read secrets from vault 'lab' with item 'test-secret'
  itemPath: "vaults/lab/items/test-secret"
```

The above produces the following k8s secret fetched by: `kubectl get secret some-secret -o yaml`
```yaml
apiVersion: v1
data:
  password: c3VwZXItc2VjcmV0IQ==
kind: Secret
metadata:
  ...
```
