# Глава 9: Работа с Helm

## Цели главы

После изучения этой главы вы:
- Поймете интеграцию Helm с ArgoCD
- Научитесь работать с Helm Charts
- Освоите управление зависимостями
- Изучите параметризацию Helm

## Интеграция Helm с ArgoCD

### Что такое Helm?

**Helm** — это менеджер пакетов для Kubernetes, который упрощает установку и управление приложениями через Charts.

### Преимущества использования Helm в ArgoCD

- ✅ Переиспользование Charts
- ✅ Параметризация через values
- ✅ Управление зависимостями
- ✅ Версионирование релизов
- ✅ Шаблонизация манифестов

## Создание Helm приложения

### Базовое Helm приложение

```yaml
# helm-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-helm-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 13.2.0
    helm:
      releaseName: nginx
      valueFiles:
      - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Создание через CLI

```bash
# Создать Helm приложение
argocd app create nginx-helm-app \
  --repo https://charts.bitnami.com/bitnami \
  --chart nginx \
  --revision 13.2.0 \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --helm-set service.type=LoadBalancer
```

## Работа с Helm Charts

### Использование публичных Charts

```yaml
spec:
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 13.2.0
```

### Использование приватных Charts

```bash
# Добавить приватный Helm репозиторий
argocd repo add https://charts.example.com \
  --type helm \
  --name my-helm-repo \
  --username myuser \
  --password mypass
```

```yaml
spec:
  source:
    repoURL: https://charts.example.com
    chart: my-chart
    targetRevision: 1.0.0
```

### Использование Charts из Git

```yaml
spec:
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: charts/my-chart
    helm:
      valueFiles:
      - values.yaml
```

## Параметризация через Values

### Values файлы

```yaml
# values.yaml в Git репозитории
replicaCount: 3
image:
  repository: nginx
  tag: "1.21"
service:
  type: ClusterIP
  port: 80
```

```yaml
# Приложение с values файлом
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: charts/my-chart
    helm:
      valueFiles:
      - values.yaml
```

### Переопределение values через CLI

```bash
# Установить значение
argocd app set nginx-helm-app \
  --helm-set replicaCount=5

# Установить несколько значений
argocd app set nginx-helm-app \
  --helm-set replicaCount=5 \
  --helm-set service.type=LoadBalancer

# Установить вложенное значение
argocd app set nginx-helm-app \
  --helm-set image.tag=1.22
```

### Переопределение values через YAML

```yaml
spec:
  source:
    helm:
      values: |
        replicaCount: 5
        service:
          type: LoadBalancer
          port: 80
        image:
          tag: "1.22"
```

### Использование нескольких values файлов

```yaml
spec:
  source:
    helm:
      valueFiles:
      - values.yaml
      - values-production.yaml
      - values-override.yaml
```

## Управление зависимостями

### Helm зависимости

```yaml
# Chart.yaml
apiVersion: v2
name: my-app
version: 1.0.0
dependencies:
  - name: postgresql
    version: "11.0.0"
    repository: https://charts.bitnami.com/bitnami
  - name: redis
    version: "16.0.0"
    repository: https://charts.bitnami.com/bitnami
```

### Обновление зависимостей

```bash
# В директории Chart
helm dependency update

# Закоммитить обновленные зависимости
git add charts/
git commit -m "Update Helm dependencies"
git push
```

### Использование зависимостей в ArgoCD

ArgoCD автоматически обрабатывает Helm зависимости:

```yaml
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: charts/my-app
    helm:
      # Зависимости будут разрешены автоматически
```

## Версионирование Helm релизов

### Управление версиями Chart

```yaml
spec:
  source:
    chart: nginx
    targetRevision: 13.2.0  # Конкретная версия
    # или
    targetRevision: ^13.0.0  # Семантическое версионирование
```

### Обновление версии

```bash
# Обновить версию Chart
argocd app set nginx-helm-app \
  --revision 13.3.0

# Или через Git
# Обновить targetRevision в манифесте приложения
```

## Helm Hooks в ArgoCD

### Pre-install Hook

```yaml
# templates/pre-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-install-job
  annotations:
    "helm.sh/hook": pre-install
spec:
  template:
    spec:
      containers:
      - name: setup
        image: busybox
        command: ['sh', '-c', 'echo "Pre-install setup"']
      restartPolicy: Never
```

### Post-install Hook

```yaml
# templates/post-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: post-install-job
  annotations:
    "helm.sh/hook": post-install
spec:
  # ...
```

ArgoCD автоматически обрабатывает Helm hooks при синхронизации.

## Helm Secrets

### Управление секретами

```yaml
# values.yaml
database:
  password: "{{ .Values.dbPassword }}"
```

```yaml
# Приложение с секретом
spec:
  source:
    helm:
      values: |
        database:
          password: $dbPassword
      parameters:
      - name: dbPassword
        value: secret:argocd/my-secret#password
```

### Использование External Secrets

```yaml
spec:
  source:
    helm:
      values: |
        database:
          password: $dbPassword
      parameters:
      - name: dbPassword
        valueFrom:
          secretKeyRef:
            name: my-secret
            key: password
```

## Продвинутые техники

### Использование Helm с Kustomize

```yaml
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: charts/my-chart
    helm:
      valueFiles:
      - values.yaml
    kustomize:
      # Kustomize патчи поверх Helm
      patches:
      - path: patches/deployment-patch.yaml
```

### Multi-environment setup

```yaml
# values-dev.yaml
replicaCount: 1
image:
  tag: "dev"

# values-prod.yaml
replicaCount: 5
image:
  tag: "prod"
```

```yaml
# dev-app.yaml
spec:
  source:
    helm:
      valueFiles:
      - values.yaml
      - values-dev.yaml
```

```yaml
# prod-app.yaml
spec:
  source:
    helm:
      valueFiles:
      - values.yaml
      - values-prod.yaml
```

## Troubleshooting Helm

### Проблемы с зависимостями

```bash
# Проверить зависимости
helm dependency list

# Обновить зависимости
helm dependency update

# Проверить Chart
helm lint .
```

### Проблемы с values

```bash
# Отобразить сгенерированные values
argocd app get nginx-helm-app --show-params

# Проверить сгенерированные манифесты
argocd app manifests nginx-helm-app
```

### Логи Helm операций

```bash
# Логи repo-server (обрабатывает Helm)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Логи синхронизации
argocd app logs nginx-helm-app
```

## Практическое задание

### Задание 1: Базовое Helm приложение

1. Создайте приложение с публичным Helm Chart (например, nginx)
2. Настройте values через файл
3. Разверните приложение
4. Проверьте работу

### Задание 2: Параметризация

1. Создайте Helm Chart с параметрами
2. Используйте values файлы
3. Переопределите значения через CLI
4. Проверьте применение параметров

### Задание 3: Зависимости

1. Создайте Chart с зависимостями
2. Обновите зависимости
3. Разверните через ArgoCD
4. Проверьте установку зависимостей

### Задание 4: Multi-environment

1. Создайте values файлы для dev и prod
2. Создайте приложения для каждого окружения
3. Разверните оба окружения
4. Сравните различия

## Резюме

В этой главе вы:
- Поняли интеграцию Helm с ArgoCD
- Научились работать с Helm Charts
- Освоили управление зависимостями
- Изучили параметризацию Helm

В следующей главе мы изучим работу с Kustomize.

## Дополнительные материалы

- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Helm Support](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
