k3s-test

git clone https://github.com/mistermedved01/k3s-test.git
sudo chmod +x install-all.sh
sudo bash install-all.sh

Edit /etc/hosts
192.168.77.77 argocd.lab.local
*замените на IP-адрес вашей VM

**ArgoCD Web:** https://argocd.lab.local:30443

**ArgoCD получение логина-пароля:** kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d