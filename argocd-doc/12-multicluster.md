# Глава 12: Multi-cluster Setup

## Цели главы

После изучения этой главы вы:
- Научитесь настраивать multi-cluster окружение
- Освоите управление несколькими кластерами
- Изучите App of Apps pattern
- Поймете централизованное управление

## Настройка Multi-cluster

### Добавление внешнего кластера

#### Через CLI

```bash
# Получить credentials внешнего кластера
kubectl config view --minify --raw > /tmp/cluster-config.yaml

# Добавить кластер в ArgoCD
argocd cluster add <context-name> \
  --name production-cluster \
  --server https://production.example.com:6443

# Или с credentials
argocd cluster add <context-name> \
  --name production-cluster \
  --server https://production.example.com:6443 \
  --kubeconfig /tmp/cluster-config.yaml
```

#### Через UI

1. Откройте Settings > Clusters
2. Нажмите "Connect Cluster"
3. Введите:
   - **Cluster Name**: production-cluster
   - **Cluster URL**: https://production.example.com:6443
   - **Credentials**: (вставить kubeconfig)
4. Нажмите "Connect"

#### Через YAML

```yaml
# cluster-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: production-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: production-cluster
  server: https://production.example.com:6443
  config: |
    {
      "bearerToken": "<token>",
      "tlsClientConfig": {
        "caData": "<ca-data>",
        "certData": "<cert-data>",
        "keyData": "<key-data>"
      }
    }
```

```bash
# Применить секрет
kubectl apply -f cluster-secret.yaml
```

### Проверка подключения

```bash
# Список кластеров
argocd cluster list

# Детали кластера
argocd cluster get production-cluster

# Проверить подключение
argocd cluster get production-cluster --show-server
```

## Управление несколькими кластерами

### Создание приложения для конкретного кластера

```yaml
# prod-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    path: app
  destination:
    server: https://production.example.com:6443  # Внешний кластер
    namespace: production
  syncPolicy:
    automated:
      prune: true
```

### Приложения для разных кластеров

```yaml
# dev-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-dev
spec:
  destination:
    server: https://dev.example.com:6443
    namespace: dev

---
# staging-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-staging
spec:
  destination:
    server: https://staging.example.com:6443
    namespace: staging

---
# prod-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-prod
spec:
  destination:
    server: https://production.example.com:6443
    namespace: production
```

## App of Apps Pattern

### Что такое App of Apps?

**App of Apps** — это паттерн, где одно родительское приложение управляет несколькими дочерними приложениями.

### Структура App of Apps

```
apps/
├── app-of-apps.yaml          # Родительское приложение
├── base/
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   └── app-of-apps.yaml
    └── prod/
        └── app-of-apps.yaml
```

### Родительское приложение

```yaml
# app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Дочерние приложения

```yaml
# apps/nginx-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    path: nginx
  destination:
    server: https://kubernetes.default.svc
    namespace: default
---
# apps/redis-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    path: redis
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

### App of Apps для разных кластеров

```yaml
# apps/prod/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prod-app-of-apps
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/org/repo.git
    path: apps/prod
  destination:
    server: https://production.example.com:6443
    namespace: argocd
---
# apps/prod/nginx-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-prod
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/org/repo.git
    path: nginx/overlays/prod
  destination:
    server: https://production.example.com:6443
    namespace: production
```

## ApplicationSet

### Что такое ApplicationSet?

**ApplicationSet** — это CRD, который автоматически создает приложения на основе шаблонов и генераторов.

### Установка ApplicationSet Controller

```bash
# Установить ApplicationSet
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/applicationset/v0.5.0/manifests/install.yaml
```

### List Generator

```yaml
# applicationset-list.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: nginx-apps
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev.example.com:6443
      - cluster: staging
        url: https://staging.example.com:6443
      - cluster: production
        url: https://production.example.com:6443
  template:
    metadata:
      name: 'nginx-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo.git
        path: nginx
      destination:
        server: '{{url}}'
        namespace: '{{cluster}}'
      syncPolicy:
        automated:
          prune: true
```

### Cluster Generator

