#!/bin/bash

set -e

echo "========================================="
echo "РЈСЃС‚Р°РЅРѕРІРєР° ArgoCD"
echo "========================================="

# РџСЂРѕРІРµСЂРєР° РЅР°Р»РёС‡РёСЏ kubectl Рё helm
if ! command -v kubectl &> /dev/null; then
    echo "РћС€РёР±РєР°: kubectl РЅРµ РЅР°Р№РґРµРЅ. РЈСЃС‚Р°РЅРѕРІРёС‚Рµ k3s СЃРЅР°С‡Р°Р»Р°."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "РћС€РёР±РєР°: helm РЅРµ РЅР°Р№РґРµРЅ. РЈСЃС‚Р°РЅРѕРІРёС‚Рµ Helm СЃРЅР°С‡Р°Р»Р°."
    exit 1
fi

# РћС‡РёСЃС‚РєР° РїСЂРµРґС‹РґСѓС‰РёС… СѓСЃС‚Р°РЅРѕРІРѕРє (РµСЃР»Рё РµСЃС‚СЊ)
echo "РџСЂРѕРІРµСЂРєР° Рё РѕС‡РёСЃС‚РєР° РїСЂРµРґС‹РґСѓС‰РёС… СѓСЃС‚Р°РЅРѕРІРѕРє ArgoCD..."
if helm list -n argocd 2>/dev/null | grep -q "argocd"; then
    echo "РќР°Р№РґРµРЅ СЃСѓС‰РµСЃС‚РІСѓСЋС‰РёР№ СЂРµР»РёР· ArgoCD. РЈРґР°Р»РµРЅРёРµ..."
    helm uninstall argocd -n argocd || true
    sleep 5
fi

# РЈРґР°Р»РµРЅРёРµ СЃРµСЂРІРёСЃР° argocd-server РµСЃР»Рё РѕРЅ СЃСѓС‰РµСЃС‚РІСѓРµС‚ (РјРѕР¶РµС‚ Р·Р°РЅРёРјР°С‚СЊ РїРѕСЂС‚)
echo "РџСЂРѕРІРµСЂРєР° СЃСѓС‰РµСЃС‚РІСѓСЋС‰РёС… СЃРµСЂРІРёСЃРѕРІ ArgoCD..."
kubectl delete service argocd-server -n argocd --ignore-not-found=true || true
sleep 2

# РџСЂРѕРІРµСЂРєР° Р·Р°РЅСЏС‚РѕСЃС‚Рё РїРѕСЂС‚Р° 30443
echo "РџСЂРѕРІРµСЂРєР° РґРѕСЃС‚СѓРїРЅРѕСЃС‚Рё РїРѕСЂС‚Р° 30443..."
HTTPS_PORT=30443
if kubectl get svc --all-namespaces -o json | grep -q "\"nodePort\":$HTTPS_PORT"; then
    echo "Р’РЅРёРјР°РЅРёРµ: РџРѕСЂС‚ 30443 СѓР¶Рµ Р·Р°РЅСЏС‚ РґСЂСѓРіРёРј СЃРµСЂРІРёСЃРѕРј."
    echo "РџРѕРёСЃРє Р°Р»СЊС‚РµСЂРЅР°С‚РёРІРЅРѕРіРѕ РїРѕСЂС‚Р°..."
    # РџРѕРїСЂРѕР±СѓРµРј РЅР°Р№С‚Рё СЃРІРѕР±РѕРґРЅС‹Р№ РїРѕСЂС‚ РІ РґРёР°РїР°Р·РѕРЅРµ 30443-30450
    for port in 30444 30445 30446 30447 30448 30449 30450; do
        if ! kubectl get svc --all-namespaces -o json | grep -q "\"nodePort\":$port"; then
            HTTPS_PORT=$port
            echo "РќР°Р№РґРµРЅ СЃРІРѕР±РѕРґРЅС‹Р№ РїРѕСЂС‚: $HTTPS_PORT"
            break
        fi
    done
    if [ "$HTTPS_PORT" = "30443" ]; then
        echo "РќРµ СѓРґР°Р»РѕСЃСЊ РЅР°Р№С‚Рё СЃРІРѕР±РѕРґРЅС‹Р№ РїРѕСЂС‚. РСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРѕРіРѕ РЅР°Р·РЅР°С‡РµРЅРёСЏ РїРѕСЂС‚Р°..."
        HTTPS_PORT=""
    fi
