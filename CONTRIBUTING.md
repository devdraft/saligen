# Contributing to SDKgen

Thank you for your interest in contributing! This document provides guidelines for contributing to the multi-language SDK generator.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourorg/sdkgen.git`
3. Create a branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Test your changes
6. Submit a pull request

## Development Setup

### Prerequisites

- Node.js 16+ (for OpenAPI Generator CLI)
- OpenAPI Generator CLI
- Language-specific tools for testing (Python, Go, etc.)

### Installation

```bash
# Install OpenAPI Generator
npm install -g @openapitools/openapi-generator-cli

# Test generation
./sdk/generate.sh -l typescript
```

## Project Structure

```
SDKgen/
├── sdk/
│   ├── openapi.yaml         # Sample OpenAPI spec
│   ├── configs/             # Generator configs per language
│   ├── wrappers/            # Production wrapper code
│   ├── generated/           # Output (gitignored)
│   └── generate.sh          # Main generation script
├── .github/workflows/       # CI/CD workflows
└── README.md
```

## Contributing Guidelines

### Adding a New Language

1. **Create Generator Config**
   ```bash
   # Create config file
   touch sdk/configs/newlang.json
   ```

2. **Create Wrapper**
   ```bash
   # Create wrapper directory
   mkdir -p sdk/wrappers/newlang
   ```

3. **Implement Wrapper Features**
   - Authentication (API Key, Bearer Token)
   - Retry logic with exponential backoff
   - Pagination helpers
   - Error normalization
   - Telemetry headers
   - Debug logging

4. **Add to Generation Script**
   Edit `sdk/generate.sh` and add case for new language

5. **Add CI Job**
   Add workflow job in `.github/workflows/sdk-generate.yml`

6. **Document**
   Create `sdk/wrappers/newlang/README.md` with usage examples

### Improving Existing Wrappers

- Focus on production features (auth, retries, pagination)
- Maintain backward compatibility
- Add tests for new features
- Update documentation

### Code Style

#### Shell Scripts
- Use `#!/usr/bin/env bash`
- Set `set -e` for error handling
- Add comments for complex logic
- Use meaningful variable names

#### Language-Specific Code
Follow the idiomatic style for each language:
- **TypeScript**: Prettier, ESLint
- **Python**: Black, Ruff
- **Go**: gofmt, golint
- **PHP**: PSR-12
- **Rust**: rustfmt
- **Ruby**: RuboCop
- **Java**: Google Java Style
- **Kotlin**: ktlint

### Testing

Test your changes:

```bash
# Generate SDKs
./sdk/generate.sh

# Test specific language
cd sdk/generated/typescript
npm install
npm test

# Test generation script
./sdk/generate.sh -l typescript,python
./sdk/generate.sh -o custom.yaml
```

### Documentation

- Update README.md for major features
- Add inline comments for complex code
- Include usage examples
- Document breaking changes

## Pull Request Process

1. **Update Version**: If changing wrapper code, update version in config
2. **Test**: Ensure all SDKs generate successfully
3. **Document**: Update relevant documentation
4. **PR Description**: 
   - Describe what changed
   - Why the change is needed
   - How to test it
   - Any breaking changes

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How to test these changes

## Checklist
- [ ] Code follows project style
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

## Commit Messages

Use conventional commits:

```
feat: add Dart SDK support
fix: resolve TypeScript retry loop
docs: update Python wrapper README
chore: update dependencies
```

## Issue Reporting

When reporting issues:

1. Check existing issues first
2. Use issue template
3. Include:
   - OpenAPI spec (redacted)
   - Generation command used
   - Error output
   - Expected vs actual behavior
   - Environment (OS, tool versions)

## Feature Requests

Feature requests are welcome! Please:

1. Check if already requested
2. Describe the feature
3. Explain the use case
4. Suggest implementation (optional)

## Code Review

All submissions require review. We'll review:

- Code quality
- Test coverage
- Documentation
- Performance impact
- Breaking changes

## Community

- Be respectful and inclusive
- Help others learn
- Share knowledge
- Give constructive feedback

## Release Process

Maintainers handle releases:

1. Update version in configs
2. Regenerate SDKs
3. Create git tags
4. Publish to registries
5. Update changelog

## Questions?

- Open an issue
- Check documentation
- Review existing PRs

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🎉

