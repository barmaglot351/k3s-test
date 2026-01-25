#!/bin/bash

set -e

echo "========================================="
echo "РџРѕР»РЅР°СЏ СѓСЃС‚Р°РЅРѕРІРєР° k3s, Helm Рё ArgoCD"
echo "========================================="

# Р¦РІРµС‚Р° РґР»СЏ РІС‹РІРѕРґР°
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# РЁР°Рі 1: РЈСЃС‚Р°РЅРѕРІРєР° k3s
echo -e "${GREEN}[1/3]${NC} РЈСЃС‚Р°РЅРѕРІРєР° k3s..."
bash install-k3s.sh

# РќР°СЃС‚СЂРѕР№РєР° РїРµСЂРµРјРµРЅРЅРѕР№ РѕРєСЂСѓР¶РµРЅРёСЏ РґР»СЏ kubectl
export KUBECONFIG=~/.kube/config

# РЁР°Рі 2: РЈСЃС‚Р°РЅРѕРІРєР° Helm
echo -e "${GREEN}[2/3]${NC} РЈСЃС‚Р°РЅРѕРІРєР° Helm..."
bash install-helm.sh

# РЁР°Рі 3: РЈСЃС‚Р°РЅРѕРІРєР° ArgoCD
echo -e "${GREEN}[3/3]${NC} РЈСЃС‚Р°РЅРѕРІРєР° ArgoCD..."
bash install-argocd.sh

# РџСЂРёРјРµРЅРµРЅРёРµ РґРѕРїРѕР»РЅРёС‚РµР»СЊРЅРѕР№ РєРѕРЅС„РёРіСѓСЂР°С†РёРё ingress (РµСЃР»Рё РЅСѓР¶РЅРѕ)
echo "РџСЂРёРјРµРЅРµРЅРёРµ РєРѕРЅС„РёРіСѓСЂР°С†РёРё ingress..."
kubectl apply -f argocd-ingress.yaml || echo "Ingress СѓР¶Рµ РЅР°СЃС‚СЂРѕРµРЅ С‡РµСЂРµР· Helm"

echo ""
echo "========================================="
echo -e "${GREEN}РЈСЃС‚Р°РЅРѕРІРєР° Р·Р°РІРµСЂС€РµРЅР°!${NC}"
echo "========================================="
echo ""
echo "Р”Р»СЏ РґРѕСЃС‚СѓРїР° Рє ArgoCD:"
echo "  URL: https://argocd.lab.local:30443"
echo "  РРјСЏ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ: admin"
echo "  РџР°СЂРѕР»СЊ: (СЃРј. РІС‹РІРѕРґ РІС‹С€Рµ РёР»Рё РІС‹РїРѕР»РЅРёС‚Рµ:)"
echo "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "Р”Р»СЏ РїРѕР»СѓС‡РµРЅРёСЏ РїР°СЂРѕР»СЏ РІС‹РїРѕР»РЅРёС‚Рµ:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
