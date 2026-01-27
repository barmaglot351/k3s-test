# Глава 3: Базовые операции

## Цели главы

После изучения этой главы вы:
- Создадите первое приложение в ArgoCD
- Научитесь синхронизировать приложения
- Освоите работу с UI и CLI
- Изучите основные команды ArgoCD

## Создание первого приложения

### Подготовка Git-репозитория

Перед созданием приложения подготовьте Git-репозиторий с Kubernetes-манифестами:

```yaml
# example-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
---
# example-app/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

### Создание приложения через CLI

```bash
# Создать приложение
argocd app create nginx-app \
  --repo https://github.com/your-org/your-repo.git \
  --path example-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy manual

# Проверить статус
argocd app get nginx-app
```

### Создание приложения через YAML

```yaml
# nginx-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: HEAD
    path: example-app
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    automated:
      prune: true
      selfHeal: true
```

```bash
# Применить манифест
kubectl apply -f nginx-app.yaml

# Проверить статус
argocd app get nginx-app
```

### Создание приложения через UI

1. Откройте веб-интерфейс ArgoCD
2. Нажмите "New App"
3. Заполните форму:
   - **Application Name**: nginx-app
   - **Project Name**: default
   - **Sync Policy**: Manual или Automatic
4. В разделе **Source**:
   - **Repository URL**: https://github.com/your-org/your-repo.git
   - **Revision**: HEAD
   - **Path**: example-app
5. В разделе **Destination**:
   - **Cluster URL**: https://kubernetes.default.svc
   - **Namespace**: default
6. Нажмите "Create"

## Синхронизация приложений

### Ручная синхронизация

```bash
# Синхронизировать приложение
argocd app sync nginx-app

# Синхронизировать с принудительным обновлением
argocd app sync nginx-app --force

# Синхронизировать с заменой ресурсов
argocd app sync nginx-app --replace

# Синхронизировать только определенные ресурсы
argocd app sync nginx-app --resource Service:default/nginx-service
```

### Автоматическая синхронизация

```yaml
# Приложение с автоматической синхронизацией
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-app
  namespace: argocd
spec:
  syncPolicy:
    automated:
      prune: true      # Удалять ресурсы, отсутствующие в Git
      selfHeal: true   # Автоматически исправлять отклонения
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
```

### Синхронизация через UI

1. Откройте приложение в UI
2. Нажмите кнопку "Sync"
3. Выберите опции синхронизации:
   - **Sync Strategy**: Normal, Replace, Apply
   - **Prune**: Удалить лишние ресурсы
   - **Dry Run**: Тестовый запуск
4. Нажмите "Synchronize"

## Работа с UI

### Основные разделы

#### Applications (Приложения)

- Список всех приложений
- Статус здоровья и синхронизации
- Быстрые действия (Sync, Refresh, Delete)

#### Application Details (Детали приложения)

- **Summary**: Общая информация
- **Resource Tree**: Дерево ресурсов
- **Manifest**: YAML-манифесты
- **Events**: События Kubernetes
- **Logs**: Логи подов
- **Network**: Сетевая топология

#### Projects (Проекты)

- Управление проектами
- Настройка разрешений
- Политики синхронизации

#### Settings (Настройки)

- **Repositories**: Git-репозитории
- **Clusters**: Kubernetes-кластеры
- **Accounts**: Пользователи и роли
- **GPG Keys**: GPG-ключи для подписи

### Полезные функции UI

- **Refresh**: Обновить статус приложения
- **Hard Refresh**: Принудительное обновление
- **Sync**: Синхронизировать приложение
- **Delete**: Удалить приложение
- **History**: История синхронизаций
- **Rollback**: Откат к предыдущей версии

## Работа с CLI

### Основные команды

#### Управление приложениями

```bash
# Список приложений
argocd app list

# Получить информацию о приложении
argocd app get nginx-app

# Создать приложение
argocd app create <app-name> [flags]

# Удалить приложение
argocd app delete nginx-app

# Обновить приложение
argocd app set nginx-app --sync-policy automated
```

#### Синхронизация

```bash
# Синхронизировать
argocd app sync nginx-app

