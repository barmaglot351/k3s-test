# Глава 4: Управление приложениями

## Цели главы

После изучения этой главы вы:
- Поймете жизненный цикл приложения в ArgoCD
- Научитесь управлять ресурсами приложений
- Освоите работу с проектами
- Изучите настройку политик синхронизации

## Жизненный цикл приложения

### Этапы жизненного цикла

1. **Создание (Creation)**
   - Приложение создается в ArgoCD
   - Настраиваются параметры синхронизации
   - Устанавливается связь с Git-репозиторием

2. **Синхронизация (Sync)**
   - ArgoCD получает манифесты из Git
   - Сравнивает желаемое и фактическое состояние
   - Применяет изменения к кластеру

3. **Мониторинг (Monitoring)**
   - Отслеживание статуса здоровья
   - Мониторинг синхронизации
   - Генерация алертов

4. **Обновление (Update)**
   - Обнаружение изменений в Git
   - Применение обновлений
   - Проверка работоспособности

5. **Откат (Rollback)**
   - Возврат к предыдущей версии
   - Восстановление состояния

6. **Удаление (Deletion)**
   - Удаление приложения
   - Очистка ресурсов

## Управление ресурсами

### Просмотр ресурсов

```bash
# Список всех ресурсов приложения
argocd app resources nginx-app

# Детальная информация о ресурсе
argocd app resources nginx-app --kind Deployment --name nginx-deployment

# Дерево ресурсов
argocd app get nginx-app --show-tree
```

### Управление ресурсами через UI

1. Откройте приложение в UI
2. Перейдите в раздел "Resource Tree"
3. Вы увидите иерархию ресурсов:
   - Namespace
   - Deployment
   - ReplicaSet
   - Pods
   - Service
   - ConfigMap, Secret и т.д.

### Фильтрация ресурсов

```bash
# Фильтрация по типу
argocd app resources nginx-app --kind Deployment

# Фильтрация по namespace
argocd app resources nginx-app --namespace default

# Фильтрация по имени
argocd app resources nginx-app --name nginx-deployment
```

### Действия с ресурсами

```bash
# Получить манифест ресурса
argocd app resources nginx-app --kind Deployment --name nginx-deployment -o yaml

# Логи пода
argocd app logs nginx-app --kind Pod --name nginx-pod-xxx

# Описание ресурса
kubectl describe deployment nginx-deployment -n default
```

## Проекты (Projects)

### Что такое проект?

**Project** — это логическая группа приложений с общими:
- Разрешениями доступа
- Источниками репозиториев
- Политиками синхронизации
- Ограничениями ресурсов

### Создание проекта

```bash
# Создать проект через CLI
argocd proj create my-project \
  --description "Мой проект" \
  --src "https://github.com/org/*" \
  --dest "https://kubernetes.default.svc,default" \
  --dest "https://kubernetes.default.svc,production"
```

### Создание проекта через YAML

```yaml
# my-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: my-project
  namespace: argocd
spec:
  description: Мой проект для разработки
  sourceRepos:
  - 'https://github.com/org/*'
  - 'https://gitlab.com/org/*'
  destinations:
  - namespace: default
    server: https://kubernetes.default.svc
  - namespace: production
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
```

```bash
# Применить проект
kubectl apply -f my-project.yaml
```

### Настройка разрешений проекта

```yaml
# Проект с RBAC
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: my-project
  namespace: argocd
spec:
  roles:
  - name: developer
    description: Разработчик проекта
    policies:
    - p, proj:my-project:developer, applications, get, my-project/*, allow
    - p, proj:my-project:developer, applications, sync, my-project/*, allow
    groups:
    - developers
  - name: admin
    description: Администратор проекта
    policies:
    - p, proj:my-project:admin, applications, *, my-project/*, allow
    groups:
    - project-admins
```

### Привязка приложения к проекту

```bash
# При создании приложения
argocd app create nginx-app \
  --project my-project \
  --repo https://github.com/org/repo.git \
  --path app

# Или обновить существующее
argocd app set nginx-app --project my-project
```

## Политики синхронизации

### Типы политик

#### Manual Sync (Ручная синхронизация)

```yaml
spec:
  syncPolicy:
    # Политика не указана или syncPolicy отсутствует
    # Синхронизация только вручную
```

