# Глава 11: Управление секретами

## Цели главы

После изучения этой главы вы:
- Поймете встроенное управление секретами в ArgoCD
- Научитесь интегрировать внешние системы управления секретами
- Освоите работу с Sealed Secrets
- Изучите External Secrets Operator

## Встроенное управление секретами

### Хранение секретов в Git

ArgoCD может работать с секретами, хранящимися в Git (зашифрованными или в base64).

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
data:
  username: YWRtaW4=  # base64 encoded
  password: cGFzc3dvcmQ=
```

### Проблемы с секретами в Git

- ❌ Секреты в открытом виде (даже в base64)
- ❌ История коммитов содержит секреты
- ❌ Сложность ротации
- ❌ Риски безопасности

## Sealed Secrets

### Что такое Sealed Secrets?

**Sealed Secrets** — это инструмент для безопасного хранения секретов в Git. Секреты шифруются публичным ключом и могут быть расшифрованы только в кластере.

### Установка Sealed Secrets

```bash
# Установить Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Проверить установку
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### Создание Sealed Secret

```bash
# Установить kubeseal CLI
# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-linux-amd64 -O kubeseal
chmod +x kubeseal
sudo mv kubeseal /usr/local/bin/

# macOS
brew install kubeseal
```

```bash
# Создать обычный Secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  --dry-run=client -o yaml > secret.yaml

# Запечатать Secret
kubeseal -o yaml < secret.yaml > sealed-secret.yaml

# Теперь sealed-secret.yaml можно безопасно хранить в Git
```

### Использование в ArgoCD

```yaml
# sealed-secret.yaml (безопасно хранить в Git)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-secret
  namespace: default
spec:
  encryptedData:
    username: AgBx...
    password: AgBy...
  template:
    metadata:
      name: my-secret
      namespace: default
    type: Opaque
```

```yaml
# Приложение с Sealed Secret
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-with-secrets
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: app
  # Sealed Secrets Controller автоматически расшифрует секреты
```

## External Secrets Operator

### Что такое ESO?

**External Secrets Operator** — это Kubernetes оператор, который синхронизирует секреты из внешних систем (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault и др.).

### Установка ESO

```bash
# Установить через Helm
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

### Настройка SecretStore

```yaml
# secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: external-secrets
```

### Создание ExternalSecret

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-external-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: my-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: secret/data/myapp
      property: username
  - secretKey: password
    remoteRef:
      key: secret/data/myapp
      property: password
```

### Использование в ArgoCD

```yaml
# Приложение с External Secret
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-with-external-secrets
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: app
  # External Secrets Operator автоматически создаст Secret
```

## HashiCorp Vault интеграция

### Настройка Vault

```yaml
# vault-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
```

### Создание ExternalSecret для Vault

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: vault-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: SecretStore
  target:
    name: my-secret
  data:
  - secretKey: password
    remoteRef:
      key: secret/data/myapp
      property: password
```

## AWS Secrets Manager интеграция

### Настройка для AWS

```yaml
# aws-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
```

### Создание ExternalSecret для AWS

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aws-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: my-secret
  data:
  - secretKey: api-key
    remoteRef:
      key: myapp/api-key
```

## Azure Key Vault интеграция

### Настройка для Azure

```yaml
# azure-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azurekv:
      vaultUrl: "https://myvault.vault.azure.net"
      authType: ServicePrincipal
      tenantId: "xxx"
      authSecretRef:
        clientId:
          name: azure-secret
          key: client-id
        clientSecret:
          name: azure-secret
          key: client-secret
```

## ArgoCD Vault Plugin

### Установка Vault Plugin

```yaml
# argocd-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  configManagementPlugins: |
    - name: argocd-vault-plugin
      generate: |
        command: [sh, -c]
        args: ["argocd-vault-plugin generate -"]
```

### Использование Vault Plugin

```yaml
# kustomization.yaml с Vault
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
```

```yaml
# deployment.yaml с Vault аннотациями
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  template:
    spec:
      containers:
      - name: nginx
        env:
        - name: PASSWORD
          value: <path:secret/data/myapp#password>  # Vault путь
```

## Best Practices

### 1. Не храните секреты в открытом виде

```yaml
# ❌ Плохо
data:
  password: cGFzc3dvcmQ=  # base64, но все еще небезопасно

# ✅ Хорошо
# Используйте Sealed Secrets или External Secrets
```

### 2. Используйте External Secrets для production

```yaml
# Production окружения должны использовать внешние системы
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
# ...
```

### 3. Ротируйте секреты регулярно

```yaml
spec:
  refreshInterval: 1h  # Обновлять каждый час
```

### 4. Используйте разные SecretStores для разных окружений

```yaml
# dev-secretstore.yaml
# prod-secretstore.yaml
```

### 5. Ограничьте доступ к секретам через RBAC

```yaml
# RBAC для доступа к секретам
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["my-secret"]
  verbs: ["get", "list"]
```

## Troubleshooting

### Проблемы с Sealed Secrets

```bash
# Проверить статус Sealed Secrets Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Проверить логи
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Проверить Sealed Secret
kubectl get sealedsecret my-secret
```

### Проблемы с External Secrets

```bash
# Проверить External Secret
kubectl get externalsecret my-external-secret

# Проверить статус
kubectl describe externalsecret my-external-secret

# Проверить логи ESO
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
```

## Практическое задание

### Задание 1: Sealed Secrets

1. Установите Sealed Secrets Controller
2. Создайте и запечатайте секрет
3. Сохраните Sealed Secret в Git
4. Разверните через ArgoCD и проверьте расшифровку

### Задание 2: External Secrets

1. Установите External Secrets Operator
2. Настройте SecretStore (можно использовать локальный Vault или mock)
3. Создайте ExternalSecret
4. Проверьте создание Secret в кластере

### Задание 3: Интеграция с Vault

1. Настройте подключение к HashiCorp Vault
2. Создайте SecretStore для Vault
3. Создайте ExternalSecret
4. Проверьте синхронизацию секретов

### Задание 4: Best Practices

1. Настройте RBAC для секретов
2. Настройте ротацию секретов
3. Создайте разные SecretStores для dev и prod
4. Протестируйте безопасность конфигурации

## Резюме

В этой главе вы:
- Поняли встроенное управление секретами в ArgoCD
- Научились интегрировать внешние системы
- Освоили работу с Sealed Secrets
- Изучили External Secrets Operator

В следующей главе мы изучим multi-cluster setup.

## Дополнительные материалы

- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [ArgoCD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/)
