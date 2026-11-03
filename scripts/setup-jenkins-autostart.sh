#!/bin/bash
# Starts SonarQube automatically on every boot (run with sudo on the Jenkins EC2)
set -e

SONAR_HOME=/home/sonarqube/sonarqube-26.10.0.133078
JAR=$(ls $SONAR_HOME/lib/sonar-application-*.jar)

cat > /etc/systemd/system/sonarqube.service <<UNIT
[Unit]
Description=SonarQube
After=network.target

[Service]
User=sonarqube
ExecStart=$(which java) -jar $JAR
LimitNOFILE=131072
LimitNPROC=8192
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now sonarqube
echo "SonarQube service enabled"