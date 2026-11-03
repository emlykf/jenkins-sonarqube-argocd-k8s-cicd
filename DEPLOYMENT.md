# Deployment Steps

This guide sets up the CI/CD pipeline on two EC2 instances:

- Jenkins EC2: Jenkins, SonarQube and Docker
- Kubernetes EC2: Minikube with Argo CD

## 1. Launch the Jenkins EC2 instance

Launch an instance with:

- AMI: Ubuntu Server 24.04 LTS
- Instance type: m7i-flex.large
- Storage: 20 GB gp3
- Inbound rules: SSH 22, Custom TCP 8080 (Jenkins), Custom TCP 9000 (SonarQube)

Connect to it:

```bash
ssh -i <your-key>.pem ubuntu@<jenkins-public-ip>
```

## 2. Install Java

```bash
sudo apt update
sudo apt install fontconfig openjdk-21-jre
java -version
```

## 3. Install Jenkins

```bash
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins
sudo systemctl status jenkins
```

## 4. Unlock Jenkins

Open `http://<jenkins-public-ip>:8080` and get the initial admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Paste it, choose Install suggested plugins and create your own admin user.

## 5. Install Docker

```bash
sudo apt update
sudo apt install docker.io
```

## 6. Grant Docker daemon access

Docker runs as root, so by default only root can use it. Adding jenkins and ubuntu to the docker group lets Jenkins start its Docker agent containers. Jenkins needs a restart and you need to log in again so the new group applies.

```bash
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu
sudo systemctl restart docker
sudo systemctl restart jenkins
groups jenkins
```

The output should include `docker`. Log out of SSH and connect again.

## 7. Install the Jenkins plugins

Go to Manage Jenkins → Plugins → Available plugins and install:

- Docker Pipeline
- SonarQube Scanner

Restart Jenkins afterwards with `http://<jenkins-public-ip>:8080/restart`.

## 8. Build the Jenkins agent image

Create a Dockerfile:

```bash
mkdir ~/jenkins-agent
cd ~/jenkins-agent
nano Dockerfile
```

Paste this and save:

```dockerfile
FROM maven:3.9-eclipse-temurin-11
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins
```

Build and test the image:

```bash
docker build -t <your-dockerhub-user>/maven-docker-agent:v1 .
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  <your-dockerhub-user>/maven-docker-agent:v1 sh -c "mvn -v && docker version"
```

## 9. Install and start SonarQube

```bash
sudo apt install unzip
sudo adduser sonarqube
sudo su - sonarqube
```

Wait for the sonarqube prompt, then run:

```bash
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-26.10.0.133078.zip
unzip sonarqube-26.10.0.133078.zip
cd sonarqube-26.10.0.133078/bin/linux-x86-64
./sonar.sh start
./sonar.sh status
exit
```

Open `http://<jenkins-public-ip>:9000`, log in with admin / admin and set a new password.

## 10. Create tokens and Jenkins credentials

SonarQube token: sidebar icon (top left) → Security → Generate Tokens. Name it `jenkins` and choose User Token.

Docker Hub token: app.docker.com → Account settings → Personal access tokens → Generate new token. Choose Read & Write.

GitHub token: Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token. Only tick `repo`, not all boxes.

Copy each token right away, it is only shown once.

Then add them in Jenkins under Manage Jenkins → Credentials → System → Global credentials → Add Credentials:

- ID `sonarqube`, kind Secret text, value: SonarQube token
- ID `docker-cred`, kind Username with password, value: Docker Hub username and token
- ID `github`, kind Secret text, value: GitHub token

The IDs have to match exactly because the Jenkinsfile uses them.

## 11. Adjust the Jenkinsfile and the manifest

In `spring-boot-app/Jenkinsfile`, change these values to your own:

- agent image: `<your-dockerhub-user>/maven-docker-agent:v1`
- `SONAR_URL`: `http://<jenkins-private-ip>:9000`
- `DOCKER_IMAGE`: `<your-dockerhub-user>/ultimate-cicd:${BUILD_NUMBER}`
- `GIT_REPO_NAME` and `GIT_USER_NAME`: your repo and GitHub username
- the `sed` line: `<your-dockerhub-user>/ultimate-cicd`

In `spring-boot-app-manifests/deployment.yml`, change the image line:

```yaml
image: <your-dockerhub-user>/ultimate-cicd:1
```

Push the changes to GitHub.

## 12. Create the pipeline job

In Jenkins, click New Item, name it `ultimate-demo` and choose Pipeline. Then set:

- Definition: Pipeline script from SCM
- SCM: Git
- Repository URL: `https://github.com/<your-github-user>/jenkins-sonarqube-argocd-k8s-cicd`
- Branch Specifier: `*/main`
- Script Path: `spring-boot-app/Jenkinsfile`

