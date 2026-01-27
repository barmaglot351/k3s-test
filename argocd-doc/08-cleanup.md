# Глава 8: Удаление и очистка ресурсов

## Цели главы

После изучения этой главы вы:
- Научитесь правильно удалять приложения
- Освоите очистку ресурсов
- Изучите управление finalizers
- Узнаете best practices для cleanup

## Удаление приложений

### Удаление через CLI

```bash
# Удалить приложение (без удаления ресурсов в кластере)
argocd app delete nginx-app

# Удалить приложение с ресурсами (cascade)
argocd app delete nginx-app --cascade

# Удалить с подтверждением
argocd app delete nginx-app --yes

# Удалить несколько приложений
argocd app delete app1 app2 app3
```

### Удаление через UI

1. Откройте приложение в UI
2. Нажмите кнопку "Delete"
3. Выберите опции:
   - **Cascade**: Удалить ресурсы в кластере
4. Подтвердите удаление

### Удаление через YAML

```bash
# Удалить через kubectl
kubectl delete application nginx-app -n argocd

# С опцией каскадного удаления (если настроено)
kubectl delete application nginx-app -n argocd --cascade=foreground
```

## Очистка ресурсов

### Автоматическая очистка (Prune)

Prune автоматически удаляет ресурсы, которые больше не существуют в Git.

```yaml
spec:
  syncPolicy:
    automated:
      prune: true  # Включить автоматическую очистку
```

### Ручная очистка

```bash
# Синхронизировать с очисткой
argocd app sync nginx-app --prune

# Принудительная очистка
argocd app sync nginx-app --prune --force
```

### Очистка через UI

1. Откройте приложение в UI
2. Нажмите "Sync"
3. Включите опцию "Prune"
4. Выполните синхронизацию

## Управление Finalizers

### Что такое Finalizers?

**Finalizers** — это механизм Kubernetes, который предотвращает удаление ресурса до завершения определенных действий.

### Finalizers в ArgoCD

ArgoCD добавляет finalizer к приложениям для корректного удаления:

```yaml
metadata:
  finalizers:
  - resources-finalizer.argocd.argoproj.io
```

### Проблемы с Finalizers

Иногда finalizers могут блокировать удаление:

```bash
# Проверить finalizers
kubectl get application nginx-app -n argocd -o yaml | grep finalizers

# Удалить finalizer вручную (осторожно!)
kubectl patch application nginx-app -n argocd \
  --type json \
  --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
```

### Безопасное удаление Finalizers

```bash
# 1. Убедиться, что приложение не синхронизируется
argocd app terminate-op nginx-app

# 2. Удалить приложение
argocd app delete nginx-app

# 3. Если блокируется, удалить finalizer
kubectl patch application nginx-app -n argocd \
  --type merge \
  -p '{"metadata":{"finalizers":[]}}'
```

## Удаление ресурсов в кластере

### Удаление через ArgoCD

```bash
# Удалить приложение с ресурсами
argocd app delete nginx-app --cascade

# Это удалит:
# - Application ресурс в ArgoCD
# - Все ресурсы приложения в целевом namespace
```

### Удаление вручную

```bash
# Удалить ресурсы вручную
kubectl delete deployment nginx-deployment -n default
kubectl delete service nginx-service -n default

# Затем удалить приложение в ArgoCD
argocd app delete nginx-app
```

### Массовое удаление

```bash
# Удалить все ресурсы в namespace
kubectl delete all --all -n default

# Удалить все приложения в проекте
argocd app list --project my-project -o name | xargs -I {} argocd app delete {}
```

## Очистка Namespace

### Удаление Namespace

```bash
# Удалить namespace (удалит все ресурсы внутри)
kubectl delete namespace my-namespace

# Если namespace блокируется finalizers
kubectl get namespace my-namespace -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw /api/v1/namespaces/my-namespace/finalize -f -
```

### Очистка через ArgoCD

```yaml
# Если namespace создан через ArgoCD
spec:
  syncPolicy:
    syncOptions:
    - PrunePropagationPolicy=foreground  # Удалять в правильном порядке
```

## Очистка Helm релизов

### Удаление Helm релиза

```bash
# Удалить через Helm
helm uninstall nginx-release

# Удалить через ArgoCD
argocd app delete nginx-app --cascade
```

