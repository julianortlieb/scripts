#!/bin/bash
set -e

# ==========================================
# KONFIGURATION
# ==========================================
# Ermittle die primäre IP-Adresse der VM
VM_IP=$(hostname -I | awk '{print $1}')
DOMAIN="${VM_IP}.nip.io"

echo "=============================================="
echo "OpenDesk Auto-Installer auf K3s"
echo "VM IP: $VM_IP"
echo "Basis-Domain: $DOMAIN"
echo "ACHTUNG: Mindestens 16GB RAM erforderlich!"
echo "=============================================="
sleep 5

# ==========================================
# 1. SYSTEM VORBEREITUNG
# ==========================================
echo "[1/6] Aktualisiere System und installiere Abhängigkeiten..."
apt-get update && apt-get upgrade -y
apt-get install -y curl git jq grep sed unzip tar

# Swap deaktivieren (empfohlen für Kubernetes)
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ==========================================
# 2. INSTALLATION K3S (ohne Traefik)
# ==========================================
echo "[2/6] Installiere K3s Cluster (ohne Traefik)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644" sh -

# Kubeconfig für Root exportieren
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc

# Warten bis Node ready ist
echo "Warte auf K3s Node..."
sleep 15
kubectl wait --for=condition=Ready node --all --timeout=60s

# ==========================================
# 3. TOOLS INSTALLIEREN (Helm & Helmfile)
# ==========================================
echo "[3/6] Installiere Helm und Helmfile..."

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Helmfile (Benötigt für OpenDesk Deployment)
HELMFILE_VERSION=$(curl -s "https://api.github.com/repos/helmfile/helmfile/releases/latest" | jq -r .tag_name)
wget -O helmfile_linux_amd64.tar.gz "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_linux_amd64.tar.gz"
tar -zxvf helmfile_linux_amd64.tar.gz
mv helmfile /usr/local/bin/
rm helmfile_linux_amd64.tar.gz LICENSE README.md

# ==========================================
# 4. BASIS-INFRASTRUKTUR (Ingress NGINX)
# ==========================================
echo "[4/6] Installiere NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.watchIngressWithoutClass=true

# Warten auf Ingress
echo "Warte auf Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# ==========================================
# 5. OPENDESK REPO & CONFIG
# ==========================================
echo "[5/6] Klone OpenDesk Deployment Repository..."
# Wir nutzen hier das offizielle Deployment Repo vom BMI / ZenDiS
WORKDIR="/opt/opendesk"
mkdir -p $WORKDIR
git clone https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git $WORKDIR || echo "Repo existiert bereits"
cd $WORKDIR

echo "Erstelle Konfiguration für lokale Umgebung..."

# Wir erstellen eine environment Values Datei für Helmfile
# Dies ist eine vereinfachte Konfiguration für den Start
cat <<EOF > ./custom-values.yaml
global:
  domain: "${DOMAIN}"
  hosts:
    hostNameStrategy: "hyphen" # portal-domain.tld statt portal.domain.tld (vermeidet Wildcard DNS Probleme lokal)
  
  # Da wir lokal sind, nutzen wir Self-Signed oder Let's Encrypt Staging, 
  # aber hier deaktivieren wir cert-manager Validierung oft lieber für lokale Tests
  # oder nutzen den eingebauten cert-manager von OpenDesk.
  
cleanup:
  deletePodsOnSuccess: false

# Minimales Setup aktivieren (falls im Chart verfügbar, sonst Standard)
EOF

# ==========================================
# 6. OPENDESK DEPLOYMENT STARTEN
# ==========================================
echo "[6/6] Starte OpenDesk Installation via Helmfile..."
echo "Dieser Schritt kann 10-20 Minuten dauern."

# Initialisierung der Helm-Repos
helmfile deps

# Installation
# HINWEIS: OpenDesk ist komplex. Falls es hier bricht, liegt es oft an Timeouts.
helmfile apply -f helmfile.yaml --state-values-file custom-values.yaml

echo "=============================================="
echo "INSTALLATION ABGESCHLOSSEN (oder versucht)"
echo "=============================================="
echo "Überprüfe den Status mit: kubectl get pods -A"
echo ""
echo "Deine OpenDesk URL sollte lauten: https://portal-${DOMAIN}"
echo "Da wir lokal sind und selbstsignierte Zertifikate nutzen,"
echo "musst du die Sicherheitswarnung im Browser akzeptieren."
echo ""
echo "Um Passwörter (z.B. für Keycloak/Admin) zu finden,"
echo "suche in den Secrets: kubectl get secrets"
echo "=============================================="
