#!/bin/bash

set -e

echo "========================================="
echo "Установка k3s"
echo "========================================="

# Обновление системы
echo "Обновление системы..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Установка необходимых пакетов
echo "Установка необходимых пакетов..."
sudo apt-get install -y curl wget

# Установка k3s
echo "Установка k3s..."
curl -sfL https://get.k3s.io | sh -

# Ожидание готовности k3s
echo "Ожидание готовности k3s..."
sudo systemctl status k3s --no-pager || true
sleep 10

# Проверка установки
echo "Проверка установки k3s..."
sudo k3s kubectl get nodes

# Сохранение kubeconfig для пользователя
echo "Настройка kubeconfig..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# Добавление KUBECONFIG в PATH
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
export KUBECONFIG=~/.kube/config

echo "========================================="
echo "k3s успешно установлен!"
echo "========================================="
echo "Для использования kubectl выполните:"
echo "export KUBECONFIG=~/.kube/config"
echo "или перезапустите терминал"
