# k3s-test

Автоматизированная установка k3s, Helm и ArgoCD для тестового окружения.

## Быстрый старт

```bash
git clone https://github.com/barmaglot351/k3s-test.git
cd k3s-test
sudo chmod +x install-all.sh
sudo bash install-all.sh
```

## Настройка DNS

Добавьте запись в `/etc/hosts` (замените IP на адрес вашей VM):

```
192.168.77.77 argocd.lab.local
```

## Доступ к ArgoCD

**Web UI:** https://argocd.lab.local:30443

**Логин:** `admin`

**Пароль:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Приложения

В репозитории доступны готовые ArgoCD Applications:

- **cert-manager** - автоматическое управление TLS сертификатами
- **Media Server Stack** - Jellyfin, Prowlarr, qBittorrent, Radarr

Подробная документация в директории `argocd-apps/`.

## Особенности k3s

- Использует **Traefik** вместо nginx-ingress (встроен по умолчанию)
- Использует **local-path** StorageClass для PersistentVolumes
- Оптимизирован для легковесных кластеров



## Дополнительная информация как через костылинг поставить сервис
1. git clone https://github.com/barmaglot351/k3s-test.git
2. cd <имя тачки>

# Настройка служебного прокси
    export http_proxy="http://<имя тачки>::<пароль прокси>@<адрес прокси:порт>"
    export https_proxy="http://<имя тачки>::<пароль прокси>@<адрес прокси:порт>"
    export ftp_proxy="http://<имя тачки>::<пароль прокси>@<адрес прокси:порт>"
    export no_proxy="localhost,127.0.0.1,::1,192.168.1.*"

3. ставим install-k3s из под прокси
4. reboot
5. комментируем установку k3s (#curl -sfL https://get.k3s.io | sh -) и снова запускаем install-k3s
6. sudo chmod +x install-helm.sh
7. sudo bash install-helm.sh
8. sudo chmod +x install-argocd.sh
9. sudo bash install-argocd.sh - установка долгая
10. копируем логин и пароль от аргос
11. выполнеяем kubectl apply -f argocd-ingress.yaml чтобы была возможность зайти вне кластера