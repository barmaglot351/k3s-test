#!/bin/bash

set -e

echo "========================================="
echo "Полная установка k3s, Helm и ArgoCD"
echo "========================================="

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Шаг 1: Установка k3s
echo -e "${GREEN}[1/3]${NC} Установка k3s..."
bash install-k3s.sh

# Настройка переменной окружения для kubectl
export KUBECONFIG=~/.kube/config

# Шаг 2: Установка Helm
echo -e "${GREEN}[2/3]${NC} Установка Helm..."
bash install-helm.sh

# Шаг 3: Установка ArgoCD
echo -e "${GREEN}[3/3]${NC} Установка ArgoCD..."
bash install-argocd.sh

# Применение дополнительной конфигурации ingress (если нужно)
echo "Применение конфигурации ingress..."
kubectl apply -f argocd-ingress.yaml || echo "Ingress уже настроен через Helm"

echo ""
echo "========================================="
echo -e "${GREEN}Установка завершена!${NC}"
echo "========================================="
echo ""
echo "Для доступа к ArgoCD:"
echo "  URL: https://argocd.lab.local:30443"
echo "  Имя пользователя: admin"
echo "  Пароль: (см. вывод выше или выполните:)"
echo "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "Для получения пароля выполните:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
