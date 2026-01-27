# Глава 13: Best Practices

## Цели главы

После изучения этой главы вы:
- Узнаете best practices организации репозиториев
- Изучите структуру проектов
- Поймете принципы безопасности
- Освоите оптимизацию производительности
- Научитесь troubleshooting

## Организация репозиториев

### Монорепозиторий vs Мультирепозиторий

#### Монорепозиторий

```
repo/
├── apps/
│   ├── nginx/
│   ├── redis/
│   └── postgres/
├── infrastructure/
│   ├── monitoring/
│   └── logging/
└── argocd-apps/
    ├── app-of-apps.yaml
    └── applications/
```

**Преимущества:**
- ✅ Единая точка истины
- ✅ Проще управление зависимостями
- ✅ Атомарные изменения

**Недостатки:**
- ❌ Может стать большим
- ❌ Конфликты при работе команды

#### Мультирепозиторий

```
app-repo/
└── k8s/

infra-repo/
└── k8s/

argocd-repo/
└── applications/
```

**Преимущества:**
- ✅ Независимость команд
- ✅ Разные права доступа
- ✅ Меньше конфликтов

**Недостатки:**
- ❌ Сложнее управление зависимостями
- ❌ Больше репозиториев для управления

### Рекомендуемая структура

```
repo/
├── README.md
├── apps/
│   ├── nginx/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   └── redis/
│       └── ...
├── infrastructure/
│   ├── monitoring/
│   └── logging/
└── argocd/
    ├── app-of-apps.yaml
    └── applications/
        ├── nginx-app.yaml
        └── redis-app.yaml
```

## Структура проектов

### Организация по командам

```yaml
# team-a-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
spec:
  description: Проект команды A
  sourceRepos:
  - 'https://github.com/org/team-a-repo.git'
  destinations:
  - namespace: team-a-*
    server: https://kubernetes.default.svc
```

### Организация по окружениям

```yaml
# dev-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: development
spec:
  description: Development окружение
  destinations:
  - namespace: dev-*
    server: https://dev-cluster.example.com:6443

---
# prod-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
spec:
  description: Production окружение
  destinations:
  - namespace: prod-*
    server: https://prod-cluster.example.com:6443
```

### Организация по приложениям

```yaml
# nginx-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: nginx
spec:
  description: Проект для Nginx
  sourceRepos:
  - 'https://github.com/org/nginx-repo.git'
  destinations:
  - namespace: nginx-*
    server: '*'
```

## Безопасность

### RBAC настройки

```yaml
# argocd-rbac-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # Администраторы
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, get, *, allow
    p, role:admin, repositories, *, *, allow
    g, admin, role:admin
    
    # Разработчики - только чтение и синхронизация своих приложений
    p, role:developer, applications, get, team-a/*, allow
    p, role:developer, applications, sync, team-a/*, allow
    p, role:developer, applications, action/*, team-a/*, allow
    g, developers, role:developer
    
    # Операторы - управление production
    p, role:operator, applications, *, production/*, allow
    g, operators, role:operator
```

### Ограничение репозиториев

```yaml
# project.yaml
spec:
  sourceRepos:
  - 'https://github.com/org/allowed-repo.git'  # Только разрешенные репозитории
```

### Ограничение кластеров

```yaml
# project.yaml
spec:
  destinations:
  - namespace: '*'
    server: https://allowed-cluster.example.com:6443  # Только разрешенные кластеры
```

### Использование Service Accounts

```yaml
# service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-deployer
  namespace: argocd
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-deployer
rules:
- apiGroups: ['*']
  resources: ['*']
  verbs: ['*']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-deployer
subjects:
- kind: ServiceAccount
  name: argocd-deployer
  namespace: argocd
```

### Управление секретами

```yaml
# Используйте External Secrets или Sealed Secrets
# Не храните секреты в открытом виде в Git
```

## Производительность

### Оптимизация синхронизации

```yaml
# Используйте автоматическую синхронизацию только когда нужно
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
```

### Кэширование репозиториев

```yaml
# argocd-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  repo.server.timeout.seconds: "60"  # Таймаут для репозиториев
```

### Ограничение ресурсов

```yaml
# argocd-application-controller deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-application-controller
spec:
  template:
    spec:
      containers:
      - name: controller
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### Параллельная синхронизация

```yaml
# argocd-cm.yaml
data:
  application.controller.concurrent.sync.limit: "10"  # Количество параллельных синхронизаций
