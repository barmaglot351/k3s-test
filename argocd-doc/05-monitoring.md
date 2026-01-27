# Глава 5: Мониторинг приложений

## Цели главы

После изучения этой главы вы:
- Научитесь отслеживать состояние приложений
- Освоите просмотр логов и событий
- Настроите алерты и уведомления
- Изучите метрики и дашборды

## Отслеживание состояния

### Статусы приложений

#### Health Status (Статус здоровья)

```bash
# Проверить статус здоровья
argocd app get nginx-app

# Возможные значения:
# - Healthy: Все ресурсы здоровы
# - Progressing: Приложение обновляется
# - Degraded: Некоторые ресурсы нездоровы
# - Suspended: Приложение приостановлено
# - Missing: Ресурсы отсутствуют
# - Unknown: Статус неизвестен
```

#### Sync Status (Статус синхронизации)

```bash
# Проверить статус синхронизации
argocd app get nginx-app

# Возможные значения:
# - Synced: Полностью синхронизировано
# - OutOfSync: Есть различия с Git
# - Unknown: Статус неизвестен
```

### Мониторинг через UI

1. **Applications List**
   - Общий обзор всех приложений
   - Цветовая индикация статусов
   - Быстрый доступ к деталям

2. **Application Details**
   - Детальная информация о статусе
   - Визуализация дерева ресурсов
   - История синхронизаций

3. **Resource Tree**
   - Иерархия ресурсов
   - Статус каждого ресурса
   - Связи между ресурсами

### Мониторинг через CLI

```bash
# Список всех приложений с статусами
argocd app list

# Детальная информация
argocd app get nginx-app

# Только статус
argocd app get nginx-app -o jsonpath='{.status.sync.status}'

# Только здоровье
argocd app get nginx-app -o jsonpath='{.status.health.status}'
```

## Логи и события

### Просмотр логов через CLI

```bash
# Логи всех подов приложения
argocd app logs nginx-app

# Логи конкретного пода
argocd app logs nginx-app --kind Pod --name nginx-pod-xxx

# Логи с фильтрацией
argocd app logs nginx-app --tail 100

# Логи в реальном времени
argocd app logs nginx-app --follow

# Логи конкретного контейнера
argocd app logs nginx-app --container nginx
```

### Просмотр логов через UI

1. Откройте приложение в UI
2. Перейдите в раздел "Logs"
3. Выберите под и контейнер
4. Просмотрите логи в реальном времени

### События Kubernetes

```bash
# События приложения
argocd app events nginx-app

# События через kubectl
kubectl get events -n default --sort-by='.lastTimestamp'

# События конкретного ресурса
kubectl describe deployment nginx-deployment -n default
```

### События в UI

1. Откройте приложение в UI
2. Перейдите в раздел "Events"
3. Просмотрите события Kubernetes
4. Фильтруйте по типу и времени

## Алерты и уведомления

### Настройка уведомлений

ArgoCD поддерживает интеграцию с различными системами уведомлений:
- Slack
- Microsoft Teams
- Discord
- Email
- Webhooks
- и другие

### Конфигурация через ConfigMap

```yaml
# argocd-notifications-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  defaultTriggers: |
    - on-sync-succeeded
    - on-sync-failed
    - on-health-degraded
  template.app-sync-succeeded: |
    email:
      subject: Application {{.app.metadata.name}} sync succeeded
    message: |
      Application {{.app.metadata.name}} sync succeeded.
      Application details: {{.context.argocdUrl}}/applications/{{.app.metadata.name}}
  template.app-sync-failed: |
    email:
      subject: Application {{.app.metadata.name}} sync failed
    message: |
      Application {{.app.metadata.name}} sync failed.
      Error: {{.failureReason}}
```

### Настройка триггеров в приложении

```yaml
# Приложение с уведомлениями
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: my-channel
    notifications.argoproj.io/subscribe.on-sync-failed.slack: my-channel
    notifications.argoproj.io/subscribe.on-health-degraded.slack: my-channel
spec:
  # ...
```

### Установка Notifications Controller

```bash
# Установить через Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd-notifications argo/argocd-notifications \
  --namespace argocd

# Или через манифесты
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/release-1.0/manifests/install.yaml
```

## Метрики и дашборды

### Метрики ArgoCD

ArgoCD экспортирует метрики в формате Prometheus:

```bash
# Получить метрики
kubectl port-forward svc/argocd-metrics -n argocd 9090:9090
curl http://localhost:9090/metrics
```

### Основные метрики

- `argocd_app_info` - Информация о приложениях
- `argocd_app_sync_total` - Количество синхронизаций
- `argocd_app_health_status` - Статус здоровья
- `argocd_app_sync_status` - Статус синхронизации
- `argocd_repo_connections_total` - Подключения к репозиториям

### Интеграция с Prometheus

```yaml
# ServiceMonitor для Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

### Grafana дашборды

ArgoCD предоставляет готовые дашборды для Grafana:

```bash
# Импортировать дашборд
# ID: 14584 (ArgoCD)
# URL: https://grafana.com/grafana/dashboards/14584
```

### Создание кастомного дашборда

Пример запросов для Grafana:

```promql
# Количество приложений по статусу здоровья
count by (health_status) (argocd_app_info)

# Количество приложений по статусу синхронизации
count by (sync_status) (argocd_app_info)

# Скорость синхронизаций
rate(argocd_app_sync_total[5m])
```

## Мониторинг через API

### REST API

```bash
# Получить токен
ARGOCD_TOKEN=$(argocd account generate-token)

# Список приложений
curl -H "Authorization: Bearer $ARGOCD_TOKEN" \
  https://argocd.example.com/api/v1/applications

# Статус приложения
curl -H "Authorization: Bearer $ARGOCD_TOKEN" \
  https://argocd.example.com/api/v1/applications/nginx-app
```

### gRPC API

```bash
# Использование через argocd CLI
argocd app get nginx-app --grpc-web
```

## Автоматический мониторинг

### Health Checks

ArgoCD автоматически проверяет здоровье ресурсов:

```yaml
# Кастомный health check
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        hs.message = obj.status.health.message
      end
    end
    return hs
```

### Автоматическое исправление (Self-Heal)

```yaml
spec:
  syncPolicy:
    automated:
      selfHeal: true  # Автоматически исправлять отклонения
```

## Практическое задание

### Задание 1: Мониторинг состояния

1. Создайте несколько приложений с разными статусами
2. Отслеживайте их состояние через UI и CLI
3. Изучите все возможные статусы
4. Научитесь интерпретировать статусы

### Задание 2: Работа с логами

1. Просмотрите логи приложения через CLI
2. Используйте фильтры и опции
3. Просмотрите логи через UI
4. Изучите события Kubernetes

### Задание 3: Настройка уведомлений

1. Установите ArgoCD Notifications
2. Настройте уведомления в Slack или Email
3. Протестируйте различные триггеры
4. Проверьте получение уведомлений

### Задание 4: Метрики и дашборды

1. Настройте экспорт метрик ArgoCD
2. Интегрируйте с Prometheus
3. Создайте дашборд в Grafana
4. Настройте алерты на метрики

## Резюме

В этой главе вы:
- Научились отслеживать состояние приложений
- Освоили просмотр логов и событий
- Настроили алерты и уведомления
- Изучили метрики и дашборды

В следующей главе мы изучим обновление приложений.

## Дополнительные материалы

- [ArgoCD Notifications](https://argocd-notifications.readthedocs.io/)
- [ArgoCD Metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)
- [Grafana Dashboard](https://grafana.com/grafana/dashboards/14584)
