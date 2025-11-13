# SDK Deployment Guide

This guide explains how to deploy your generated SDKs to their respective package registries.

## 📋 Pre-Deployment Checklist

Before deploying any SDK, ensure you have:

- [ ] **Tested the SDK** - Verify it works with your API
- [ ] **Updated version numbers** - Increment version in config files
- [ ] **Regenerated SDKs** - Run `./sdk/generate.sh` after version updates
- [ ] **Created git tags** - Tag releases for version tracking
- [ ] **Updated CHANGELOG** - Document changes (if applicable)
- [ ] **Package registry accounts** - Set up accounts and authentication

## 🔐 Authentication Setup

### npm (TypeScript)
```bash
npm login
# Enter username, password, and email
# For scoped packages: npm login --scope=@yourorg
```

### PyPI (Python)
```bash
# Install twine
pip install twine

# Create API token at https://pypi.org/manage/account/token/
# Use token as password when uploading
```

### Go Modules
```bash
# No authentication needed for public repos
# Ensure your Go module is in a git repository
# Tag releases: git tag v0.1.0 && git push origin v0.1.0
```

### Composer/Packagist (PHP)
```bash
# 1. Create account at https://packagist.org
# 2. Submit your GitHub repository URL
# 3. Add webhook for auto-updates (optional)
```

### crates.io (Rust)
```bash
# Get API token from https://crates.io/me
cargo login <your-token>
```

### RubyGems
```bash
# Get API key from https://rubygems.org/profile/edit
gem signin
# Or set credentials in ~/.gem/credentials
```

### Maven Central (Java/Kotlin)
```bash
# Requires Sonatype account and GPG signing
# See: https://central.sonatype.org/publish/publish-guide/
```

## 📦 Language-Specific Deployment

### 1. TypeScript (npm)

```bash
cd sdk/generated/typescript

# Update version (if not done in config)
npm version patch  # or minor, major

# Login to npm (if not already)
npm login

# Publish
npm publish --access public

# For scoped packages (@org/package)
npm publish --access public
```

**Verification:**
```bash
npm view @yourorg/yourapi
```

---

### 2. Python (PyPI)

```bash
cd sdk/generated/python

# Install build tools
pip install build twine

# Build distribution packages
python -m build

# Upload to PyPI
twine upload dist/*

# Or upload to TestPyPI first (recommended)
twine upload --repository testpypi dist/*
```

**Verification:**
```bash
pip install yourapi
python -c "import yourapi; print(yourapi.__version__)"
```

---

### 3. Go Modules

```bash
cd sdk/generated/go

# Ensure go.mod is properly configured
# Update version in go.mod if needed

# Create and push git tag
git tag v0.1.0
git push origin v0.1.0

# Users can install with:
# go get github.com/yourorg/yourapi-go@v0.1.0
```

**Note:** Go modules are distributed via git repositories. Ensure your repository is public or users have access.

**Verification:**
```bash
go list -m -versions github.com/yourorg/yourapi-go
```

---

### 4. PHP (Packagist)

```bash
cd sdk/generated/php

# 1. Push to GitHub (if not already)
git init
git add .
git commit -m "Initial PHP SDK release"
git remote add origin https://github.com/yourorg/yourapi-php.git
git push -u origin main

# 2. Submit to Packagist
# - Go to https://packagist.org/packages/submit
# - Enter your repository URL: https://github.com/yourorg/yourapi-php
# - Click "Check" and then "Submit"

# 3. (Optional) Add webhook for auto-updates
# - In Packagist: Settings → API Token
# - In GitHub: Settings → Webhooks → Add webhook
# - URL: https://packagist.org/api/github?username=YOUR_USERNAME
# - Secret: Your Packagist API token
```

**Verification:**
```bash
composer require yourorg/yourapi
```

---

### 5. Rust (crates.io)

```bash
cd sdk/generated/rust

# Login to crates.io (first time only)
cargo login <your-api-token>

# Verify package is ready
cargo package --dry-run

# Publish
cargo publish

# Or publish without verification (faster, but less safe)
cargo publish --no-verify
```

**Note:** Once published, a version cannot be overwritten. Use `cargo yank` to remove a version.

**Verification:**
```bash
cargo search yourapi
```

---

### 6. Ruby (RubyGems)

```bash
cd sdk/generated/ruby

# Build gem
gem build yourapi.gemspec

# Push to RubyGems
gem push yourapi-0.1.0.gem

# Or use credentials file
# Create ~/.gem/credentials with:
# :rubygems_api_key: YOUR_API_KEY
gem push yourapi-0.1.0.gem
```

**Verification:**
```bash
gem search yourapi
gem install yourapi
```

---

### 7. Java (Maven Central)

```bash
cd sdk/generated/java

# Configure Maven settings.xml with Sonatype credentials
# See: https://central.sonatype.org/publish/publish-guide/

# Build and deploy
mvn clean deploy -P release

# Or if using Gradle
./gradlew publishToMavenLocal
./gradlew publish
```

**Prerequisites:**
- Sonatype account
- GPG key for signing
- Maven Central access (request via JIRA ticket)

**Verification:**
```bash
# Check Maven Central
# https://search.maven.org/search?q=g:com.yourorg
```

