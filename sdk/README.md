# SDK Generation Guide

This directory contains everything needed to generate production-ready SDKs from your OpenAPI specification.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Wrapper Architecture](#wrapper-architecture)
- [Generation Process](#generation-process)
- [Publishing](#publishing)
- [Troubleshooting](#troubleshooting)

## Quick Start

### 1. Prepare Your OpenAPI Spec

Replace `openapi.yaml` with your API specification (YAML or JSON):

```bash
# Using YAML
cp your-api.yaml sdk/openapi.yaml

# Using JSON
cp your-api.json sdk/openapi.json
```

Or update the provided template with your API endpoints, models, and authentication.

**Supported formats:** `.yaml`, `.yml`, `.json`

### 2. Configure & Generate SDKs

#### First-Time Setup (Automatic)

On your first run, the script automatically detects default configs and starts the configuration wizard:

```bash
# First run - automatically prompts for configuration
./sdk/generate.sh -o swagger.yml

# Pre-specify the SDK name
./sdk/generate.sh -o swagger.yml -n myapi
```

This will prompt you for:
- SDK/project name
- Organization details
- Email and website
- GitHub username
- npm package settings

All configuration files will be automatically updated and SDKs generated.

> **Note**: Configuration mode is automatically triggered on first run. To reconfigure later, use the `-c` flag: `./sdk/generate.sh -c`

#### Subsequent Runs (Generation Only)

```bash
# Generate all SDKs (uses sdk/openapi.yaml by default)
./sdk/generate.sh

# Generate specific language
./sdk/generate.sh -l typescript

# Use custom OpenAPI YAML file
./sdk/generate.sh -o path/to/custom.yaml -l python

# Use OpenAPI JSON file
./sdk/generate.sh -o path/to/api-spec.json -l typescript

# Multiple languages with JSON spec
./sdk/generate.sh -o api.json -l typescript,python,go
```

### 3. Test Generated SDKs

```bash
# TypeScript
cd generated/typescript && npm install && npm test

# Python
cd generated/python && pip install -e . && pytest

# Go
cd generated/go && go test ./...
```

## Configuration

### Generator Configs

Each language has a configuration file in `configs/` that controls code generation:

#### TypeScript (`configs/typescript.json`)
```json
{
  "npmName": "@yourorg/yourapi",
  "npmVersion": "0.1.0",
  "supportsES6": true,
  "withSeparateModelsAndApi": true
}
```

#### Python (`configs/python.json`)
```json
{
  "packageName": "yourapi",
  "projectName": "yourapi-sdk",
  "packageVersion": "0.1.0"
}
```

#### Go (`configs/go.json`)
```json
{
  "packageName": "yourapi",
  "packageVersion": "0.1.0",
  "isGoSubmodule": true
}
```

### Customizing Package Names

Update these fields in config files:
- **TypeScript**: `npmName`
- **Python**: `packageName`, `projectName`
- **Go**: `packageName`
- **PHP**: `invokerPackage`, `packageName`
- **Rust**: `packageName`
- **Swift**: `projectName`, `podName`
- **Ruby**: `gemName`, `moduleName`
- **Java**: `groupId`, `artifactId`
- **Kotlin**: `groupId`, `artifactId`, `packageName`

## Wrapper Architecture

Generated SDKs consist of two layers:

### 1. Generated Layer (by OpenAPI Generator)
- API client classes
- Model/data classes
- Request/response types
- Basic HTTP operations

Location: `generated/{language}/`

### 2. Wrapper Layer (custom production code)
- Authentication handling
- Retry logic with exponential backoff
- Pagination helpers
- Error normalization
- Telemetry and headers
- Debug logging

Location: `wrappers/{language}/`

### How They Work Together

```
Your App
    ↓
Wrapper Client (production features)
    ↓
Generated Client (OpenAPI-based)
    ↓
HTTP Library (axios, requests, etc.)
    ↓
Your API
```

### Example: TypeScript

```typescript
// Your app uses the wrapper
import { YourAPIClient } from '@yourorg/yourapi';

const client = new YourAPIClient({
  baseUrl: 'https://api.example.com',
  apiKey: 'key'
});

// Wrapper handles retries, pagination, errors
const customers = await client.getAllCursor('/customers');
```

## Generation Process

### What Happens When You Run `./generate.sh`

1. **Validation**: Checks OpenAPI spec exists
2. **Generator Installation**: Verifies OpenAPI Generator is installed
3. **Code Generation**: For each language:
   - Creates output directory
   - Runs OpenAPI Generator with language-specific config
   - Copies wrapper code to generated directory
   - Reports success/failure

4. **Summary**: Reports overall results

### Generated Output Structure

```
generated/{language}/
├── README.md                 # Language-specific usage guide
├── package.json / setup.py / etc.  # Package manifest
├── src/ or lib/              # Generated source code
├── models/                   # Data models
├── apis/                     # API client code
└── wrapper files             # Production wrapper code
```

## Publishing

### Version Management

Each language can be versioned independently:

```bash
# Update version in config file
vim sdk/configs/typescript.json  # Change npmVersion

# Regenerate
./sdk/generate.sh -l typescript

# Publish
cd sdk/generated/typescript
npm version patch
npm publish
```

### Publishing Checklist

Before publishing:

- [ ] Update version in config file
- [ ] Regenerate SDK
- [ ] Test generated SDK thoroughly
- [ ] Update CHANGELOG
- [ ] Create git tag (e.g., `sdk-ts@0.1.1`)
- [ ] Run language-specific publish command

### Language-Specific Publishing

#### TypeScript (npm)
```bash
cd generated/typescript
npm login
npm publish --access public
```

#### Python (PyPI)
```bash
cd generated/python
python -m build
twine upload dist/*
```

#### Go (module)
```bash
cd generated/go
git tag v0.1.0
git push origin v0.1.0
# Users: go get github.com/yourorg/yourapi-go@v0.1.0
```

#### PHP (Packagist)
```bash
# 1. Push to GitHub
# 2. Submit to packagist.org
# 3. Add webhook for auto-updates
```

#### Rust (crates.io)
```bash
cd generated/rust
cargo login
cargo publish
```

#### Swift (CocoaPods)
```bash
cd generated/swift
pod spec lint
pod trunk push YourAPI.podspec
```

#### Ruby (RubyGems)
```bash
cd generated/ruby
gem build yourapi.gemspec
gem push yourapi-0.1.0.gem
```

#### Java (Maven Central)
```bash
cd generated/java
mvn clean deploy -P release
```

#### Kotlin (Maven Central)
```bash
cd generated/kotlin
./gradlew publish
```

## Troubleshooting

### Common Issues

#### OpenAPI Generator Not Found
```bash
# Install globally
npm install -g @openapitools/openapi-generator-cli

# Or use npx
npx @openapitools/openapi-generator-cli generate ...
```

#### Invalid OpenAPI Spec
```bash
# Validate your spec (YAML)
openapi-generator-cli validate -i sdk/openapi.yaml

# Validate your spec (JSON)
openapi-generator-cli validate -i sdk/openapi.json

# Use online validator
# https://editor.swagger.io/
```

#### Generation Fails for Specific Language
```bash
# Check language-specific dependencies
./sdk/generate.sh -l typescript  # More detailed output

# Review error logs
# Check configs/{language}.json for typos
```

#### Wrapper Code Not Copied
```bash
# Ensure wrapper directory exists
ls -la sdk/wrappers/{language}/

# Check permissions
chmod +x sdk/generate.sh

# Manually copy wrapper
cp -r sdk/wrappers/typescript/* sdk/generated/typescript/
```

### Getting Help

1. Check [OpenAPI Generator docs](https://openapi-generator.tech/docs/generators)
2. Review language-specific wrapper README
3. Enable debug mode in wrapper code
4. Open an issue with:
   - OpenAPI spec (redacted)
   - Generator config
   - Error output
   - Language and version

## Advanced Usage

### Custom OpenAPI Transformations

Transform your spec before generation:

```bash
# Example: Add custom extension to YAML
cat openapi.yaml | \
  yq '.info["x-sdk-version"] = "custom"' > transformed.yaml

./sdk/generate.sh -o transformed.yaml

# Example: Convert YAML to JSON
yq eval -o=json openapi.yaml > openapi.json
./sdk/generate.sh -o openapi.json -l typescript
```

### Selective Generation

Generate only changed languages:

```bash
# Check what changed
git diff --name-only sdk/openapi.yaml sdk/configs/

# Generate only affected
./sdk/generate.sh -l typescript,python
```

### Local Testing

Test SDKs locally before publishing:

```bash
# TypeScript - npm link
cd generated/typescript
npm link
cd ~/your-test-project
npm link @yourorg/yourapi

# Python - editable install
cd generated/python
pip install -e .

# Go - replace directive
go mod edit -replace github.com/yourorg/yourapi=../sdk/generated/go
```

## Best Practices

1. **Version Control**: Commit `openapi.yaml`, `configs/`, and `wrappers/`. Don't commit `generated/`.

2. **CI/CD**: Use GitHub Actions workflow for automated generation.

3. **Testing**: Write integration tests that use generated SDKs.

4. **Documentation**: Keep wrapper README files up to date.

5. **Versioning**: Use semantic versioning for each SDK independently.

6. **Breaking Changes**: Increment major version when OpenAPI spec changes in breaking ways.

## Examples

See individual wrapper directories for complete examples:

- `wrappers/typescript/README.md`
- `wrappers/python/README.md`
- `wrappers/go/README.md`
- etc.

## Contributing

To add support for a new language:

1. Create config file in `configs/{language}.json`
2. Create wrapper in `wrappers/{language}/`
3. Add generation logic to `generate.sh`
4. Add CI job to `.github/workflows/sdk-generate.yml`
5. Document in wrapper README

---

**Need help?** Open an issue or check the main [README](../README.md).

