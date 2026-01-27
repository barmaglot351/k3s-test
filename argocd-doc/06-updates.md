# Глава 6: Обновление приложений

## Цели главы

После изучения этой главы вы:
- Изучите стратегии обновления приложений
- Научитесь настраивать автоматическую синхронизацию
- Освоите управление версиями
- Познакомитесь с Canary и Blue-Green развертываниями

## Стратегии обновления

### 1. Rolling Update (Постепенное обновление)

**Rolling Update** — стандартная стратегия Kubernetes, обновляет поды постепенно.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Максимум новых подов
      maxUnavailable: 0  # Максимум недоступных подов
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.22  # Новая версия
```

### 2. Recreate (Пересоздание)

**Recreate** — останавливает все поды перед созданием новых.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  strategy:
    type: Recreate  # Остановить все, затем создать новые
```

### 3. Canary Deployment (Канареечное развертывание)

Развертывание новой версии для части трафика.

```yaml
# Основное приложение
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
spec:
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: nginx
---
# Canary версия
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app-canary
spec:
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: canary
    path: nginx
```

### 4. Blue-Green Deployment

Развертывание новой версии параллельно со старой, затем переключение трафика.

```yaml
# Blue (текущая версия)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app-blue
spec:
  source:
    targetRevision: v1.0
---
# Green (новая версия)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app-green
spec:
  source:
    targetRevision: v2.0
```

## Автоматическая синхронизация

### Базовая автоматическая синхронизация

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
spec:
  syncPolicy:
    automated:
      prune: true      # Удалять ресурсы, отсутствующие в Git
      selfHeal: true   # Автоматически исправлять отклонения
```

### Синхронизация с ограничениями

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
```

### Настройка через CLI

```bash
# Включить автоматическую синхронизацию
argocd app set nginx-app --sync-policy automated

# С включенным prune
argocd app set nginx-app --sync-policy automated --auto-prune

# С включенным self-heal
argocd app set nginx-app --sync-policy automated --self-heal
```

## Управление версиями

### Использование тегов Git

```yaml
spec:
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: v1.2.3  # Конкретный тег
```

### Использование веток

```yaml
spec:
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main  # Ветка
```

### Использование коммитов

```yaml
spec:
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: abc123def  # SHA коммита
```

### Обновление версии через CLI

```bash
# Обновить на конкретный тег
argocd app set nginx-app --revision v1.2.3

# Обновить на ветку
argocd app set nginx-app --revision main

# Обновить на коммит
argocd app set nginx-app --revision abc123def
```

### Обновление версии через Git

```bash
# 1. Создать новый тег
git tag v1.2.4
git push origin v1.2.4

# 2. Обновить манифест приложения в Git
# argocd-apps/nginx-app.yaml
spec:
  source:
    targetRevision: v1.2.4

# 3. Закоммитить изменения
git add argocd-apps/nginx-app.yaml
git commit -m "Update nginx-app to v1.2.4"
git push

# 4. ArgoCD автоматически синхронизирует (если включена автоматическая синхронизация)
```

## Обновление образов контейнеров

### Обновление через Git

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.22  # Обновить версию образа
```

### Использование Image Updater

ArgoCD Image Updater автоматически обновляет образы контейнеров.

```bash
# Установить Image Updater
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

```yaml
# Приложение с Image Updater
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  annotations:
    argocd-image-updater.argoproj.io/image-list: nginx=nginx
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/git-branch: main
spec:
  # ...
```

## Синхронизация по Webhook

### Настройка Webhook

```yaml
# argocd-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  webhook.github: |
    - url: https://github.com/org/repo
      secret: <webhook-secret>
      events:
        - push
```

### Настройка в GitHub

1. Перейдите в Settings > Webhooks репозитория
2. Добавьте webhook:
   - **Payload URL**: `https://argocd.example.com/api/webhook`
   - **Content type**: `application/json`
   - **Secret**: (секрет из конфигурации)
   - **Events**: Push events

### Настройка в GitLab

1. Перейдите в Settings > Webhooks
2. Добавьте webhook:
   - **URL**: `https://argocd.example.com/api/webhook`
   - **Trigger**: Push events
   - **Secret token**: (секрет из конфигурации)

## Постепенное развертывание (Progressive Delivery)

### Использование Flagger

Flagger — инструмент для Canary и A/B тестирования.

```yaml
# Canary ресурс
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: nginx
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx
  service:
    port: 80
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
    - name: request-duration
      thresholdRange:
        max: 500
```

## Обновление с проверками

### Pre-Sync Hooks

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    hook:
      preSync:
        - name: pre-sync-check
          job:
            spec:
              template:
                spec:
                  containers:
                  - name: check
                    image: busybox
                    command: ['sh', '-c', 'echo "Pre-sync check"']
                  restartPolicy: Never
```

### Post-Sync Hooks

```yaml
spec:
  syncPolicy:
    hook:
      postSync:
        - name: post-sync-notification
          job:
            spec:
              template:
                spec:
                  containers:
                  - name: notify
                    image: curlimages/curl
                    command: ['curl', '-X', 'POST', 'https://webhook.example.com']
                  restartPolicy: Never
```

## Отслеживание обновлений

### История синхронизаций

```bash
# Просмотр истории
argocd app history nginx-app

# Детальная информация о синхронизации
argocd app history nginx-app --id <sync-id>
```

### Мониторинг через UI

1. Откройте приложение в UI
2. Перейдите в раздел "History"
3. Просмотрите историю синхронизаций
4. Изучите детали каждой синхронизации

## Практическое задание

### Задание 1: Автоматическая синхронизация

1. Создайте приложение с автоматической синхронизацией
2. Внесите изменения в Git-репозиторий
3. Проверьте, что ArgoCD автоматически синхронизировал изменения
4. Протестируйте prune и self-heal

### Задание 2: Управление версиями

1. Создайте несколько версий приложения в Git (теги)
2. Обновите приложение на разные версии
3. Используйте CLI для переключения версий
4. Изучите историю изменений

### Задание 3: Webhook синхронизация

1. Настройте webhook для вашего репозитория
2. Протестируйте автоматическую синхронизацию при push
3. Проверьте логи ArgoCD при получении webhook
4. Убедитесь, что синхронизация происходит мгновенно

### Задание 4: Стратегии развертывания

1. Создайте приложение с Rolling Update стратегией
2. Протестируйте обновление
3. Попробуйте Canary развертывание
4. Изучите различия в поведении

## Резюме

В этой главе вы:
- Изучили различные стратегии обновления
- Научились настраивать автоматическую синхронизацию
- Освоили управление версиями
- Познакомились с продвинутыми техниками развертывания

В следующей главе мы изучим откат приложений.

## Дополнительные материалы

- [Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-policies/)
- [ArgoCD Image Updater](https://argocd-image-updater.readthedocs.io/)
- [Flagger](https://flagger.app/)
