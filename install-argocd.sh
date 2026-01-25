#!/bin/bash

set -e

echo "========================================="
echo "Установка ArgoCD"
echo "========================================="

# Проверка наличия kubectl и helm
if ! command -v kubectl &> /dev/null; then
    echo "Ошибка: kubectl не найден. Установите k3s сначала."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "Ошибка: helm не найден. Установите Helm сначала."
    exit 1
fi

# Очистка предыдущих установок (если есть)
echo "Проверка и очистка предыдущих установок ArgoCD..."
if helm list -n argocd 2>/dev/null | grep -q "argocd"; then
    echo "Найден существующий релиз ArgoCD. Удаление..."
    helm uninstall argocd -n argocd || true
    sleep 5
fi

# Удаление сервиса argocd-server если он существует (может занимать порт)
echo "Проверка существующих сервисов ArgoCD..."
kubectl delete service argocd-server -n argocd --ignore-not-found=true || true
sleep 2

# Проверка занятости порта 30443
echo "Проверка доступности порта 30443..."
HTTPS_PORT=30443
if kubectl get svc --all-namespaces -o json | grep -q "\"nodePort\":$HTTPS_PORT"; then
    echo "Внимание: Порт 30443 уже занят другим сервисом."
    echo "Поиск альтернативного порта..."
    # Попробуем найти свободный порт в диапазоне 30443-30450
    for port in 30444 30445 30446 30447 30448 30449 30450; do
        if ! kubectl get svc --all-namespaces -o json | grep -q "\"nodePort\":$port"; then
            HTTPS_PORT=$port
            echo "Найден свободный порт: $HTTPS_PORT"
            break
        fi
    done
    if [ "$HTTPS_PORT" = "30443" ]; then
        echo "Не удалось найти свободный порт. Использование автоматического назначения порта..."
        HTTPS_PORT=""
    fi
fi

# Создание namespace для ArgoCD
echo "Создание namespace argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Добавление репозитория ArgoCD
echo "Добавление Helm репозитория ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm || true
echo "Обновление репозиториев Helm..."
helm repo update

# Создание временного values файла для аннотаций
if [ -n "$HTTPS_PORT" ]; then
cat > /tmp/argocd-values.yaml <<EOF
server:
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - argocd.lab.local
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.lab.local
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
      traefik.ingress.kubernetes.io/router.tls: "true"
  service:
    type: NodePort
    nodePortHttp: 30080
    nodePortHttps: $HTTPS_PORT
EOF
else
cat > /tmp/argocd-values.yaml <<EOF
server:
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - argocd.lab.local
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.lab.local
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
      traefik.ingress.kubernetes.io/router.tls: "true"
  service:
    type: NodePort
    nodePortHttp: 30080
EOF
fi

# Установка ArgoCD через Helm
echo "Установка ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values /tmp/argocd-values.yaml \
  --timeout 15m \
  --wait

# Удаление временного файла
rm -f /tmp/argocd-values.yaml

# Ожидание готовности подов
echo "Ожидание готовности ArgoCD..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || true

# Получение начального пароля администратора
echo "========================================="
echo "ArgoCD установлен!"
echo "========================================="
echo "Получение начального пароля администратора..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ""
echo "Имя пользователя: admin"
echo "Пароль: $ARGOCD_PASSWORD"
echo ""
# Получение фактического порта из сервиса
ACTUAL_HTTPS_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "30443")
if [ -n "$ACTUAL_HTTPS_PORT" ]; then
    echo "ArgoCD будет доступен по адресу: https://argocd.lab.local:$ACTUAL_HTTPS_PORT"
else
    echo "ArgoCD будет доступен через Ingress: https://argocd.lab.local"
    echo "Для прямого доступа через NodePort проверьте порт командой:"
    echo "  kubectl get svc argocd-server -n argocd"
fi
echo "========================================="
