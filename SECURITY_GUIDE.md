# Secure Credential Management Guide

## The Problem

Running `docker login quay.io -u "user" -p "password"` shows a warning:
```
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
```

This is because the password appears in:
- Shell history
- Process list (visible to other users)
- Shell scripts in plain text

## Secure Solutions

### Option 1: Interactive Login with Hidden Input (Simplest)

**Use the secure login script:**
```bash
./secure-login.sh
```

**Or manually:**
```bash
docker login quay.io -u "mpwbaruk+mpwrobot"
# Enter password when prompted (won't be visible)
```

**Pros:**
- ✅ Password never stored in files
- ✅ Not visible in shell history
- ✅ Secure by default

**Cons:**
- ❌ Manual input required each time
- ❌ Can't automate easily

---

### Option 2: Environment Variables with .env File (Recommended for Development)

**Step 1: Create .env file**
```bash
cp ..env .env
```

**Step 2: Edit .env with your credentials**
```bash
# Open in your editor
nano .env  # or vim, code, etc.
```

Add your token:
```bash
QUAY_USERNAME=mpwbaruk+mpwrobot
QUAY_TOKEN=your_actual_robot_token_here
```

**Step 3: Secure the file**
```bash
chmod 600 .env  # Only you can read/write
```

**Step 4: Login using the script**
```bash
./login-from-env.sh
```

**Or manually:**
```bash
source .env
echo "$QUAY_TOKEN" | docker login quay.io -u "$QUAY_USERNAME" --password-stdin
```

**Pros:**
- ✅ Secure password-stdin method
- ✅ Easy to automate
- ✅ One-time setup

**Cons:**
- ⚠️ Token stored in file (must protect it!)
- ⚠️ Must never commit to git

---

### Option 3: macOS Keychain (Most Secure for Mac)

**Store token in keychain:**
```bash
# Add to keychain
security add-generic-password \
  -a "mpwbaruk+mpwrobot" \
  -s "quay.io" \
  -w "your_robot_token_here"
```

**Create login script using keychain:**
```bash
#!/bin/bash
TOKEN=$(security find-generic-password \
  -a "mpwbaruk+mpwrobot" \
  -s "quay.io" \
  -w)

echo "$TOKEN" | docker login quay.io \
  -u "mpwbaruk+mpwrobot" \
  --password-stdin
```

**Pros:**
- ✅ Most secure (encrypted keychain)
- ✅ macOS native solution
- ✅ No plaintext files

**Cons:**
- ❌ More complex setup
- ❌ Mac-specific

---

### Option 4: Docker Credential Helpers (Production Grade)

**Install credential helper:**
```bash
brew install docker-credential-helper
```

**Configure Docker to use it:**
```bash
# Edit ~/.docker/config.json
{
  "credsStore": "osxkeychain"
}
```

**Login normally (credentials auto-stored in keychain):**
```bash
docker login quay.io -u "mpwbaruk+mpwrobot"
```

**Pros:**
- ✅ Industry standard
- ✅ Automatic credential management
- ✅ Secure keychain storage

---

## Critical Security Rules

### DO ✅

1. **Use .gitignore**
   ```bash
   # Always ignore sensitive files
   echo ".env" >> .gitignore
   echo "*.env" >> .gitignore
   echo "terraform/*.tfvars" >> .gitignore
   ```

2. **Protect .env file permissions**
   ```bash
   chmod 600 .env
   ```

3. **Use --password-stdin**
   ```bash
   echo "$TOKEN" | docker login quay.io -u "user" --password-stdin
   ```

4. **Clear environment variables after use**
   ```bash
   unset QUAY_TOKEN
   ```

5. **Check what you're committing**
   ```bash
   git status
   git diff
   ```

### DON'T ❌

1. **Never commit credentials**
   ```bash
   # BAD - DO NOT DO THIS
   git add .env
   git add terraform.tfvars
   ```

2. **Never use -p flag**
   ```bash
   # BAD - visible in process list and history
   docker login quay.io -u "user" -p "password"
   ```

3. **Never hardcode in scripts**
   ```bash
   # BAD
   TOKEN="abc123xyz"
   ```

4. **Never share credentials**
   - Don't paste in Slack/email
   - Don't share .env files
   - Generate new robot accounts for team members

---

## Recommended Setup for Your Project

**1. Copy files to your project:**
```bash
cp secure-login.sh ~/rd-spark-control-plane/
cp ..env ~/rd-spark-control-plane/
cp .gitignore ~/rd-spark-control-plane/
```

**2. Choose your method:**

**For quick testing (Option 1):**
```bash
./secure-login.sh
```

**For daily development (Option 2):**
```bash
cp ..env .env
nano .env  # Add your token
chmod 600 .env
./login-from-env.sh
```

**3. Update Makefile (optional):**

Add a secure login target:
```makefile
docker-login:
	@./secure-login.sh
```

Or use .env:
```makefile
docker-login:
	@./login-from-env.sh
```

---

## Verify Your Security

**Check what's ignored:**
```bash
git status --ignored
```

**Verify .env is not tracked:**
```bash
git ls-files | grep .env
# Should return nothing!
```

**Check file permissions:**
```bash
ls -la .env
# Should show: -rw------- (600)
```

---

## What to Commit vs. Not Commit

### ✅ SAFE TO COMMIT:
- `.env.template` (no real credentials)
- `.gitignore`
- `secure-login.sh`
- `login-from-env.sh`
- `Makefile`
- `Dockerfile`
- `README.md`

### ❌ NEVER COMMIT:
- `.env` (contains real token)
- `terraform.tfvars` (may contain passwords)
- `.docker/config.json` (contains encoded credentials)
- Any file with actual tokens/passwords

---

## If You Accidentally Commit Credentials

**1. Immediately rotate the credential**
- Go to Quay.io
- Delete the compromised robot account
- Create a new one

**2. Remove from git history**
```bash
# Remove file from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (if already pushed)
git push origin --force --all
```

**3. Inform your team**
- Let them know credentials were compromised
- Everyone should pull fresh and update

---

## Summary

**For this project, I recommend:**

1. Use `secure-login.sh` for now (simplest)
2. Login stays valid until you logout
3. Once logged in, run `make docker-build` and `make docker-push`

**Command:**
```bash
./secure-login.sh
make docker-build
make docker-push
```

Done! Your credentials are secure and never exposed in history or process list.
