# Other Challenges


### 4. Jenkins Had No Access to Docker

**Problem:** The first build failed with `permission denied ... docker.sock`, because the jenkins user wasn't in the docker group. The `usermod` lines I pasted after `sudo su -` were swallowed and never ran.

**Solution:** Ran `usermod -aG docker jenkins` again, one command at a time, and restarted Jenkins.

**Result:** Jenkins can start its Docker agent containers.

**Lesson:** After a command that opens a new shell (`sudo su -`, `su - user`, `newgrp`), wait for the new prompt before pasting the next command.

---

### 5. SonarQube Analysis Didn't Start

**Problem:** The analysis failed with `No plugin found for prefix 'sonar'`, because Maven couldn't resolve the short command `mvn sonar:sonar` anymore.

**Solution:** Called the plugin by its full name and used the current token parameter:

```bash
mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar -Dsonar.token=$SONAR_AUTH_TOKEN
```

**Result:** The analysis runs on every build.

---

### 6. Docker Hub Login Failed

**Problem:** The image push failed with `incorrect username or password`, because I sign in to Docker Hub with GitHub, so my account has no password Jenkins could use.

**Solution:** Created a Docker Hub access token with Read & Write and used it in the `docker-cred` credential.

**Result:** Jenkins pushes every new image to Docker Hub.

---

### 7. Jenkins Couldn't Find the GitHub Credential

**Problem:** The last stage failed with `Could not find credentials entry with ID 'github'`, even though the credential was listed in Jenkins.

**Solution:** Deleted the credential and created it again, typing the ID `github` by hand.

**Result:** Jenkins can push to GitHub.

**Lesson:** The name shown in the credentials list isn't always the ID. Credential IDs can't be edited afterwards.

---

### 8. Git Didn't Recognize the Repository

**Problem:** The last stage failed with `fatal: not in a git directory`, because Git refuses to work in a folder owned by another user (the container runs as root, the workspace belongs to jenkins).

**Solution:** Told Git to trust the workspace in the Jenkinsfile:

```bash
git config --global --add safe.directory "$WORKSPACE"
```

**Result:** Git can commit and push the updated `deployment.yml`.

---

### 9. Jenkins Couldn't Fetch the Code After a Successful Build

**Problem:** The build failed at the start with `insufficient permission ... .git/objects`, because the last build's Git commit (made as root inside the container) left files Jenkins wasn't allowed to change. 

**Solution:** Gave the folder back with `sudo chown -R jenkins:jenkins /var/lib/jenkins/workspace/ultimate-demo`, and added a `post` block to the Jenkinsfile that does this after every build.

**Result:** Every build leaves the workspace owned by Jenkins.

---

### 10. The Image Tag Was Only Updated Once

**Problem:** The second deployment failed with `nothing to commit`, because `sed` searched for the placeholder `replaceImageTag`, which was already replaced in the first build.

**Solution:** Changed `sed` to replace whatever tag is in the image line:

```bash
sed -i "s|image: emlykf/ultimate-cicd:.*|image: emlykf/ultimate-cicd:${BUILD_NUMBER}|" spring-boot-app-manifests/deployment.yml
```

**Result:** Every build updates the image tag, so Argo CD gets each new version.