fi

# РЎРѕР·РґР°РЅРёРµ namespace РґР»СЏ ArgoCD
echo "РЎРѕР·РґР°РЅРёРµ namespace argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Р”РѕР±Р°РІР»РµРЅРёРµ СЂРµРїРѕР·РёС‚РѕСЂРёСЏ ArgoCD
echo "Р”РѕР±Р°РІР»РµРЅРёРµ Helm СЂРµРїРѕР·РёС‚РѕСЂРёСЏ ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm || true
echo "РћР±РЅРѕРІР»РµРЅРёРµ СЂРµРїРѕР·РёС‚РѕСЂРёРµРІ Helm..."
helm repo update

# РЎРѕР·РґР°РЅРёРµ РІСЂРµРјРµРЅРЅРѕРіРѕ values С„Р°Р№Р»Р° РґР»СЏ Р°РЅРЅРѕС‚Р°С†РёР№
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

# РЈСЃС‚Р°РЅРѕРІРєР° ArgoCD С‡РµСЂРµР· Helm
echo "РЈСЃС‚Р°РЅРѕРІРєР° ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values /tmp/argocd-values.yaml \
  --timeout 15m \
  --wait

# РЈРґР°Р»РµРЅРёРµ РІСЂРµРјРµРЅРЅРѕРіРѕ С„Р°Р№Р»Р°
rm -f /tmp/argocd-values.yaml

# РћР¶РёРґР°РЅРёРµ РіРѕС‚РѕРІРЅРѕСЃС‚Рё РїРѕРґРѕРІ
echo "РћР¶РёРґР°РЅРёРµ РіРѕС‚РѕРІРЅРѕСЃС‚Рё ArgoCD..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || true

# РџРѕР»СѓС‡РµРЅРёРµ РЅР°С‡Р°Р»СЊРЅРѕРіРѕ РїР°СЂРѕР»СЏ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°
echo "========================================="
echo "ArgoCD СѓСЃС‚Р°РЅРѕРІР»РµРЅ!"
echo "========================================="
echo "РџРѕР»СѓС‡РµРЅРёРµ РЅР°С‡Р°Р»СЊРЅРѕРіРѕ РїР°СЂРѕР»СЏ Р°РґРјРёРЅРёСЃС‚СЂР°С‚РѕСЂР°..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo ""
echo "РРјСЏ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ: admin"
echo "РџР°СЂРѕР»СЊ: $ARGOCD_PASSWORD"
echo ""
# РџРѕР»СѓС‡РµРЅРёРµ С„Р°РєС‚РёС‡РµСЃРєРѕРіРѕ РїРѕСЂС‚Р° РёР· СЃРµСЂРІРёСЃР°
ACTUAL_HTTPS_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "30443")
if [ -n "$ACTUAL_HTTPS_PORT" ]; then
    echo "ArgoCD Р±СѓРґРµС‚ РґРѕСЃС‚СѓРїРµРЅ РїРѕ Р°РґСЂРµСЃСѓ: https://argocd.lab.local:$ACTUAL_HTTPS_PORT"
else
    echo "ArgoCD Р±СѓРґРµС‚ РґРѕСЃС‚СѓРїРµРЅ С‡РµСЂРµР· Ingress: https://argocd.lab.local"
    echo "Р”Р»СЏ РїСЂСЏРјРѕРіРѕ РґРѕСЃС‚СѓРїР° С‡РµСЂРµР· NodePort РїСЂРѕРІРµСЂСЊС‚Рµ РїРѕСЂС‚ РєРѕРјР°РЅРґРѕР№:"
    echo "  kubectl get svc argocd-server -n argocd"
fi
echo "========================================="