# Отменить синхронизацию
argocd app terminate-op nginx-app

# История синхронизаций
argocd app history nginx-app

# Откат
argocd app rollback nginx-app <revision>
```

#### Мониторинг

```bash
# Статус приложения
argocd app get nginx-app

# Логи приложения
argocd app logs nginx-app

# События
argocd app events nginx-app

# Дерево ресурсов
argocd app resources nginx-app
```

#### Управление репозиториями

```bash
# Список репозиториев
argocd repo list

# Добавить репозиторий
argocd repo add https://github.com/user/repo.git

# Удалить репозиторий
argocd repo rm https://github.com/user/repo.git
```

#### Управление проектами

```bash
# Список проектов
argocd proj list

# Создать проект
argocd proj create my-project

# Получить информацию о проекте
argocd proj get my-project
```

### Полезные флаги

```bash
# Вывод в формате YAML
argocd app get nginx-app -o yaml

# Вывод в формате JSON
argocd app get nginx-app -o json

# Широкий вывод
argocd app list -o wide

# Фильтрация
argocd app list --project default
```

## Статусы приложений

### Health Status (Статус здоровья)

```bash
# Проверить статус здоровья
argocd app get nginx-app | grep Health

# Возможные значения:
# - Healthy: Приложение работает корректно
# - Progressing: Приложение обновляется
# - Degraded: Приложение работает, но не оптимально
# - Suspended: Приложение приостановлено
# - Missing: Ресурсы отсутствуют
# - Unknown: Статус неизвестен
```

### Sync Status (Статус синхронизации)

```bash
# Проверить статус синхронизации
argocd app get nginx-app | grep Sync

# Возможные значения:
# - Synced: Синхронизировано с Git
# - OutOfSync: Есть различия
# - Unknown: Статус неизвестен
```

## Обновление приложений

### Обновление через Git

```bash
# 1. Внести изменения в Git-репозиторий
git add .
git commit -m "Update nginx version"
git push

# 2. ArgoCD автоматически обнаружит изменения (если включена автоматическая синхронизация)
# Или синхронизировать вручную
argocd app sync nginx-app
```

### Обновление параметров приложения

```bash
# Изменить параметры приложения
argocd app set nginx-app \
  --sync-policy automated \
  --sync-option CreateNamespace=true

# Обновить репозиторий
argocd app set nginx-app \
  --repo https://github.com/new-repo.git \
  --path new-path
```

## Удаление приложений

### Удаление через CLI

```bash
# Удалить приложение (без удаления ресурсов)
argocd app delete nginx-app

# Удалить приложение с ресурсами
argocd app delete nginx-app --cascade

# Удалить приложение с подтверждением
argocd app delete nginx-app --yes
```

### Удаление через UI

1. Откройте приложение
2. Нажмите "Delete"
3. Выберите опции:
   - **Cascade**: Удалить ресурсы в кластере
4. Подтвердите удаление

## Практическое задание

### Задание 1: Создание первого приложения

1. Создайте Git-репозиторий с простым приложением (nginx)
2. Добавьте репозиторий в ArgoCD
3. Создайте приложение через CLI
4. Проверьте статус приложения

### Задание 2: Работа с синхронизацией

1. Внесите изменения в манифесты в Git
2. Синхронизируйте приложение вручную
3. Проверьте, что изменения применились
4. Настройте автоматическую синхронизацию

### Задание 3: Изучение UI

1. Откройте приложение в UI
2. Изучите все разделы (Summary, Resource Tree, Manifest, Events)
3. Выполните синхронизацию через UI
4. Просмотрите логи подов

### Задание 4: Работа с CLI

1. Используйте CLI для получения информации о приложении
2. Выполните синхронизацию через CLI
3. Просмотрите историю синхронизаций
4. Попробуйте различные форматы вывода (yaml, json)

## Резюме

В этой главе вы:
- Создали первое приложение в ArgoCD
- Научились синхронизировать приложения вручную и автоматически
- Освоили работу с UI и CLI
- Изучили основные команды и операции

В следующей главе мы углубимся в управление приложениями и их жизненный цикл.

## Дополнительные материалы

- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)
- [Application Resource](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications)
- [Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-policies/)
