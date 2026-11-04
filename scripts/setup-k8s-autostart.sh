#!/bin/bash
# Starts Minikube and the port-forwards automatically on every boot (run with sudo on the Kubernetes EC2)
set -e

create_service() {
  cat > /etc/systemd/system/$1.service <<UNIT
[Unit]
After=$2

[Service]
Type=$3
RemainAfterExit=$4
User=ubuntu
Environment=HOME=/home/ubuntu
ExecStart=$5
Restart=$6
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
}

create_service minikube docker.service oneshot yes "$(which minikube) start --wait=all" on-failure
create_service argocd-ui minikube.service simple no "$(which kubectl) port-forward svc/example-argocd-server 8443:443 --address 0.0.0.0" always
create_service app minikube.service simple no "$(which kubectl) port-forward svc/spring-boot-app-service 8010:80 --address 0.0.0.0" always

systemctl daemon-reload
systemctl enable --now minikube argocd-ui app
echo "Minikube and port-forwards enabled"