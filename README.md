# Multi-Language SDK Generator

Production-ready SDK generation system that creates high-quality, type-safe SDKs for 8 programming languages from a single OpenAPI specification.

## ✨ Features

- **8 Language Support**: TypeScript, Python, Go, PHP, Rust, Ruby, Java, Kotlin
- **Production-Ready Wrappers**: Built-in auth, retries, pagination, error handling, and telemetry
- **Automated CI/CD**: GitHub Actions workflow for continuous SDK generation and publishing
- **Flexible Generation**: Generate all SDKs or select specific languages
- **Custom OpenAPI Support**: Use your own OpenAPI YAML specification
- **Zero-Config**: Works out of the box with sensible defaults

## 🚀 Quick Start

### Installation

**Option 1: Install from npm (Recommended)**

```bash
# Install globally
npm install -g saligen

# Use it anywhere
saligen -o swagger.yml -c
```

**Option 2: Install locally in a project**

```bash
npm install --save-dev saligen

# Use with npx
npx saligen -o swagger.yml -c
```

**Option 3: Clone and use locally**

```bash
git clone https://github.com/devdraft/saligen.git
cd saligen
./setup.sh
./sdk/generate.sh -o swagger.yml -c
```

### Prerequisites

- **Node.js 16+** (for OpenAPI Generator CLI)
- **Java 11+** (required by OpenAPI Generator CLI)
  - Check version: `java -version`
  - Install on macOS: `brew install openjdk@11`
  - Or download from: [Adoptium](https://adoptium.net/)
  - Set JAVA_HOME if needed: `export JAVA_HOME=$(/usr/libexec/java_home -v 11)`
- Language-specific tools for building SDKs:
  - Node.js 16+ for TypeScript
  - Python 3.8+ for Python
  - Go 1.19+ for Go
  - PHP 8.1+ for PHP
  - Rust 1.70+ for Rust
  - Ruby 3.0+ for Ruby
  - Java 11+ for Java/Kotlin

**Note:** The OpenAPI Generator CLI is included as an npm dependency, but Java 11+ must be installed separately.

### Installation

**Option 1: Automatic Setup (Recommended)**
```bash
# Clone or download the repository
cd SDKgen

# Run the setup script
./setup.sh
```

**Option 2: Manual Setup**
```bash
# Clone or download the repository
cd SDKgen

# Install dependencies (OpenAPI Generator CLI)
cd sdk
npm install
cd ..
```

**Option 3: Let it auto-install**

The generator will automatically run `npm install` if dependencies are missing when you first run it.

### First-Time Setup (Auto-Configuration)

On your first run, the script automatically detects that configs haven't been customized and starts the configuration wizard:

```bash
# First run - automatically prompts for configuration
./sdk/generate.sh -o swagger.yml

# Or pre-specify the SDK name
./sdk/generate.sh -o swagger.yml -n myapi
```

The wizard will guide you through:
- ✅ Setting your SDK/project name
- ✅ Configuring organization details  
- ✅ Customizing package names and settings
- ✅ Automatically generating all configured SDKs

### Subsequent Runs (Quick Generation)

After initial configuration, simply run the script to generate:

```bash
# Generate all SDKs with your configured settings
./sdk/generate.sh

# Generate specific SDKs
./sdk/generate.sh -l typescript

# With custom OpenAPI spec
./sdk/generate.sh -o path/to/your/openapi.yaml -l typescript,python
```

### Reconfigure Anytime

Need to update your SDK configuration? Use the `-c` flag:

```bash
# Force reconfiguration
./sdk/generate.sh -c

# Reconfigure with custom OpenAPI spec
./sdk/generate.sh -o swagger.yml -c
```

## 📁 Project Structure

```
SDKgen/
├── sdk/
│   ├── openapi.yaml              # Your OpenAPI specification (YAML or JSON)
│   ├── configs/                  # Generator configs per language
│   │   ├── typescript.json
│   │   ├── python.json
│   │   ├── go.json
│   │   ├── php.json
│   │   ├── rust.json
│   │   ├── ruby.json
│   │   ├── java.json
│   │   └── kotlin.json
│   ├── wrappers/                 # Production wrapper code
│   │   ├── typescript/           # TypeScript wrapper with retries, auth, etc.
│   │   ├── python/               # Python wrapper
│   │   ├── go/                   # Go wrapper
│   │   ├── php/                  # PHP wrapper
│   │   ├── rust/                 # Rust wrapper
│   │   ├── ruby/                 # Ruby wrapper
│   │   ├── java/                 # Java wrapper
│   │   └── kotlin/               # Kotlin wrapper
│   ├── generated/                # Output directory for generated SDKs
│   │   ├── typescript/
│   │   ├── python/
│   │   └── ...
│   └── generate.sh               # Generation script
├── .github/
│   └── workflows/
│       └── sdk-generate.yml      # CI/CD workflow
└── README.md
```

## 🎯 Supported Languages

| Language   | Generator        | Features                                           |
|------------|------------------|----------------------------------------------------|
| TypeScript | typescript-axios | Async/await, type safety, axios client             |
| Python     | python           | Type hints, generators, urllib3                    |
| Go         | go               | Context support, zero dependencies                 |
| PHP        | php              | PSR-4, composer, modern PHP 8.1+                   |
| Rust       | rust             | Async/await, tokio, type safety                    |
| Ruby       | ruby             | Enumerators, zero dependencies                     |
| Java       | java             | Maven, OkHttp, Gson, Java 11+                      |
| Kotlin     | kotlin           | Coroutines, data classes, modern Kotlin            |

## 🛠️ Production Features

All generated SDKs include production-ready features:

### Authentication
- API Key authentication
- Bearer token authentication
- Custom header support

### Retry Logic
- Automatic retries for 429, 500, 502, 503, 504 status codes
- Exponential backoff with max 8-second cap
- Respects `Retry-After` headers

### Pagination
- Cursor-based pagination helpers
- Page-based pagination support
- Async iterators/generators for streaming results

### Error Handling
- Normalized error types across all languages
- Structured error information (status, code, message, details, requestId)
- Type-safe error handling

### Telemetry
- SDK version headers (`X-SDK-Version`, `X-SDK-Language`)
- Custom User-Agent
- Request ID propagation

### Configuration
- Configurable timeouts (default: 15s)
- Configurable max retries (default: 3)
- Debug logging support
- Custom headers

## 📚 Documentation

Each generated SDK includes comprehensive documentation:

- Quick start guide
- Configuration options
- Authentication examples
- Pagination patterns
- Error handling
- Environment-specific configuration
- Complete API reference

See individual wrapper directories for language-specific documentation:
- [TypeScript SDK](sdk/wrappers/typescript/README.md)
- [Python SDK](sdk/wrappers/python/README.md)
- [Go SDK](sdk/wrappers/go/README.md)
- [PHP SDK](sdk/wrappers/php/README.md)
- [Rust SDK](sdk/wrappers/rust/README.md)
- [Ruby SDK](sdk/wrappers/ruby/README.md)
- [Java SDK](sdk/wrappers/java/README.md)
- [Kotlin SDK](sdk/wrappers/kotlin/README.md)

## 🔄 CI/CD Integration

The included GitHub Actions workflow automatically:

1. Validates your OpenAPI spec
2. Generates SDKs for all languages
3. Builds and tests each SDK
4. Uploads artifacts
5. Publishes to package registries (on tagged releases)

### Triggering SDK Generation

```bash
# Automatic trigger on changes to:
# - sdk/openapi.yaml
# - sdk/configs/**
# - sdk/wrappers/**

# Manual trigger via GitHub UI
# Go to Actions → Generate SDKs → Run workflow

# Tag-based publishing
git tag sdk-ts@0.1.0
git tag sdk-py@0.1.0
git push --tags
```

### Required Secrets

For automated publishing, configure these secrets in your GitHub repository:

- `NPM_TOKEN` - npm publishing
- `PYPI_TOKEN` - PyPI publishing
- `CARGO_TOKEN` - crates.io publishing
- `RUBYGEMS_TOKEN` - RubyGems publishing
- `MAVEN_USERNAME` / `MAVEN_PASSWORD` - Maven Central
- `GPG_PASSPHRASE` - For Maven artifact signing

## 🔧 Customization

### Update OpenAPI Spec

1. Edit `sdk/openapi.yaml` (or `.json`) with your API specification
2. Run `./sdk/generate.sh` to regenerate SDKs
3. Review generated code in `sdk/generated/`

**Supported formats:** `.yaml`, `.yml`, `.json`

### Modify Generator Config

Edit language-specific config files in `sdk/configs/` to customize:
- Package names and versions
- Additional generator options
- Code style preferences

### Extend Wrappers

Wrapper code in `sdk/wrappers/` can be extended with:
- Custom API methods
- Additional helper functions
- Business logic specific to your API

## 📦 Publishing SDKs

### npm (TypeScript)
```bash
cd sdk/generated/typescript
npm version patch
npm publish --access public
```

### PyPI (Python)
```bash
cd sdk/generated/python
python -m build
twine upload dist/*
```

### Go
```bash
cd sdk/generated/go
git tag v0.1.0
git push origin v0.1.0
```

### Composer (PHP)
```bash
cd sdk/generated/php
# Submit to Packagist.org
```

### crates.io (Rust)
```bash
cd sdk/generated/rust
cargo publish
```

### RubyGems
```bash
cd sdk/generated/ruby
gem build yourapi.gemspec
gem push yourapi-0.1.0.gem
```

### Maven Central (Java/Kotlin)
```bash
cd sdk/generated/java
mvn deploy
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check the documentation in `sdk/README.md`
- Review language-specific README files

## 🌟 Credits

Built with:
- [OpenAPI Generator](https://openapi-generator.tech/)
- Language-specific HTTP clients and JSON libraries
- GitHub Actions for CI/CD

---

**Ready to generate production-ready SDKs?** Replace `sdk/openapi.yaml` with your API specification and run `./sdk/generate.sh`!

