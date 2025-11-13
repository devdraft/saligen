# Publishing to npm

This guide explains how to publish the Multi-SDK Generator to npm so others can install and use it.

## Prerequisites

1. **npm account**: Create one at [npmjs.com](https://www.npmjs.com/signup)
2. **Login to npm**: `npm login`
3. **Update package.json**: Set your package name, author, repository, etc.

## Step 1: Update package.json

Edit `package.json` and update:

```json
{
  "name": "saligen",
  "version": "1.0.0",
  "author": "Your Name <your.email@example.com>",
  "repository": {
    "type": "git",
    "url": "https://github.com/devdraft/saligen"
  },
  "bugs": {
    "url": "https://github.com/devdraft/saligen/issues"
  },
  "homepage": "https://github.com/devdraft/saligen#readme"
}
```

**Important**: The package name must be unique on npm. Check availability:
```bash
npm search saligen
```

## Step 2: Test Locally

Before publishing, test the package locally:

```bash
# Build/test the package
npm test

# Test the CLI locally using npm link
npm link

# In another directory, test it
cd /tmp
mkdir test-sdkgen
cd test-sdkgen
npm link saligen

# Test the command
saligen --help
saligen -o /path/to/openapi.yaml -c

# Unlink when done
npm unlink saligen
cd /path/to/SDKgen
npm unlink
```

## Step 3: Prepare for Publishing

1. **Ensure .gitignore is correct** - Make sure `node_modules/` and `sdk/generated/` are ignored
2. **Check files to include** - The `files` field in package.json controls what gets published
3. **Update README.md** - Make sure installation instructions are clear

## Step 4: Publish

### Dry Run (Test without publishing)

```bash
npm publish --dry-run
```

This shows what files would be published without actually publishing.

### Publish to npm

```bash
# Publish public package
npm publish --access public

# Or if you set "private": false in package.json
npm publish
```

### Publish Beta/RC Version

```bash
npm version 1.0.0-beta.1
npm publish --tag beta
```

Users install with: `npm install multi-sdk-generator@beta`

## Step 5: Verify Publication

1. Check your package on npm: `https://www.npmjs.com/package/saligen`
2. Test installation:
   ```bash
   npm install -g saligen
   saligen --help
   ```

## Usage After Publishing

Users can install and use it like this:

```bash
# Install globally
npm install -g saligen

# Use the CLI
saligen -o swagger.yml -c

# Or install locally in a project
npm install --save-dev saligen
npx saligen -o swagger.yml
```

## Updating the Package

1. **Update version**:
   ```bash
   npm version patch  # 1.0.0 -> 1.0.1
   npm version minor  # 1.0.0 -> 1.1.0
   npm version major  # 1.0.0 -> 2.0.0
   ```

2. **Publish**:
   ```bash
   npm publish
   ```

## Package Structure

When published, npm includes:
- `bin/` - CLI scripts
- `sdk/` - All SDK generation files (configs, wrappers, generate.sh)
- `LICENSE` - License file
- `README.md` - Documentation
- `TESTING.md` - Testing guide

Excluded (via .gitignore):
- `node_modules/` - Installed by users
- `sdk/generated/` - Generated output
- `sdk/node_modules/` - Installed by postinstall script

## Troubleshooting

### Error: Package name already taken

Choose a different name in package.json:
```json
{
  "name": "@devdraft/saligen"
}
```

Or use a scoped package:
```json
{
  "name": "@yourusername/saligen",
  "publishConfig": {
    "access": "public"
  }
}
```

### Error: You must verify your email

Verify your email at npmjs.com before publishing.

### Error: Missing files

Check the `files` field in package.json includes all necessary files.

### Error: Permission denied

Make sure you're logged in: `npm login`
Check you own the package name or use a scoped package: `@yourusername/package-name`

## Best Practices

1. **Use semantic versioning** (major.minor.patch)
2. **Write clear release notes** in CHANGELOG.md
3. **Tag releases in git**: `git tag v1.0.0 && git push --tags`
4. **Test before publishing**: Always test locally first
5. **Keep dependencies updated**: Regularly update OpenAPI Generator CLI version

## Scoped Packages

For organization packages:

```json
{
  "name": "@yourorg/multi-sdk-generator",
  "publishConfig": {
    "access": "public"
  }
}
```

Publish with: `npm publish --access public`