```

## Версионирование

### Использование тегов

```yaml
spec:
  source:
    targetRevision: v1.2.3  # Конкретная версия
```

### Использование веток

```yaml
spec:
  source:
    targetRevision: main  # Стабильная ветка
```

### Семантическое версионирование

```
v1.0.0  # Major.Minor.Patch
v1.1.0  # Minor обновление
v1.1.1  # Patch обновление
v2.0.0  # Major обновление
```

## Мониторинг и алертинг

### Настройка уведомлений

```yaml
# argocd-notifications-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.slack: |
    token: $slack-token
  defaultTriggers: |
    - on-sync-succeeded
    - on-sync-failed
    - on-health-degraded
    - on-sync-status-unknown
```

### Метрики Prometheus

```yaml
# ServiceMonitor для ArgoCD
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

### Дашборды Grafana

```bash
# Импортировать дашборд
# ID: 14584 (ArgoCD)
```

## Troubleshooting

### Общие проблемы

#### Проблема: Приложение не синхронизируется

```bash
# 1. Проверить статус
argocd app get my-app

# 2. Проверить репозиторий
argocd repo get https://github.com/org/repo.git

# 3. Проверить логи
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# 4. Проверить доступность Git
kubectl exec -n argocd deployment/argocd-repo-server -- git ls-remote <repo-url>
```

#### Проблема: Ресурсы не создаются

```bash
# 1. Проверить права доступа
kubectl auth can-i create deployments --namespace default

# 2. Проверить манифесты
argocd app manifests my-app

# 3. Проверить события
kubectl get events -n default --sort-by='.lastTimestamp'
```

#### Проблема: Health check fails

```bash
# 1. Проверить статус ресурсов
kubectl get all -n default

# 2. Проверить логи подов
kubectl logs -n default <pod-name>

# 3. Проверить события
kubectl describe pod <pod-name> -n default
```

### Полезные команды

```bash
# Обновить приложение
argocd app get my-app --refresh

# Принудительная синхронизация
argocd app sync my-app --force

# Просмотр манифестов
argocd app manifests my-app

# Просмотр параметров
argocd app get my-app --show-params

# Дерево ресурсов
argocd app get my-app --show-tree
```

## Документация

### README для приложений

```markdown
# Nginx Application

## Описание
Веб-сервер Nginx

## Развертывание
```bash
kubectl apply -f argocd-apps/nginx/nginx-app.yaml
```

## Конфигурация
- Replicas: 3
- Image: nginx:1.21
- Port: 80

## Обновление
```bash
argocd app sync nginx-app
```
```

### Документация проектов

```markdown
# Team A Project

## Назначение
Проект для команды A

## Разрешения
- Разработчики: чтение и синхронизация
- Операторы: полный доступ

## Репозитории
- https://github.com/org/team-a-repo.git

## Кластеры
- Development: https://dev.example.com:6443
- Staging: https://staging.example.com:6443
```

## Чеклист для Production

- [ ] Настроен RBAC
- [ ] Используются проекты для изоляции
- [ ] Настроены уведомления
- [ ] Настроен мониторинг
- [ ] Используются External Secrets
- [ ] Настроены backup'ы
- [ ] Документированы процессы
- [ ] Настроены алерты
- [ ] Протестированы процедуры отката
- [ ] Настроена аутентификация (SSO)

## Практическое задание

### Задание 1: Организация репозитория

1. Создайте структуру репозитория по best practices
2. Организуйте приложения по папкам
3. Создайте README для каждого приложения
4. Настройте версионирование

### Задание 2: Настройка безопасности

1. Создайте проекты с ограничениями
2. Настройте RBAC
3. Ограничьте доступ к репозиториям и кластерам
4. Протестируйте права доступа

### Задание 3: Оптимизация

1. Настройте кэширование репозиториев
2. Ограничьте ресурсы для компонентов ArgoCD
3. Настройте параллельную синхронизацию
4. Измерьте производительность

### Задание 4: Мониторинг

1. Настройте уведомления
2. Интегрируйте с Prometheus
3. Создайте дашборд в Grafana
4. Настройте алерты

## Резюме

В этой главе вы:
- Узнали best practices организации репозиториев
- Изучили структуру проектов
- Поняли принципы безопасности
- Освоили оптимизацию производительности
- Научились troubleshooting

Поздравляем! Вы завершили курс по ArgoCD! 🎉

## Дополнительные материалы

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
