# Глава 2: Подготовка окружения

## Цели главы

После изучения этой главы вы:
- Установите K3s на вашей системе
- Установите ArgoCD в кластер
- Настроите доступ к ArgoCD
- Выполните первоначальную конфигурацию

## Установка K3s

K3s — это облегченный дистрибутив Kubernetes, идеально подходящий для разработки и тестирования.

### Системные требования

- Linux, macOS или Windows (с WSL2)
- Минимум 512 MB RAM
- Минимум 1 CPU core
- Свободное место на диске: 1 GB+

### Установка K3s на Linux/macOS

#### Быстрая установка

```bash
# Установка K3s
curl -sfL https://get.k3s.io | sh -

# Проверка установки
sudo k3s kubectl get nodes
```

#### Установка с настройками

```bash
# Установка с отключением traefik (если планируете использовать другой ingress)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -

# Установка с указанием версии
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.28.0" sh -
```

### Установка K3s на Windows (WSL2)

```powershell
# В WSL2 (Ubuntu/Debian)
curl -sfL https://get.k3s.io | sh -

# Настройка kubectl для Windows
# Скопируйте kubeconfig из WSL в Windows
```

### Настройка kubectl

После установки K3s настройте kubectl:

```bash
# Linux/macOS
export KUBECONFIG=~/.kube/config
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config

# Проверка
kubectl get nodes
```

### Проверка кластера

```bash
# Проверить ноды
kubectl get nodes

# Проверить системные поды
kubectl get pods -n kube-system

# Проверить версию Kubernetes
kubectl version --short
```

## Установка ArgoCD

### Метод 1: Установка через манифесты

```bash
# Создать namespace для ArgoCD
kubectl create namespace argocd

# Установить ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Дождаться готовности всех подов
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
```

### Метод 2: Установка через Helm

```bash
# Добавить Helm репозиторий ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Установить ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer
```

### Проверка установки

```bash
# Проверить поды ArgoCD
kubectl get pods -n argocd

# Ожидаемый вывод:
# NAME                                                READY   STATUS    RESTARTS   AGE
# argocd-application-controller-0                     1/1     Running   0          2m
# argocd-applicationset-controller-6b8b5d4c5d-xxxxx   1/1     Running   0          2m
# argocd-dex-server-7d4b5c6d7e-xxxxx                  1/1     Running   0          2m
# argocd-redis-7d8b9c0d1e-xxxxx                       1/1     Running   0          2m
# argocd-repo-server-7f9a0b1c2d-xxxxx                1/1     Running   0          2m
# argocd-server-8a3b4c5d6e-xxxxx                      1/1     Running   0          2m

# Проверить сервисы
kubectl get svc -n argocd
```

## Настройка доступа к ArgoCD

### Получение пароля администратора

```bash
# Получить начальный пароль администратора
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Или через argocd CLI (если установлен)
argocd admin initial-password -n argocd
```

### Доступ через Port Forwarding

```bash
# Пробросить порт ArgoCD сервера
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Открыть в браузере
# https://localhost:8080
# Логин: admin
# Пароль: (из предыдущей команды)
```

### Настройка Ingress (опционально)

Если вы хотите получить доступ через доменное имя:

```yaml
# argocd-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  rules:
  - host: argocd.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
  tls:
  - hosts:
    - argocd.example.com
    secretName: argocd-secret
```

```bash
# Применить Ingress
kubectl apply -f argocd-ingress.yaml
```

### Изменение типа сервиса (для LoadBalancer)

Если у вас есть LoadBalancer:

```bash
# Изменить тип сервиса на LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Получить внешний IP
kubectl get svc argocd-server -n argocd
```

## Установка ArgoCD CLI

### Установка на Linux

```bash
# Скачать последнюю версию
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

# Установить
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
```

### Установка на macOS

```bash
# Через Homebrew
brew install argocd

# Или вручную
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-darwin-amd64
chmod +x /usr/local/bin/argocd
```

