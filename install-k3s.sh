#!/bin/bash

# Установка UTF-8 кодировки для корректного отображения русского текста
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

set -e

echo "========================================="
echo "РЈСЃС‚Р°РЅРѕРІРєР° k3s"
echo "========================================="

# РћР±РЅРѕРІР»РµРЅРёРµ СЃРёСЃС‚РµРјС‹
echo "РћР±РЅРѕРІР»РµРЅРёРµ СЃРёСЃС‚РµРјС‹..."
sudo apt-get update -y
sudo apt-get upgrade -y

# РЈСЃС‚Р°РЅРѕРІРєР° РЅРµРѕР±С…РѕРґРёРјС‹С… РїР°РєРµС‚РѕРІ
echo "РЈСЃС‚Р°РЅРѕРІРєР° РЅРµРѕР±С…РѕРґРёРјС‹С… РїР°РєРµС‚РѕРІ..."
sudo apt-get install -y curl wget

# РЈСЃС‚Р°РЅРѕРІРєР° k3s
echo "РЈСЃС‚Р°РЅРѕРІРєР° k3s..."
curl -sfL https://get.k3s.io | sh -

# РћР¶РёРґР°РЅРёРµ РіРѕС‚РѕРІРЅРѕСЃС‚Рё k3s
echo "РћР¶РёРґР°РЅРёРµ РіРѕС‚РѕРІРЅРѕСЃС‚Рё k3s..."
sudo systemctl status k3s --no-pager || true
sleep 10

# РџСЂРѕРІРµСЂРєР° СѓСЃС‚Р°РЅРѕРІРєРё
echo "РџСЂРѕРІРµСЂРєР° СѓСЃС‚Р°РЅРѕРІРєРё k3s..."
sudo k3s kubectl get nodes

# РЎРѕС…СЂР°РЅРµРЅРёРµ kubeconfig РґР»СЏ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ
echo "РќР°СЃС‚СЂРѕР№РєР° kubeconfig..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# Р”РѕР±Р°РІР»РµРЅРёРµ KUBECONFIG РІ PATH
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
export KUBECONFIG=~/.kube/config

echo "========================================="
echo "k3s СѓСЃРїРµС€РЅРѕ СѓСЃС‚Р°РЅРѕРІР»РµРЅ!"
echo "========================================="
echo "Р”Р»СЏ РёСЃРїРѕР»СЊР·РѕРІР°РЅРёСЏ kubectl РІС‹РїРѕР»РЅРёС‚Рµ:"
echo "export KUBECONFIG=~/.kube/config"
echo "РёР»Рё РїРµСЂРµР·Р°РїСѓСЃС‚РёС‚Рµ С‚РµСЂРјРёРЅР°Р»"
