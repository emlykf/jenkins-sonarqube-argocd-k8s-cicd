# Other - Challenges

### 6. SonarQube Analysis Didn't Start

**Problem:** The analysis failed with `No plugin found for prefix 'sonar'`, because Maven couldn't resolve the short command `mvn sonar:sonar` anymore.

**Solution:** Called the plugin by its full name and used the current token parameter:

```bash
mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar -Dsonar.token=$SONAR_AUTH_TOKEN
```

**Result:** The analysis runs on every build.

### 7. Jenkins Had No Access to Docker

**Problem:** The first build failed with `permission denied ... docker.sock`, because the jenkins user wasn't in the docker group. The `usermod` lines I pasted after `sudo su -` were swallowed and never ran.

**Solution:** Ran `usermod -aG docker jenkins` again, one command at a time, and restarted Jenkins.

**Result:** Jenkins can start its Docker agent containers.

**Lesson:** After a command that opens a new shell (`sudo su -`, `su - user`, `newgrp`), wait for the new prompt before pasting the next command.

---

### 8. Docker Hub Login Failed

**Problem:** The image push failed with `incorrect username or password`, because I sign in to Docker Hub with GitHub, so my account has no password Jenkins could use.

**Solution:** Created a Docker Hub access token with Read & Write and used it in the `docker-cred` credential.

**Result:** Jenkins pushes every new image to Docker Hub.

---

### 9. Jenkins Couldn't Find the GitHub Credential

**Problem:** The last stage failed with `Could not find credentials entry with ID 'github'`, even though the credential was listed in Jenkins.

**Solution:** Deleted the credential and created it again, typing the ID `github` by hand.

**Result:** Jenkins can push to GitHub.

**Lesson:** The name shown in the credentials list isn't always the ID. Credential IDs can't be edited afterwards.

---

### 10. Git Didn't Recognize the Repository

**Problem:** The last stage failed with `fatal: not in a git directory`, because Git refuses to work in a folder owned by another user (the container runs as root, the workspace belongs to jenkins).

**Solution:** Told Git to trust the workspace in the Jenkinsfile:

```bash
git config --global --add safe.directory "$WORKSPACE"
```

**Result:** Git can commit and push the updated `deployment.yml`.