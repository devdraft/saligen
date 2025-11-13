# Saligen Architecture

This document describes the architecture and design decisions behind Saligen, the multi-language SDK generator.

## Overview

Saligen is a production-ready SDK generation system that creates type-safe, feature-rich SDKs for 9 programming languages from a single OpenAPI specification. It combines the power of OpenAPI Generator with custom production wrappers to deliver enterprise-grade SDKs.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Saligen Generator                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────┐  │
│  │   OpenAPI    │─────▶│   Config     │─────▶│ Generator│  │
│  │   Spec       │      │   Files      │      │  Script  │  │
│  │ (YAML/JSON)  │      │  (per lang)  │      │          │  │
│  └──────────────┘      └──────────────┘      └──────────┘  │
│                                                               │
│                          │                                    │
│                          ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         OpenAPI Generator CLI (npm)                   │   │
│  │  Generates base SDK code for each language            │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                    │
│                          ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Production Wrappers                           │   │
│  │  Adds: Auth, Retries, Pagination, Error Handling     │   │
│  └──────────────────────────────────────────────────────┘   │
│                          │                                    │
│                          ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Generated SDKs                                │   │
│  │  TypeScript, Python, Go, PHP, Rust, Swift, etc.      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Generation Script (`sdk/generate.sh`)

The main orchestration script that:
- Validates OpenAPI specifications (YAML/JSON)
- Detects first-time setup and triggers configuration wizard
- Manages OpenAPI Generator CLI installation
- Generates SDKs for selected languages
- Copies production wrapper code
- Handles errors and provides user feedback

**Key Features:**
- Path detection (local vs npm package installation)
- Interactive configuration mode
- Language-specific generation logic
- Automatic dependency management

### 2. Configuration Files (`sdk/configs/`)

Language-specific JSON configuration files that control:
- Package names and versions
- Code generation options
- Library choices (e.g., axios for TypeScript, requests for Python)
- Code style preferences
- Organization and repository details

**Supported Languages:**
- TypeScript (`typescript.json`)
- Python (`python.json`)
- Go (`go.json`)
- PHP (`php.json`)
- Rust (`rust.json`)
- Swift (`swift.json`)
- Ruby (`ruby.json`)
- Java (`java.json`)
- Kotlin (`kotlin.json`)

### 3. Production Wrappers (`sdk/wrappers/`)

Custom code layers that add enterprise features to generated SDKs:

#### Common Features Across All Languages:

1. **Authentication**
   - API Key support
   - Bearer token support
   - Custom header injection

2. **Retry Logic**
   - Exponential backoff
   - Configurable max retries
   - Respects `Retry-After` headers
   - Retries on: 429, 500, 502, 503, 504

3. **Pagination**
   - Cursor-based pagination helpers
   - Page-based pagination helpers
   - Async iterators/generators

4. **Error Handling**
   - Normalized error types
   - Structured error information
   - Request ID propagation

5. **Telemetry**
   - SDK version headers
   - Custom User-Agent
   - Request/response logging

6. **Configuration**
   - Timeout management
   - Debug mode
   - Custom headers

### 4. CLI Entry Point (`bin/sdk-generate.js`)

Node.js wrapper that:
- Detects package installation location
- Spawns the bash generation script
- Handles environment variables
- Provides cross-platform compatibility

## Data Flow

### Generation Process

1. **Input**: OpenAPI specification (YAML/JSON)
2. **Configuration**: User provides SDK name, org details via wizard
3. **Generation**: OpenAPI Generator creates base SDK code
4. **Enhancement**: Wrapper code is copied to generated SDKs
5. **Output**: Production-ready SDKs in `sdk/generated/`

### Configuration Flow

```
User runs: saligen -o swagger.yml -c
    │
    ├─▶ Check if first run (default configs detected)
    │
    ├─▶ Interactive wizard prompts for:
    │   - SDK name
    │   - Organization details
    │   - Email, GitHub, version
    │   - npm package settings
    │
    └─▶ Update all 9 language config files
        └─▶ Generate SDKs
```

## Design Decisions

### Why OpenAPI Generator?

- **Mature**: Battle-tested, widely used
- **Comprehensive**: Supports 50+ languages
- **Maintained**: Active community and regular updates
- **Standard**: Follows OpenAPI specification

### Why Custom Wrappers?

OpenAPI Generator creates functional SDKs but lacks:
- Production-grade retry logic
- Standardized error handling
- Pagination helpers
- Telemetry and observability
- Consistent API across languages

Wrappers bridge this gap by providing:
- Consistent developer experience
- Enterprise-ready features out of the box
- Best practices built-in
- Reduced boilerplate for users

### Why npm Package?

- **Accessibility**: Easy installation via `npm install -g saligen`
- **Portability**: Works on Windows, macOS, Linux
- **Dependency Management**: Bundles OpenAPI Generator CLI
- **Version Control**: Semantic versioning
- **Distribution**: Simple publishing to npm registry

### Why Bash Script?

- **Compatibility**: Works across Unix-like systems
- **Flexibility**: Easy to extend and modify
- **Integration**: Seamless with OpenAPI Generator CLI
- **User Experience**: Rich terminal output with colors

## File Structure

```
saligen/
├── bin/
│   └── sdk-generate.js          # CLI entry point
├── sdk/
│   ├── generate.sh              # Main generation script
│   ├── configs/                 # Language-specific configs
│   │   ├── typescript.json
│   │   ├── python.json
│   │   └── ...
│   ├── wrappers/                # Production wrapper code
│   │   ├── typescript/
│   │   ├── python/
│   │   └── ...
│   ├── generated/               # Output directory (gitignored)
│   └── package.json             # OpenAPI Generator CLI dependency
├── package.json                 # npm package definition
├── README.md                    # User documentation
├── ARCHITECTURE.md              # This file
└── .gitignore                   # Ignore generated files
```

## Extension Points

### Adding a New Language

1. **Create config file**: `sdk/configs/newlang.json`
2. **Create wrapper**: `sdk/wrappers/newlang/`
3. **Add to generator**: Update `generate_sdk()` function in `generate.sh`
4. **Update docs**: Add language to README

### Customizing Wrappers

Wrappers are copied as-is to generated SDKs. To customize:
1. Edit wrapper code in `sdk/wrappers/{language}/`
2. Regenerate SDKs
3. Wrapper code is merged with generated code

### Adding Features

New features can be added to:
- **Wrappers**: Language-specific implementations
- **Generator script**: Cross-language logic
- **Config files**: Language-specific options

## Performance Considerations

- **Parallel Generation**: Languages are generated sequentially (can be parallelized)
- **Caching**: OpenAPI Generator CLI is cached in `node_modules`
- **Incremental**: Only regenerates changed languages
- **Selective**: Can generate specific languages with `-l` flag

## Security Considerations

- **No Code Execution**: Generated code is static, no eval/exec
- **Dependency Management**: Pinned OpenAPI Generator version
- **Input Validation**: OpenAPI spec validation before generation
- **Path Safety**: All paths are validated and sanitized

## Future Enhancements

- [ ] Parallel language generation
- [ ] Template customization system
- [ ] Plugin architecture for wrappers
- [ ] CI/CD integration templates
- [ ] Multi-version SDK support
- [ ] Custom generator templates
- [ ] SDK testing framework
- [ ] Performance benchmarking

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to Saligen.

## License

MIT License - see [LICENSE](LICENSE) for details.