### Установка на Windows

```powershell
# Через Chocolatey
choco install argocd

# Или скачать вручную с GitHub Releases
```

### Вход через CLI

```bash
# Настроить сервер (если используете port-forward)
argocd login localhost:8080

# Или через Ingress
argocd login argocd.example.com

# Ввести логин и пароль при запросе
```

### Изменение пароля администратора

```bash
# Войти в ArgoCD
argocd login localhost:8080

# Изменить пароль
argocd account update-password
```

## Первоначальная конфигурация

### Настройка Git-репозитория

```bash
# Добавить Git-репозиторий через CLI
argocd repo add https://github.com/your-org/your-repo.git \
  --type git \
  --name my-repo

# Или через UI: Settings > Repositories > Connect Repo
```

### Создание первого проекта

```bash
# Создать проект через CLI
argocd proj create my-project \
  --description "Мой первый проект" \
  --src "https://github.com/your-org/your-repo.git" \
  --dest "https://kubernetes.default.svc,my-namespace"

# Или через UI: Settings > Projects > New Project
```

### Настройка RBAC

```yaml
# argocd-rbac-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:org-admin, applications, *, */*, allow
    p, role:org-admin, clusters, get, *, allow
    p, role:org-admin, repositories, get, *, allow
    p, role:org-admin, repositories, create, *, allow
    p, role:org-admin, repositories, update, *, allow
    p, role:org-admin, repositories, delete, *, allow
    g, admin, role:org-admin
```

```bash
# Применить конфигурацию RBAC
kubectl apply -f argocd-rbac-config.yaml
```

## Проверка работоспособности

### Тест через CLI

```bash
# Проверить версию
argocd version --client

# Проверить подключение к серверу
argocd cluster list

# Проверить репозитории
argocd repo list
```

### Тест через UI

1. Откройте веб-интерфейс ArgoCD
2. Войдите с учетными данными администратора
3. Проверьте разделы:
   - Applications
   - Projects
   - Settings > Repositories
   - Settings > Clusters

## Устранение неполадок

### Проблема: Поды не запускаются

```bash
# Проверить логи подов
kubectl logs -n argocd <pod-name>

# Проверить события
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Проверить ресурсы
kubectl describe pod <pod-name> -n argocd
```

### Проблема: Не могу подключиться к серверу

```bash
# Проверить статус сервиса
kubectl get svc argocd-server -n argocd

# Проверить порт-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Проверить логи сервера
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Проблема: Ошибки при добавлении репозитория

```bash
# Проверить доступность репозитория
kubectl exec -n argocd deployment/argocd-repo-server -- git ls-remote <repo-url>

# Проверить логи repo-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

## Практическое задание

### Задание 1: Установка K3s

1. Установите K3s на вашей системе
2. Настройте kubectl для работы с кластером
3. Проверьте, что кластер работает корректно

### Задание 2: Установка ArgoCD

1. Установите ArgoCD в кластер
2. Дождитесь готовности всех подов
3. Получите пароль администратора

### Задание 3: Настройка доступа

1. Настройте доступ к ArgoCD через port-forward или Ingress
2. Установите ArgoCD CLI
3. Войдите в ArgoCD через CLI и UI
4. Измените пароль администратора

### Задание 4: Первоначальная конфигурация

1. Добавьте Git-репозиторий в ArgoCD
2. Создайте первый проект
3. Проверьте работоспособность всех компонентов

## Резюме

В этой главе вы:
- Установили K3s и настроили kubectl
- Установили ArgoCD в кластер
- Настроили доступ к ArgoCD через UI и CLI
- Выполнили первоначальную конфигурацию

В следующей главе мы создадим первое приложение в ArgoCD и изучим базовые операции.

## Дополнительные материалы

- [K3s Installation Guide](https://docs.k3s.io/installation)
- [ArgoCD Installation Guide](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)