```yaml
# applicationset-cluster.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: nginx-cluster-apps
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  template:
    metadata:
      name: 'nginx-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo.git
        path: nginx
      destination:
        server: '{{server}}'
        namespace: default
```

### Git Generator

```yaml
# applicationset-git.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: nginx-git-apps
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/org/repo.git
      revision: main
      directories:
      - path: apps/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo.git
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: default
```

## Централизованное управление

### Hub-Spoke модель

```
Central ArgoCD (Hub)
├── Production Cluster
├── Staging Cluster
└── Development Cluster
```

### Настройка Hub

```yaml
# hub-argocd-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd-hub.example.com
```

### Управление через Hub

```yaml
# Все приложения управляются из Hub
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-prod
spec:
  destination:
    server: https://production.example.com:6443  # Удаленный кластер
```

## RBAC для Multi-cluster

### Ограничение доступа к кластерам

```yaml
# argocd-rbac-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # Разрешить доступ только к dev кластеру
    p, role:dev-admin, applications, *, dev-cluster/*, allow
    p, role:dev-admin, clusters, get, dev-cluster, allow
    
    # Разрешить доступ только к prod кластеру
    p, role:prod-admin, applications, *, prod-cluster/*, allow
    p, role:prod-admin, clusters, get, prod-cluster, allow
    
    # Назначить роли
    g, dev-team, role:dev-admin
    g, prod-team, role:prod-admin
```

## Мониторинг Multi-cluster

### Дашборд для всех кластеров

```bash
# Список приложений во всех кластерах
argocd app list

# Статус по кластерам
argocd app list --server https://production.example.com:6443
```

### Метрики по кластерам

```promql
# Количество приложений по кластерам
count by (cluster) (argocd_app_info)

# Статус синхронизации по кластерам
count by (cluster, sync_status) (argocd_app_info)
```

## Best Practices

### 1. Используйте отдельные проекты для кластеров

```yaml
# prod-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
spec:
  destinations:
  - namespace: '*'
    server: https://production.example.com:6443
```

### 2. Используйте ApplicationSet для масштабирования

```yaml
# Вместо создания множества приложений вручную
# Используйте ApplicationSet
```

### 3. Централизуйте управление

```yaml
# Один ArgoCD Hub управляет всеми кластерами
```

### 4. Используйте разные репозитории для разных окружений

```yaml
# dev-apps/
# staging-apps/
# prod-apps/
```

### 5. Настройте мониторинг для каждого кластера

```yaml
# Отдельные алерты для каждого кластера
```

## Troubleshooting

### Проблемы с подключением к кластеру

```bash
# Проверить подключение
argocd cluster get production-cluster

# Проверить credentials
kubectl --context=production-cluster get nodes

# Проверить логи
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Проблемы с синхронизацией

```bash
# Проверить статус приложения
argocd app get nginx-prod

# Проверить доступность кластера
argocd cluster get production-cluster
```

## Практическое задание

### Задание 1: Добавление кластера

1. Подготовьте второй кластер (или используйте контекст)
2. Добавьте кластер в ArgoCD
3. Проверьте подключение
4. Создайте тестовое приложение в новом кластере

### Задание 2: App of Apps

1. Создайте структуру App of Apps
2. Создайте родительское приложение
3. Создайте несколько дочерних приложений
4. Проверьте синхронизацию всех приложений

### Задание 3: ApplicationSet

1. Установите ApplicationSet Controller
2. Создайте ApplicationSet с List Generator
3. Проверьте автоматическое создание приложений
4. Попробуйте Git Generator

### Задание 4: Multi-cluster управление

1. Настройте приложения для разных кластеров
2. Настройте RBAC для ограничения доступа
3. Создайте дашборд для мониторинга
4. Протестируйте синхронизацию между кластерами

## Резюме

В этой главе вы:
- Научились настраивать multi-cluster окружение
- Освоили управление несколькими кластерами
- Изучили App of Apps pattern
- Поняли централизованное управление

В следующей главе мы изучим best practices.

## Дополнительные материалы

- [Multi-cluster Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- [ApplicationSet](https://argocd-applicationset.readthedocs.io/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#app-of-apps-pattern)
