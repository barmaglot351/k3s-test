#!/bin/bash

set -e

echo "========================================="
echo "Установка Helm"
echo "========================================="

# Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Ошибка: kubectl не найден. Установите k3s сначала."
    exit 1
fi

# Установка Helm
echo "Загрузка и установка Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Проверка установки
echo "Проверка установки Helm..."
helm version

echo "========================================="
echo "Helm успешно установлен!"
echo "========================================="
