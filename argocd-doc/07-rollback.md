# Глава 7: Откат приложений

## Цели главы

После изучения этой главы вы:
- Научитесь выполнять ручной откат приложений
- Освоите автоматический откат
- Изучите историю версий
- Научитесь восстанавливать состояние приложений

## Ручной откат

### Откат через CLI

```bash
# Просмотр истории синхронизаций
argocd app history nginx-app

# Откат к предыдущей версии
argocd app rollback nginx-app <revision-id>

# Откат к конкретному коммиту
argocd app rollback nginx-app abc123def

# Откат с подтверждением
argocd app rollback nginx-app <revision-id> --yes
```

### Откат через UI

1. Откройте приложение в UI
2. Перейдите в раздел "History"
3. Выберите версию для отката
4. Нажмите "Rollback"
5. Подтвердите откат

### Откат через Git

```bash
# 1. Найти коммит для отката
git log --oneline

# 2. Вернуться к предыдущему коммиту в Git
git checkout <previous-commit-hash>

# 3. Обновить манифесты приложения
# (если нужно изменить targetRevision)

# 4. Закоммитить изменения
git add .
git commit -m "Rollback to previous version"
git push

# 5. Синхронизировать приложение
argocd app sync nginx-app
```

## Автоматический откат

### Настройка автоматического отката

ArgoCD может автоматически откатывать приложения при обнаружении проблем.

```yaml
# Приложение с автоматическим откатом
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5        # Максимум попыток
      backoff:
        duration: 5s  # Задержка между попытками
        factor: 2     # Множитель задержки
        maxDuration: 3m
```

### Health-based откат

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - RespectIgnoreDifferences=true
    retry:
      limit: 3
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 1m
```

## История версий

### Просмотр истории

```bash
# Полная история
argocd app history nginx-app

# История с деталями
argocd app history nginx-app -o wide

# История в формате JSON
argocd app history nginx-app -o json
```

### Формат вывода истории

```
ID  DATE                           REVISION                              SOURCE
0   2024-01-15 10:30:45 +0000 UTC  abc123def (main)                     https://github.com/org/repo.git
1   2024-01-15 11:15:20 +0000 UTC  def456ghi (main)                     https://github.com/org/repo.git
2   2024-01-15 12:00:10 +0000 UTC  ghi789jkl (main)                     https://github.com/org/repo.git
```

### Детали синхронизации

```bash
# Детали конкретной синхронизации
argocd app history nginx-app --id 2

# Информация включает:
# - ID синхронизации
# - Дата и время
# - Ревизия Git
# - Источник
# - Результат синхронизации
# - Измененные ресурсы
```

## Восстановление состояния

### Восстановление из Git

```bash
# 1. Найти рабочую версию в Git
git log --oneline --all

# 2. Проверить содержимое коммита
git show <commit-hash>:path/to/manifests

# 3. Обновить приложение на эту версию
argocd app set nginx-app --revision <commit-hash>

# 4. Синхронизировать
argocd app sync nginx-app
```

### Восстановление через откат

```bash
# 1. Просмотреть историю
argocd app history nginx-app

# 2. Найти рабочую версию
# 3. Выполнить откат
argocd app rollback nginx-app <revision-id>
```

### Восстановление ресурсов

Если ресурсы были удалены или изменены вручную:

```bash
# 1. Проверить текущее состояние
argocd app get nginx-app

# 2. Если статус OutOfSync, синхронизировать
argocd app sync nginx-app

# 3. Если нужно восстановить удаленные ресурсы
argocd app sync nginx-app --replace
```

## Откат с сохранением данных

### StatefulSet откат

При откате StatefulSet важно сохранить данные:

```yaml
# StatefulSet с PersistentVolume
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 1
  template:
    spec:
      containers:
      - name: db
        image: postgres:13  # Откатить на предыдущую версию
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

```bash
# Откат StatefulSet
argocd app rollback database-app <revision-id>

# Данные в PersistentVolume сохранятся
```

## Откат с проверками

### Pre-rollback проверки

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
spec:
  syncPolicy:
    hook:
      preSync:
        - name: pre-rollback-check
          job:
            spec:
              template:
                spec:
                  containers:
                  - name: check
                    image: busybox
                    command: ['sh', '-c', 'echo "Pre-rollback check"']
                  restartPolicy: Never
```

### Post-rollback проверки

```yaml
spec:
  syncPolicy:
    hook:
      postSync:
        - name: post-rollback-verification
          job:
            spec:
              template:
                spec:
                  containers:
                  - name: verify
                    image: curlimages/curl
                    command: ['curl', '-f', 'http://nginx-service/health']
                  restartPolicy: Never
```

## Откат Helm приложений

### Откат Helm релиза

```bash
# Просмотр истории Helm релиза
helm history nginx-release

# Откат через Helm
helm rollback nginx-release <revision>

# Откат через ArgoCD
argocd app rollback nginx-app <revision-id>
```

### Helm история в ArgoCD

```bash
# ArgoCD сохраняет историю Helm релизов
argocd app history nginx-app

# Каждая синхронизация Helm создает новую запись в истории
```

## Откат нескольких приложений

### Откат App of Apps

```bash
# Если используется App of Apps pattern
# Откат родительского приложения откатит дочерние

# 1. Просмотреть дочерние приложения
argocd app list --app-parent nginx-app

# 2. Откатить родительское приложение
argocd app rollback nginx-app <revision-id>

# 3. Дочерние приложения будут синхронизированы
```

### Массовый откат

```bash
# Откатить несколько приложений
for app in app1 app2 app3; do
  argocd app rollback $app <revision-id>
done
```

## Мониторинг отката

### Отслеживание процесса отката

```bash
# Мониторинг в реальном времени
watch -n 1 'argocd app get nginx-app'

# Или через UI
# Открыть приложение и следить за статусом
```

### Логи отката

```bash
# Логи синхронизации
argocd app logs nginx-app --follow

# События
argocd app events nginx-app
```

## Практическое задание

### Задание 1: Ручной откат

1. Создайте приложение и выполните несколько обновлений
2. Просмотрите историю синхронизаций
3. Выполните откат к предыдущей версии через CLI
4. Проверьте, что откат выполнен успешно

### Задание 2: Откат через UI

1. Выполните откат через веб-интерфейс
2. Изучите процесс отката в UI
3. Проверьте изменения в кластере
4. Убедитесь, что приложение работает корректно

### Задание 3: Автоматический откат

1. Настройте автоматический откат при ошибках
2. Создайте проблемную версию приложения
3. Проверьте, что ArgoCD пытается откатить
4. Изучите логи и события

### Задание 4: Восстановление состояния

1. Вручную измените ресурсы в кластере
2. Используйте self-heal для восстановления
3. Выполните откат к известной рабочей версии
4. Проверьте целостность данных (если используется StatefulSet)

## Резюме

В этой главе вы:
- Научились выполнять ручной откат приложений
- Освоили автоматический откат
- Изучили историю версий
- Научились восстанавливать состояние приложений

В следующей главе мы изучим удаление и очистку ресурсов.

## Дополнительные материалы

- [Application Rollback](https://argo-cd.readthedocs.io/en/stable/user-guide/application-management/#rollback)
- [Sync History](https://argo-cd.readthedocs.io/en/stable/user-guide/application-management/#sync-history)
- [Retry Strategy](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-policies/#retry-strategy)