### Очистка Helm секретов

Helm хранит информацию о релизах в секретах:

```bash
# Просмотреть Helm секреты
kubectl get secrets -n default | grep helm

# Удалить секреты
kubectl delete secret sh.helm.release.v1.nginx-release.v1 -n default
```

## Очистка PersistentVolumes

### Удаление PVC

```bash
# Удалить PVC
kubectl delete pvc my-pvc -n default

# PVC с Retain policy не удалит PV автоматически
```

### Удаление PV

```bash
# Просмотреть PV
kubectl get pv

# Удалить PV
kubectl delete pv my-pv

# Если PV заблокирован
kubectl patch pv my-pv -p '{"metadata":{"finalizers":[]}}'
```

## Очистка Secrets и ConfigMaps

### Удаление Secrets

```bash
# Удалить секрет
kubectl delete secret my-secret -n default

# Массовое удаление
kubectl get secrets -n default -o name | grep my-prefix | xargs kubectl delete
```

### Удаление ConfigMaps

```bash
# Удалить ConfigMap
kubectl delete configmap my-config -n default
```

## Очистка репозиториев

### Удаление репозитория

```bash
# Удалить репозиторий
argocd repo rm https://github.com/org/repo.git

# Удалить через UI
# Settings > Repositories > Delete
```

### Очистка кэша репозитория

```bash
# Очистить кэш репозитория
argocd repo get https://github.com/org/repo.git

# Принудительное обновление
argocd app get nginx-app --refresh
```

## Очистка проектов

### Удаление проекта

```bash
# Удалить проект
argocd proj delete my-project

# Удалить через YAML
kubectl delete appproject my-project -n argocd
```

### Очистка перед удалением проекта

```bash
# 1. Удалить все приложения в проекте
argocd app list --project my-project -o name | xargs -I {} argocd app delete {} --cascade

# 2. Удалить проект
argocd proj delete my-project
```

## Best Practices для Cleanup

### 1. Всегда используйте Cascade

```bash
# Правильно: удалять с ресурсами
argocd app delete nginx-app --cascade

# Неправильно: оставлять ресурсы в кластере
argocd app delete nginx-app
```

### 2. Проверяйте зависимости

```bash
# Проверить зависимости перед удалением
argocd app get nginx-app --show-tree

# Убедиться, что нет зависимых ресурсов
```

### 3. Используйте Prune для автоматической очистки

```yaml
spec:
  syncPolicy:
    automated:
      prune: true  # Автоматически удалять лишние ресурсы
```

### 4. Очищайте в правильном порядке

```bash
# 1. Удалить приложения
# 2. Удалить проекты
# 3. Удалить репозитории
# 4. Очистить namespace
```

### 5. Документируйте процесс

```bash
# Создать скрипт для очистки
#!/bin/bash
# cleanup.sh
argocd app delete app1 --cascade --yes
argocd app delete app2 --cascade --yes
kubectl delete namespace my-namespace
```

## Практическое задание

### Задание 1: Удаление приложения

1. Создайте тестовое приложение
2. Удалите его через CLI с cascade
3. Проверьте, что все ресурсы удалены
4. Попробуйте удалить через UI

### Задание 2: Очистка ресурсов

1. Создайте приложение с несколькими ресурсами
2. Удалите один ресурс из Git
3. Включите prune и синхронизируйте
4. Проверьте, что ресурс удален из кластера

### Задание 3: Управление Finalizers

1. Создайте приложение
2. Попробуйте удалить его с блокирующим finalizer
3. Безопасно удалите finalizer
4. Завершите удаление

### Задание 4: Массовая очистка

1. Создайте несколько тестовых приложений
2. Напишите скрипт для их удаления
3. Выполните массовую очистку
4. Проверьте, что все ресурсы удалены

## Резюме

В этой главе вы:
- Научились правильно удалять приложения
- Освоили очистку ресурсов
- Изучили управление finalizers
- Узнали best practices для cleanup

В следующей главе мы изучим работу с Helm.

## Дополнительные материалы

- [Application Deletion](https://argo-cd.readthedocs.io/en/stable/user-guide/application-management/#deleting-applications)
- [Finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/)
- [Garbage Collection](https://kubernetes.io/docs/concepts/architecture/garbage-collection/)
