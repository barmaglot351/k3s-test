# Глава 10: Работа с Kustomize

## Цели главы

После изучения этой главы вы:
- Поймете концепции Kustomize
- Научитесь создавать базовые и оверлейные конфигурации
- Освоите патчи и трансформации
- Изучите многоокруженные развертывания

## Что такое Kustomize?

**Kustomize** — это инструмент для кастомизации Kubernetes-манифестов без шаблонов. Он позволяет создавать варианты базовых конфигураций для разных окружений.

### Преимущества Kustomize

- ✅ Декларативный подход
- ✅ Переиспользование манифестов
- ✅ Без шаблонов
- ✅ Встроен в kubectl
- ✅ Поддержка патчей

## Базовые конфигурации

### Структура базовой конфигурации

```
base/
├── kustomization.yaml
├── deployment.yaml
├── service.yaml
└── configmap.yaml
```

### kustomization.yaml

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

commonLabels:
  app: nginx
  version: v1

namespace: default
```

### Базовые ресурсы

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
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
```

## Оверлейные конфигурации

### Структура оверлеев

```
.
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patch-replicas.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── patch-replicas.yaml
```

### Dev оверлей

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namespace: dev

patchesStrategicMerge:
- patch-replicas.yaml

commonLabels:
  environment: dev
```

```yaml
# overlays/dev/patch-replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1  # Меньше реплик для dev
```

### Prod оверлей

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namespace: production

patchesStrategicMerge:
- patch-replicas.yaml
- patch-resources.yaml

commonLabels:
  environment: production
```

```yaml
# overlays/prod/patch-replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 5  # Больше реплик для prod
```

## Создание Kustomize приложения в ArgoCD

### Базовое приложение

```yaml
# kustomize-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-kustomize-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: base
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
```

### Приложение с оверлеем

```yaml
# dev-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-dev-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: overlays/dev  # Использовать dev оверлей
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
```

## Патчи и трансформации

### Strategic Merge Patches

```yaml
# patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.22  # Обновить образ
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
```

```yaml
# kustomization.yaml
patchesStrategicMerge:
- patch.yaml
```

### JSON Patches

```yaml
# kustomization.yaml
patches:
- target:
    kind: Deployment
    name: nginx
  path: json-patch.yaml
```

```yaml
# json-patch.yaml
- op: replace
  path: /spec/replicas
  value: 5
- op: add
  path: /spec/template/spec/containers/0/env
  value:
  - name: ENV
    value: production
```

### Inline Patches

```yaml
# kustomization.yaml
patches:
- target:
    kind: Deployment
    name: nginx
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 5
```

## Трансформации

### Images

```yaml
# kustomization.yaml
images:
- name: nginx
  newName: my-registry.com/nginx
  newTag: 1.22
```

### Replicas

```yaml
# kustomization.yaml
replicas:
- name: nginx
  count: 5
```

### Name Prefix/Suffix

```yaml
# kustomization.yaml
namePrefix: dev-
nameSuffix: -v1
```

### Common Labels/Annotations

```yaml
# kustomization.yaml
commonLabels:
  app: nginx
  environment: dev
commonAnnotations:
  description: "Development environment"
```

### Namespace

```yaml
# kustomization.yaml
namespace: my-namespace
```

## Переменные (Variables)

### Использование переменных

```yaml
# kustomization.yaml
vars:
- name: IMAGE_TAG
  objref:
    kind: ConfigMap
    name: app-config
    apiVersion: v1
  fieldref:
    fieldpath: data.imageTag
```

```yaml
# deployment.yaml
spec:
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:$(IMAGE_TAG)
```

## Многоокруженные развертывания

### Структура для нескольких окружений

```
.
├── base/
│   ├── kustomization.yaml
│   └── ...
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
```

### Создание приложений для каждого окружения

```yaml
# dev-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-dev
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: overlays/dev
  destination:
    namespace: dev
---
# staging-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-staging
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: overlays/staging
  destination:
    namespace: staging
---
# prod-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-prod
spec:
  source:
    repoURL: https://github.com/org/repo.git
    path: overlays/prod
  destination:
    namespace: production
```

## Комбинация Kustomize с Helm

### Kustomize поверх Helm

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
- name: nginx
  repo: https://charts.bitnami.com/bitnami
  version: 13.2.0
  releaseName: nginx

patchesStrategicMerge:
- patch.yaml
```

## Best Practices

### 1. Используйте базовые конфигурации

```
base/
├── kustomization.yaml
└── resources/
    ├── deployment.yaml
    └── service.yaml
```

### 2. Минимизируйте дублирование

Используйте оверлеи вместо копирования манифестов.

### 3. Используйте патчи для изменений

```yaml
# Вместо полного переопределения
patchesStrategicMerge:
- patch.yaml
```

### 4. Версионируйте оверлеи

```yaml
commonLabels:
  version: v1.0.0
```

### 5. Документируйте структуру

```yaml
# kustomization.yaml
# Этот оверлей настраивает production окружение
# Использует 5 реплик и production namespace
```

## Troubleshooting

### Проблемы с путями

```bash
# Проверить структуру
kubectl kustomize base/

# Проверить оверлей
kubectl kustomize overlays/dev/
```

### Проблемы с патчами

```bash
# Просмотреть сгенерированные манифесты
kubectl kustomize overlays/dev/

# Проверить синтаксис
kubectl kustomize overlays/dev/ --dry-run
```

### Проблемы в ArgoCD

```bash
# Просмотреть сгенерированные манифесты
argocd app manifests nginx-kustomize-app

# Проверить логи repo-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## Практическое задание

### Задание 1: Базовая конфигурация

1. Создайте базовую Kustomize конфигурацию
2. Включите deployment, service, configmap
3. Создайте приложение в ArgoCD
4. Разверните и проверьте

### Задание 2: Оверлеи

1. Создайте dev и prod оверлеи
2. Настройте разные значения для каждого окружения
3. Создайте приложения для каждого окружения
4. Разверните оба окружения

### Задание 3: Патчи

1. Создайте strategic merge патч
2. Создайте JSON патч
3. Примените оба патча
4. Проверьте результат

### Задание 4: Трансформации

1. Используйте трансформации images
2. Примените namePrefix и nameSuffix
3. Добавьте commonLabels
4. Проверьте применение трансформаций

## Резюме

В этой главе вы:
- Поняли концепции Kustomize
- Научились создавать базовые и оверлейные конфигурации
- Освоили патчи и трансформации
- Изучили многоокруженные развертывания

В следующей главе мы изучим управление секретами.

## Дополнительные материалы

- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Kustomize Support](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [Kustomize Best Practices](https://github.com/kubernetes-sigs/kustomize/blob/master/docs/eschewedFeatures.md)