Click Save.

## 13. Set Up the GitHub Webhook

In the Jenkins job, click **Configure** and set:

- **Triggers:** tick GitHub hook trigger for GITScm polling
- **Pipeline → Git → Additional Behaviours:**
  - Polling ignores commits in certain paths, **Excluded Regions:** `spring-boot-app-manifests/.*`
  - Force polling using workspace

Click **Save**.

In your GitHub repo, go to **Settings → Webhooks → Add webhook**:

- **Payload URL:** `http://<jenkins-public-ip>:8080/github-webhook/`
- **Content type:** `application/json`
- **Events:** Just the push event

Verify: under **Recent Deliveries**, the ping shows a green check.

## 14. Launch the Kubernetes EC2 instance

Launch an instance with:

- AMI: Ubuntu Server 24.04 LTS
- Instance type: m7i-flex.large
- Storage: 20 GB gp3
- Inbound rules: SSH 22, Custom TCP 8443 (Argo CD UI), Custom TCP 8010 (app)

Connect to it:

```bash
ssh -i <your-key>.pem ubuntu@<k8s-public-ip>
```

## 15. Install Minikube

Install Docker:

```bash
sudo apt update
sudo apt install docker.io
sudo usermod -aG docker ubuntu
newgrp docker
```

Install kubectl and Minikube:

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
```

Start Minikube:

```bash
minikube start --memory=6g
kubectl get nodes
```

## 16. Install OLM and the Argo CD Operator

The install commands come from operatorhub.io. Search for Argo CD, click Install and copy the commands shown there. They always contain the current OLM version.

At the time of writing, they were:

```bash
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.46.0/install.sh | bash -s v0.46.0
kubectl create -f https://operatorhub.io/install/argocd-operator.yaml
```

Check that the operator is ready:

```bash
kubectl get csv -n operators -w
```

Wait until the phase shows `Succeeded`, then press Ctrl + C.

## 17. Create the Argo CD instance

The file `argocd/argocd-basic.yaml` is based on the basic example from the Argo CD Operator documentation (operatorhub.io → Argo CD → Operator Documentation → Usage → Basics), with the server service set to NodePort.

```bash
kubectl apply -f https://raw.githubusercontent.com/<your-github-user>/jenkins-sonarqube-argocd-k8s-cicd/main/argocd/argocd-basic.yaml
kubectl get pods -w
```

Wait until all example-argocd pods are running, then press Ctrl + C.

## 18. Open the Argo CD UI

Start the port-forward and keep the terminal open:

```bash
kubectl port-forward svc/example-argocd-server 8443:443 --address 0.0.0.0
```

Open `https://<k8s-public-ip>:8443`.

In a second SSH session, get the admin password:

```bash
kubectl get secret example-argocd-cluster -o jsonpath='{.data.admin\.password}' | base64 -d; echo
```

Log in with admin and that password.

## 19. Create the Argo CD Application

Click New App and fill in:

- Application Name: `spring-boot-app`
- Project Name: `default`
- Sync Policy: Automatic
- Repository URL: `https://github.com/<your-github-user>/jenkins-sonarqube-argocd-k8s-cicd`
- Revision: `HEAD`
- Path: `spring-boot-app-manifests`
- Cluster URL: `https://kubernetes.default.svc`
- Namespace: `default`

Click Create.

## 20. Run the pipeline

Push a change to the `spring-boot-app` folder. The webhook starts the build automatically. Build Now in Jenkins still works for a manual run.

When the build is green, check:

- SonarQube: Quality Gate passed
- Docker Hub: new image tag with the build number
- GitHub: new commit "Update deployment image to version ..."
- Argo CD: Synced and Healthy

## 21. Open the app

On the Kubernetes EC2, in a new SSH session:

```bash
kubectl port-forward svc/spring-boot-app-service 8010:80 --address 0.0.0.0
```

Open `http://<k8s-public-ip>:8010`.

## 22. Start everything again after a restart

Both instances get new public IPs after a restart.

In GitHub, update the Payload URL of the webhook with the new Jenkins public IP: Settings → Webhooks → Edit.

On the Jenkins EC2, start SonarQube:

```bash
sudo su - sonarqube
cd sonarqube-26.10.0.133078/bin/linux-x86-64
./sonar.sh start
exit
```

On the Kubernetes EC2, start Minikube:

```bash
minikube start
kubectl get pods
```

Then start the port-forwards again from step 18 and step 21.

## 23. Clean up

Terminate both EC2 instances and delete their security groups.

Delete the tokens you no longer need:

- the Docker Hub access token
- the GitHub classic token

Optionally, delete the `ultimate-cicd` images from Docker Hub.