---

### 8. Kotlin (Maven Central / Gradle)

```bash
cd sdk/generated/kotlin

# Using Gradle
./gradlew publishToMavenLocal
./gradlew publish

# Or configure for Maven Central
# See Java instructions above
```

**Verification:**
```bash
# Check Maven Central or your configured repository
```

---

## 🔄 Automated Deployment (CI/CD)

The project includes a GitHub Actions workflow for automated deployment. To use it:

### Setup Secrets

Configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

- `NPM_TOKEN` - npm publishing token
- `PYPI_TOKEN` - PyPI API token
- `CARGO_TOKEN` - crates.io API token
- `RUBYGEMS_TOKEN` - RubyGems API key
- `MAVEN_USERNAME` - Sonatype username
- `MAVEN_PASSWORD` - Sonatype password
- `GPG_PASSPHRASE` - GPG key passphrase (for Maven)

### Trigger Deployment

**Option 1: Tag-based (Recommended)**
```bash
# Create tags for each SDK you want to publish
git tag sdk-ts@0.1.0    # TypeScript
git tag sdk-py@0.1.0    # Python
git tag sdk-go@v0.1.0   # Go
git tag sdk-php@0.1.0   # PHP
git tag sdk-rust@0.1.0  # Rust
git tag sdk-ruby@0.1.0  # Ruby
git tag sdk-java@0.1.0  # Java
git tag sdk-kotlin@0.1.0 # Kotlin

# Push tags
git push --tags
```

**Option 2: Manual Workflow Dispatch**
1. Go to GitHub Actions
2. Select "Generate SDKs" workflow
3. Click "Run workflow"
4. Check "Publish to registries"
5. Click "Run workflow"

### Workflow Behavior

- **On tag push**: Automatically publishes matching SDKs
- **On manual dispatch**: Can optionally publish if `publish` input is checked
- **On spec/config changes**: Only generates SDKs (doesn't publish)

---

## 📝 Version Management

### Update Version Before Deployment

1. **Update config file:**
   ```bash
   # Edit the version in the language-specific config
   vim sdk/configs/typescript.json  # Change "npmVersion"
   vim sdk/configs/python.json      # Change "packageVersion"
   # etc.
   ```

2. **Regenerate SDK:**
   ```bash
   ./sdk/generate.sh -l typescript
   ```

3. **Verify version in generated package:**
   ```bash
   cd sdk/generated/typescript
   cat package.json | grep version
   ```

### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
- **MINOR** (1.0.0 → 1.1.0): New features, backward compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes, backward compatible

---

## 🧪 Testing Before Deployment

### Local Testing

```bash
# TypeScript
cd sdk/generated/typescript
npm install
npm test
npm link
# Test in another project: npm link @yourorg/yourapi

# Python
cd sdk/generated/python
pip install -e .
python -m pytest

# Go
cd sdk/generated/go
go test ./...

# PHP
cd sdk/generated/php
composer install
composer test

# Rust
cd sdk/generated/rust
cargo test

# Ruby
cd sdk/generated/ruby
bundle install
bundle exec rspec

# Java
cd sdk/generated/java
mvn test

# Kotlin
cd sdk/generated/kotlin
./gradlew test
```

---

## 🚨 Troubleshooting

### npm: Package name already taken
- Use a scoped package: `@yourorg/yourapi`
- Or choose a different name

### PyPI: Package name conflicts
- Check availability: `pip search yourapi` (deprecated) or check pypi.org
- Use a more unique name

### Go: Module not found
- Ensure repository is public
- Verify go.mod module path matches repository URL
- Check git tags are pushed

### PHP: Packagist submission fails
- Verify repository is public
- Check composer.json is valid
- Ensure repository has at least one tag

### Rust: Publish fails
- Check Cargo.toml metadata
- Verify all dependencies are published
- Ensure version hasn't been published before

### Maven: Deployment fails
- Verify Sonatype account access
- Check GPG signing configuration
- Ensure all required metadata is present

---

## 📚 Additional Resources

- [npm Publishing Guide](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)
- [PyPI Packaging Guide](https://packaging.python.org/tutorials/packaging-projects/)
- [Go Modules Publishing](https://go.dev/doc/modules/publishing)
- [Packagist Documentation](https://packagist.org/about)
- [crates.io Publishing](https://doc.rust-lang.org/cargo/reference/publishing.html)
- [RubyGems Publishing](https://guides.rubygems.org/publishing/)
- [Maven Central Publishing](https://central.sonatype.org/publish/publish-guide/)

---

## 🎯 Quick Reference

| Language | Registry | Command | Auth |
|----------|----------|---------|------|
| TypeScript | npm | `npm publish` | `npm login` |
| Python | PyPI | `twine upload dist/*` | API token |
| Go | Git | `git tag && git push` | None (public) |
| PHP | Packagist | Submit repo URL | Account |
| Rust | crates.io | `cargo publish` | `cargo login` |
| Ruby | RubyGems | `gem push` | API key |
| Java | Maven Central | `mvn deploy` | Sonatype |
| Kotlin | Maven Central | `./gradlew publish` | Sonatype |

---

**Ready to deploy?** Start with one language, test thoroughly, then expand to others!