#### Automated Sync (Автоматическая синхронизация)

```yaml
spec:
  syncPolicy:
    automated:
      prune: true        # Удалять ресурсы, отсутствующие в Git
      selfHeal: true     # Автоматически исправлять отклонения
      allowEmpty: false   # Разрешить пустые приложения
```

#### Sync Options

```yaml
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true              # Создавать namespace автоматически
    - PrunePropagationPolicy=foreground # Политика удаления
    - PruneLast=true                    # Удалять в последнюю очередь
    - ApplyOutOfSyncOnly=true           # Применять только OutOfSync ресурсы
    - RespectIgnoreDifferences=true     # Учитывать ignoreDifferences
```

### Настройка политик через CLI

```bash
# Включить автоматическую синхронизацию
argocd app set nginx-app --sync-policy automated

# Включить prune
argocd app set nginx-app --sync-policy automated --auto-prune

# Включить self-heal
argocd app set nginx-app --sync-policy automated --self-heal

# Добавить sync options
argocd app set nginx-app --sync-option CreateNamespace=true
```

## Игнорирование различий

Иногда ArgoCD должен игнорировать определенные поля при сравнении:

```yaml
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
  - group: ""
    kind: Service
    jsonPointers:
    - /spec/clusterIP
  - group: ""
    kind: Secret
    jqPathExpressions:
    - .data
```

### Настройка через CLI

```bash
# Игнорировать поле replicas в Deployment
argocd app set nginx-app \
  --ignore-difference '{"group":"apps","kind":"Deployment","jsonPointers":["/spec/replicas"]}'
```

## Ограничения ресурсов

### Ограничения в проекте

```yaml
spec:
  namespaceResourceWhitelist:
  - group: ""
    kind: ConfigMap
  - group: ""
    kind: Secret
  - group: apps
    kind: Deployment
  clusterResourceWhitelist:
  - group: ""
    kind: Namespace
```

### Ограничения через CLI

```bash
# Ограничить типы ресурсов в проекте
argocd proj allow-cluster-resource my-project '*' '*'
argocd proj allow-namespace-resource my-project '*' '*'
```

## Health Checks

### Встроенные health checks

ArgoCD имеет встроенные health checks для:
- Deployment
- StatefulSet
- DaemonSet
- Service
- Ingress
- PersistentVolumeClaim
- и других

### Кастомные health checks

```yaml
# argocd-cm.yaml
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

## Sync Windows

### Настройка окон синхронизации

```yaml
spec:
  syncWindows:
  - kind: allow
    schedule: "10 1 * * *"  # Разрешить синхронизацию в 01:10
    duration: 1h             # В течение 1 часа
    applications:
    - nginx-app
  - kind: deny
    schedule: "* * * * *"   # Запретить в остальное время
```

### Управление через CLI

```bash
# Добавить окно синхронизации
argocd app windows add nginx-app \
  --kind allow \
  --schedule "10 1 * * *" \
  --duration 1h
```

## Практическое задание

### Задание 1: Управление ресурсами

1. Создайте приложение с несколькими ресурсами
2. Изучите дерево ресурсов в UI
3. Просмотрите ресурсы через CLI
4. Получите манифесты ресурсов

### Задание 2: Работа с проектами

1. Создайте новый проект
2. Настройте разрешения для проекта
3. Создайте приложение в этом проекте
4. Проверьте ограничения проекта

### Задание 3: Настройка политик

1. Настройте автоматическую синхронизацию
2. Включите prune и self-heal
3. Настройте sync options
4. Протестируйте работу политик

### Задание 4: Игнорирование различий

1. Создайте приложение с Deployment
2. Настройте игнорирование поля replicas
3. Измените replicas в кластере вручную
4. Проверьте, что ArgoCD игнорирует это изменение

## Резюме

В этой главе вы:
- Изучили жизненный цикл приложения
- Научились управлять ресурсами приложений
- Освоили работу с проектами
- Настроили политики синхронизации

В следующей главе мы изучим мониторинг приложений.

## Дополнительные материалы

- [Application Management](https://argo-cd.readthedocs.io/en/stable/user-guide/application-management/)
- [Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [Sync Policies](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-policies/)
