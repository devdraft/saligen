#!/usr/bin/env bash

#######################################
# Multi-Language SDK Generator
#
# Usage:
#   ./generate.sh [OPTIONS]
#   saligen [OPTIONS]  (when installed via npm)
#
# Options:
#   -l, --language LANG    Generate SDK for specific language(s) (comma-separated)
#                          Available: typescript, python, go, php, rust, ruby, java, kotlin, all
#   -o, --openapi PATH     Path to OpenAPI spec (YAML or JSON) (default: sdk/openapi.yaml)
#                          Supported formats: .yaml, .yml, .json
#   -c, --configure        Force interactive configuration mode
#   -n, --name NAME        SDK/project name (pre-fills configuration prompt)
#   -h, --help             Show this help message
#
# Note: First-time setup automatically triggers configuration wizard
#
# Examples:
#   ./generate.sh -o swagger.yml                     # First run: auto-configures, then generates
#   ./generate.sh -o swagger.yml -n myapi            # First run: pre-fill SDK name
#   ./generate.sh                                    # Subsequent runs: just generate
#   ./generate.sh -c                                 # Force reconfiguration anytime
#   ./generate.sh -l typescript,python               # Generate specific languages only
#   ./generate.sh -o custom-api.yaml -l go           # Use custom spec, generate Go only
#######################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Detect if running from npm package installation
# If SDKGEN_PACKAGE_DIR is set, we're running from npm install
if [ -n "$SDKGEN_PACKAGE_DIR" ]; then
    # Running from npm package
    SCRIPT_DIR="$SDKGEN_PACKAGE_DIR/sdk"
    BASE_DIR="$SDKGEN_PACKAGE_DIR"
else
    # Running from local development
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# Default values
DEFAULT_OPENAPI_PATH="$SCRIPT_DIR/openapi.yaml"
OPENAPI_PATH="${OPENAPI_PATH:-$DEFAULT_OPENAPI_PATH}"
LANGUAGES=""
ALL_LANGUAGES="typescript python go php rust ruby java kotlin"
CONFIGURE_MODE=false
SDK_NAME=""

# Supported OpenAPI file extensions
SUPPORTED_EXTENSIONS=("yaml" "yml" "json")

# Check if configs have been customized (detect first run)
check_first_run() {
    # Check TypeScript config for default placeholder values
    if [ -f "$SCRIPT_DIR/configs/typescript.json" ]; then
        local npm_name=$(grep -o '"npmName"[[:space:]]*:[[:space:]]*"[^"]*"' "$SCRIPT_DIR/configs/typescript.json" | cut -d'"' -f4)
        # If it's still "hiver" or "@yourorg/yourapi", it's likely first run
        if [ "$npm_name" = "hiver" ] || [ "$npm_name" = "@yourorg/yourapi" ]; then
            return 0  # First run
        fi
    fi
    return 1  # Already configured
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--language)
            LANGUAGES="$2"
            shift 2
            ;;
        -o|--openapi)
            OPENAPI_PATH="$2"
            shift 2
            ;;
        -c|--configure)
            CONFIGURE_MODE=true
            shift
            ;;
        -n|--name)
            SDK_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Multi-Language SDK Generator"
            echo ""
            echo "Usage: ./generate.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -l, --language LANG    Generate SDK for specific language(s) (comma-separated)"
            echo "                         Available: typescript, python, go, php, rust, ruby, java, kotlin, all"
            echo "  -o, --openapi PATH     Path to OpenAPI spec (YAML or JSON) (default: sdk/openapi.yaml)"
            echo "                         Supported formats: .yaml, .yml, .json"
            echo "  -c, --configure        Force interactive configuration mode"
            echo "  -n, --name NAME        SDK/project name (pre-fills configuration prompt)"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Note: First-time setup automatically triggers configuration wizard"
            echo ""
            echo "Examples:"
            echo "  ./generate.sh -o swagger.yml                     # First run: auto-configures, then generates"
            echo "  ./generate.sh -o swagger.yml -n myapi            # First run: pre-fill SDK name"
            echo "  ./generate.sh                                    # Subsequent runs: just generate"
            echo "  ./generate.sh -c                                 # Force reconfiguration anytime"
            echo "  ./generate.sh -l typescript,python               # Generate specific languages only"
            echo "  ./generate.sh -o custom-api.yaml -l go           # Use custom spec, generate Go only"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            echo "Run './generate.sh --help' for usage information"
            exit 1
            ;;
    esac
done

# Auto-enable configure mode if this is the first run (configs not customized)
if [ "$CONFIGURE_MODE" = false ]; then
    if check_first_run; then
        echo -e "${YELLOW}⚠ First-time setup detected! Starting configuration wizard...${NC}"
        echo ""
        CONFIGURE_MODE=true
    fi
fi

# Determine which languages to generate
if [ -z "$LANGUAGES" ] || [ "$LANGUAGES" = "all" ]; then
    LANGUAGES_TO_GENERATE=$ALL_LANGUAGES
else
    LANGUAGES_TO_GENERATE=$(echo "$LANGUAGES" | tr ',' ' ')
fi

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Multi-Language SDK Generator           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Interactive Configuration Mode
if [ "$CONFIGURE_MODE" = true ]; then
    echo -e "${CYAN}Interactive Configuration Mode${NC}"
    echo ""
    
    # Prompt helper function
    prompt_input() {
        local prompt_text="$1"
        local default_value="$2"
        local user_input
        
        if [ -n "$default_value" ]; then
            echo -e "${YELLOW}$prompt_text${NC} ${GREEN}[$default_value]${NC}" >&2
        else
            echo -e "${YELLOW}$prompt_text${NC}" >&2
        fi
        
        read -r user_input
        
        if [ -z "$user_input" ]; then
            echo "$default_value"
        else
            echo "$user_input"
        fi
    }
    
    prompt_yes_no() {
        local prompt_text="$1"
        local default_value="$2"
        local user_input
        
        if [ "$default_value" = "y" ]; then
            echo -e "${YELLOW}$prompt_text${NC} ${GREEN}[Y/n]${NC}" >&2
        else
            echo -e "${YELLOW}$prompt_text${NC} ${GREEN}[y/N]${NC}" >&2
        fi
        
        read -r user_input
        user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
        
        if [ -z "$user_input" ]; then
            echo "$default_value"
        else
            echo "${user_input:0:1}"
        fi
    }
    
    # Get SDK configuration
    if [ -z "$SDK_NAME" ]; then
        SDK_NAME=$(prompt_input "Enter your SDK/project name (lowercase, no spaces):" "myapi")
        SDK_NAME=$(echo "$SDK_NAME" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    fi
    
    ORG_NAME=$(prompt_input "Enter your organization/company name:" "MyOrg")
    EMAIL=$(prompt_input "Enter your contact email:" "api@example.com")
    VERSION=$(prompt_input "Enter the initial version:" "0.1.0")
    GITHUB_USER=$(prompt_input "Enter your GitHub username/org:" "myorg")
    WEBSITE=$(prompt_input "Enter your website (optional):" "https://example.com")
    
    echo ""
    SCOPED_NPM=$(prompt_yes_no "Use scoped npm package (e.g., @org/package)?" "n")
    if [ "$SCOPED_NPM" = "y" ]; then
        NPM_SCOPE=$(prompt_input "Enter npm scope (without @):" "$GITHUB_USER")
        NPM_NAME="@$NPM_SCOPE/$SDK_NAME"
    else
        NPM_NAME="$SDK_NAME"
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}Configuration Summary:${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "  SDK Name:      $SDK_NAME" >&2
    echo -e "  Organization:  $ORG_NAME" >&2
    echo -e "  Email:         $EMAIL" >&2
    echo -e "  Version:       $VERSION" >&2
    echo -e "  GitHub:        $GITHUB_USER" >&2
    echo -e "  NPM Package:   $NPM_NAME" >&2
    echo "" >&2
    
    CONFIRM=$(prompt_yes_no "Update configs and generate SDKs?" "y")
    if [ "$CONFIRM" != "y" ]; then
        echo -e "${YELLOW}Configuration cancelled${NC}" >&2
        exit 0
    fi
    
    echo ""
    echo -e "${BLUE}Updating configuration files...${NC}"
    
    # Update TypeScript config
    cat > "$SCRIPT_DIR/configs/typescript.json" << EOF
{
  "npmName": "$NPM_NAME",
  "npmVersion": "$VERSION",
  "supportsES6": true,
  "withSeparateModelsAndApi": true,
  "modelPropertyNaming": "camelCase",
  "useSingleRequestParameter": true,
  "usePromises": true,
  "apiPackage": "apis",
  "modelPackage": "models",
  "withInterfaces": true,
  "stringEnums": true
}
EOF
    
    # Update Python config
    cat > "$SCRIPT_DIR/configs/python.json" << EOF
{
  "packageName": "$SDK_NAME",
  "projectName": "${SDK_NAME}-sdk",
  "packageVersion": "$VERSION",
  "httpUserAgent": "${SDK_NAME}-python-sdk/$VERSION",
  "packageUrl": "https://github.com/$GITHUB_USER/${SDK_NAME}-python",
  "enumPropertyNaming": "original",
  "library": "urllib3",
  "generateSourceCodeOnly": false
}
EOF
    
    # Update Go config
    cat > "$SCRIPT_DIR/configs/go.json" << EOF
{
  "packageName": "$SDK_NAME",
  "packageVersion": "$VERSION",
  "enumClassPrefix": true,
  "isGoSubmodule": true,
  "hideGenerationTimestamp": true,
  "useOneOfDiscriminatorLookup": true,
  "withGoCodegenComment": false,
  "structPrefix": false,
  "generateInterfaces": true
}
EOF
    
    # Update PHP config
    ORG_PASCAL=$(echo "$ORG_NAME" | sed 's/[^a-zA-Z0-9]//g')
    SDK_PASCAL=$(echo "$SDK_NAME" | sed 's/[^a-zA-Z0-9]//g' | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    cat > "$SCRIPT_DIR/configs/php.json" << EOF
{
  "invokerPackage": "${ORG_PASCAL}\\\\${SDK_PASCAL}",
  "modelPackage": "${ORG_PASCAL}\\\\${SDK_PASCAL}\\\\Model",
  "apiPackage": "${ORG_PASCAL}\\\\${SDK_PASCAL}\\\\Api",
  "packageName": "$(echo $GITHUB_USER | tr '[:upper:]' '[:lower:]')/${SDK_NAME}",
  "gitUserId": "$GITHUB_USER",
  "gitRepoId": "${SDK_NAME}-php",
  "artifactVersion": "$VERSION",
  "variableNamingConvention": "camelCase",
  "phpVersion": "8.1",
  "srcBasePath": "src"
}
EOF
    
    # Update Rust config
    cat > "$SCRIPT_DIR/configs/rust.json" << EOF
{
  "packageName": "$SDK_NAME",
  "packageVersion": "$VERSION",
  "library": "reqwest",
  "useSingleRequestParameter": true,
  "supportAsync": true,
  "supportMultipleResponses": true,
  "bestFitInt": true
}
EOF
    
    # Update Ruby config
    cat > "$SCRIPT_DIR/configs/ruby.json" << EOF
{
  "gemName": "$SDK_NAME",
  "moduleName": "$SDK_CAPITALIZED",
  "gemVersion": "$VERSION",
  "gemAuthor": "$ORG_NAME",
  "gemAuthorEmail": "$EMAIL",
  "gemHomepage": "https://github.com/$GITHUB_USER/${SDK_NAME}-ruby",
  "gemLicense": "MIT",
  "gemSummary": "Ruby SDK for $SDK_CAPITALIZED",
  "gemDescription": "Official Ruby SDK for $SDK_CAPITALIZED",
  "library": "faraday",
  "httpLibrary": "faraday"
}
EOF
    
    # Update Java config
    JAVA_PACKAGE=$(echo "$GITHUB_USER" | tr '[:upper:]' '[:lower:]' | tr '-' '.')
    cat > "$SCRIPT_DIR/configs/java.json" << EOF
{
  "groupId": "com.$JAVA_PACKAGE",
  "artifactId": "${SDK_NAME}-sdk",
  "artifactVersion": "$VERSION",
  "artifactDescription": "Java SDK for $SDK_NAME",
  "artifactUrl": "https://github.com/$GITHUB_USER/${SDK_NAME}-java",
  "developerName": "$ORG_NAME",
  "developerEmail": "$EMAIL",
  "developerOrganization": "$ORG_NAME",
  "developerOrganizationUrl": "$WEBSITE",
  "scmConnection": "scm:git:git://github.com/$GITHUB_USER/${SDK_NAME}-java.git",
  "scmDeveloperConnection": "scm:git:ssh://github.com:$GITHUB_USER/${SDK_NAME}-java.git",
  "scmUrl": "https://github.com/$GITHUB_USER/${SDK_NAME}-java",
  "licenseName": "MIT",
  "licenseUrl": "https://opensource.org/licenses/MIT",
  "invokerPackage": "com.$JAVA_PACKAGE.${SDK_NAME}",
  "apiPackage": "com.$JAVA_PACKAGE.${SDK_NAME}.api",
  "modelPackage": "com.$JAVA_PACKAGE.${SDK_NAME}.model",
  "library": "okhttp-gson",
  "dateLibrary": "java8",
  "java8": true,
  "hideGenerationTimestamp": true,
  "serializableModel": true,
  "useRuntimeException": true
}
EOF
    
    # Update Kotlin config
    cat > "$SCRIPT_DIR/configs/kotlin.json" << EOF
{
  "groupId": "com.$JAVA_PACKAGE",
  "artifactId": "${SDK_NAME}-sdk-kotlin",
  "artifactVersion": "$VERSION",
  "packageName": "com.$JAVA_PACKAGE.${SDK_NAME}",
  "library": "jvm-okhttp4",
  "dateLibrary": "java8",
  "serializationLibrary": "gson",
  "enumPropertyNaming": "original",
  "requestDateConverter": "toJson",
  "useCoroutines": true,
  "sourceFolder": "src/main/kotlin"
}
EOF
    
    echo -e "${GREEN}✓ All configuration files updated${NC}"
    echo ""
fi

# Function to increment version (patch version)
increment_version() {
    local version=$1
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    local patch=$(echo "$version" | cut -d. -f3)
    
    # Increment patch version
    patch=$((patch + 1))
    echo "$major.$minor.$patch"
}

# Function to read current version from generated SDK or config
get_current_version() {
    # First, try to get version from generated TypeScript package.json (most reliable)
    local generated_pkg="$SCRIPT_DIR/generated/typescript/package.json"
    if [ -f "$generated_pkg" ]; then
        local version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$generated_pkg" | cut -d'"' -f4)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Fallback: try config files
    local config_file="$SCRIPT_DIR/configs/typescript.json"
    if [ -f "$config_file" ]; then
        local version=$(grep -o '"npmVersion"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" | cut -d'"' -f4)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Fallback: try Python config
    config_file="$SCRIPT_DIR/configs/python.json"
    if [ -f "$config_file" ]; then
        local version=$(grep -o '"packageVersion"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" | cut -d'"' -f4)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi
    
    # Default version if nothing found
    echo "0.0.1"
}

# Function to update version in all config files
update_all_versions() {
    local new_version=$1
    local config_dir="$SCRIPT_DIR/configs"
    
    echo -e "${BLUE}Incrementing version to ${CYAN}$new_version${NC}..."
    
    # Update TypeScript config
    if [ -f "$config_dir/typescript.json" ]; then
        # Use a temporary file and then replace
        if command -v jq &> /dev/null; then
            jq ".npmVersion = \"$new_version\"" "$config_dir/typescript.json" > "$config_dir/typescript.json.tmp" && mv "$config_dir/typescript.json.tmp" "$config_dir/typescript.json"
        else
            # Fallback: use sed (less reliable but works)
            sed -i.bak "s/\"npmVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"npmVersion\": \"$new_version\"/" "$config_dir/typescript.json" && rm -f "$config_dir/typescript.json.bak"
        fi
    fi
    
    # Update Python config
    if [ -f "$config_dir/python.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".packageVersion = \"$new_version\" | .httpUserAgent = (.httpUserAgent | split(\"/\")[0] + \"/$new_version\")" "$config_dir/python.json" > "$config_dir/python.json.tmp" && mv "$config_dir/python.json.tmp" "$config_dir/python.json"
        else
            sed -i.bak "s/\"packageVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"packageVersion\": \"$new_version\"/" "$config_dir/python.json" && rm -f "$config_dir/python.json.bak"
        fi
    fi
    
    # Update Go config
    if [ -f "$config_dir/go.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".packageVersion = \"$new_version\"" "$config_dir/go.json" > "$config_dir/go.json.tmp" && mv "$config_dir/go.json.tmp" "$config_dir/go.json"
        else
            sed -i.bak "s/\"packageVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"packageVersion\": \"$new_version\"/" "$config_dir/go.json" && rm -f "$config_dir/go.json.bak"
        fi
    fi
    
    # Update PHP config
    if [ -f "$config_dir/php.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".artifactVersion = \"$new_version\"" "$config_dir/php.json" > "$config_dir/php.json.tmp" && mv "$config_dir/php.json.tmp" "$config_dir/php.json"
        else
            sed -i.bak "s/\"artifactVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"artifactVersion\": \"$new_version\"/" "$config_dir/php.json" && rm -f "$config_dir/php.json.bak"
        fi
    fi
    
    # Update Rust config
    if [ -f "$config_dir/rust.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".packageVersion = \"$new_version\"" "$config_dir/rust.json" > "$config_dir/rust.json.tmp" && mv "$config_dir/rust.json.tmp" "$config_dir/rust.json"
        else
            sed -i.bak "s/\"packageVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"packageVersion\": \"$new_version\"/" "$config_dir/rust.json" && rm -f "$config_dir/rust.json.bak"
        fi
    fi
    
    # Update Ruby config
    if [ -f "$config_dir/ruby.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".gemVersion = \"$new_version\"" "$config_dir/ruby.json" > "$config_dir/ruby.json.tmp" && mv "$config_dir/ruby.json.tmp" "$config_dir/ruby.json"
        else
            sed -i.bak "s/\"gemVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"gemVersion\": \"$new_version\"/" "$config_dir/ruby.json" && rm -f "$config_dir/ruby.json.bak"
        fi
    fi
    
    # Update Java config
    if [ -f "$config_dir/java.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".artifactVersion = \"$new_version\"" "$config_dir/java.json" > "$config_dir/java.json.tmp" && mv "$config_dir/java.json.tmp" "$config_dir/java.json"
        else
            sed -i.bak "s/\"artifactVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"artifactVersion\": \"$new_version\"/" "$config_dir/java.json" && rm -f "$config_dir/java.json.bak"
        fi
    fi
    
    # Update Kotlin config
    if [ -f "$config_dir/kotlin.json" ]; then
        if command -v jq &> /dev/null; then
            jq ".artifactVersion = \"$new_version\"" "$config_dir/kotlin.json" > "$config_dir/kotlin.json.tmp" && mv "$config_dir/kotlin.json.tmp" "$config_dir/kotlin.json"
        else
            sed -i.bak "s/\"artifactVersion\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"artifactVersion\": \"$new_version\"/" "$config_dir/kotlin.json" && rm -f "$config_dir/kotlin.json.bak"
        fi
    fi
    
    # Also update wrapper package.json files (they get copied over generated ones)
    # Update TypeScript wrapper
    local wrapper_pkg="$SCRIPT_DIR/wrappers/typescript/package.json"
    if [ -f "$wrapper_pkg" ]; then
        if command -v jq &> /dev/null; then
            jq ".version = \"$new_version\"" "$wrapper_pkg" > "$wrapper_pkg.tmp" && mv "$wrapper_pkg.tmp" "$wrapper_pkg"
        else
            sed -i.bak "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$new_version\"/" "$wrapper_pkg" && rm -f "$wrapper_pkg.bak"
        fi
    fi
    
    # Update Python wrapper files
    local python_setup="$SCRIPT_DIR/wrappers/python/setup.py"
    if [ -f "$python_setup" ]; then
        sed -i.bak "s/version=\"[^\"]*\"/version=\"$new_version\"/" "$python_setup" && rm -f "$python_setup.bak" 2>/dev/null || true
    fi
    
    local python_pyproject="$SCRIPT_DIR/wrappers/python/pyproject.toml"
    if [ -f "$python_pyproject" ]; then
        sed -i.bak "s/^version = \"[^\"]*\"/version = \"$new_version\"/" "$python_pyproject" && rm -f "$python_pyproject.bak" 2>/dev/null || true
    fi
    
    # Update Rust wrapper
    local rust_cargo="$SCRIPT_DIR/wrappers/rust/Cargo.toml"
    if [ -f "$rust_cargo" ]; then
        sed -i.bak "s/^version = \"[^\"]*\"/version = \"$new_version\"/" "$rust_cargo" && rm -f "$rust_cargo.bak" 2>/dev/null || true
    fi
    
    # Update Ruby wrapper
    local ruby_gemspec="$SCRIPT_DIR/wrappers/ruby/yourapi.gemspec"
    if [ -f "$ruby_gemspec" ]; then
        sed -i.bak "s/\.version[[:space:]]*=[[:space:]]*[^[:space:]]*/\.version       = '$new_version'/" "$ruby_gemspec" && rm -f "$ruby_gemspec.bak" 2>/dev/null || true
    fi
    
    # Update Java wrapper
    local java_pom="$SCRIPT_DIR/wrappers/java/pom.xml"
    if [ -f "$java_pom" ]; then
        sed -i.bak "s/<version>[^<]*<\/version>/<version>$new_version<\/version>/" "$java_pom" && rm -f "$java_pom.bak" 2>/dev/null || true
        # More specific for the main version tag
        sed -i.bak "0,/<version>[^<]*<\/version>/s/<version>[^<]*<\/version>/<version>$new_version<\/version>/" "$java_pom" && rm -f "$java_pom.bak" 2>/dev/null || true
    fi
    
    # Update Kotlin wrapper
    local kotlin_gradle="$SCRIPT_DIR/wrappers/kotlin/build.gradle.kts"
    if [ -f "$kotlin_gradle" ]; then
        sed -i.bak "s/^version = \"[^\"]*\"/version = \"$new_version\"/" "$kotlin_gradle" && rm -f "$kotlin_gradle.bak" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Version updated to $new_version in all config files and wrappers${NC}"
    echo ""
}

# Auto-increment version before generation (skip on first run/configuration)
if [ "$CONFIGURE_MODE" = false ]; then
    CURRENT_VERSION=$(get_current_version)
    NEW_VERSION=$(increment_version "$CURRENT_VERSION")
    update_all_versions "$NEW_VERSION"
fi

echo -e "${YELLOW}OpenAPI Spec:${NC} $OPENAPI_PATH"
echo -e "${YELLOW}Languages:${NC} $LANGUAGES_TO_GENERATE"
if [ "$CONFIGURE_MODE" = false ]; then
    echo -e "${YELLOW}Version:${NC} $NEW_VERSION"
fi
echo ""

# Check if OpenAPI spec exists
if [ ! -f "$OPENAPI_PATH" ]; then
    echo -e "${RED}Error: OpenAPI spec not found at $OPENAPI_PATH${NC}"
    exit 1
fi

# Validate file extension
EXTENSION="${OPENAPI_PATH##*.}"
EXTENSION_VALID=false
for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
    if [ "$EXTENSION" = "$ext" ]; then
        EXTENSION_VALID=true
        break
    fi
done

if [ "$EXTENSION_VALID" = false ]; then
    echo -e "${RED}Error: Unsupported file extension '.$EXTENSION'${NC}"
    echo -e "${YELLOW}Supported formats: .yaml, .yml, .json${NC}"
    exit 1
fi

echo -e "${GREEN}✓ OpenAPI spec format: .$EXTENSION${NC}"

# Check Java version (OpenAPI Generator requires Java 11+)
echo -e "${BLUE}Checking Java version...${NC}"

# Function to check Java version
check_java_version() {
    local java_cmd=$1
    local version_output=$($java_cmd -version 2>&1 | head -n 1)
    local version=$(echo "$version_output" | cut -d'"' -f2 | sed '/^1\./s///' | cut -d'.' -f1)
    
    if [ -z "$version" ]; then
        # Try alternative parsing for older Java versions
        version=$(echo "$version_output" | awk -F '"' '{print $2}' | awk -F '.' '{print $1}')
    fi
    
    echo "$version"
}

# Try to find a suitable Java version
JAVA_CMD="java"
JAVA_VERSION=""

# First, check if JAVA_HOME is set and use it
if [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JAVA_CMD="$JAVA_HOME/bin/java"
    JAVA_VERSION=$(check_java_version "$JAVA_CMD")
    if [ -n "$JAVA_VERSION" ] && [ "$JAVA_VERSION" -ge 11 ]; then
        echo -e "${GREEN}✓ Using Java $JAVA_VERSION from JAVA_HOME${NC}"
        export JAVA_HOME
    fi
fi

# If JAVA_HOME didn't work or wasn't set, try to find a newer Java
if [ -z "$JAVA_VERSION" ] || [ "$JAVA_VERSION" -lt 11 ]; then
    # Try Homebrew OpenJDK (common on macOS)
    if [ -x "/opt/homebrew/opt/openjdk/bin/java" ]; then
        JAVA_CMD="/opt/homebrew/opt/openjdk/bin/java"
        JAVA_VERSION=$(check_java_version "$JAVA_CMD")
        if [ -n "$JAVA_VERSION" ] && [ "$JAVA_VERSION" -ge 11 ]; then
            export JAVA_HOME="/opt/homebrew/opt/openjdk"
            echo -e "${GREEN}✓ Using Java $JAVA_VERSION from Homebrew${NC}"
        fi
    fi
fi

# If still no suitable Java, try java_home utility (macOS)
if [ -z "$JAVA_VERSION" ] || [ "$JAVA_VERSION" -lt 11 ]; then
    if command -v /usr/libexec/java_home &> /dev/null; then
        # Try to find Java 11 or higher
        for version in 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11; do
            JAVA_HOME_CANDIDATE=$(/usr/libexec/java_home -v "$version" 2>/dev/null)
            if [ -n "$JAVA_HOME_CANDIDATE" ] && [ -x "$JAVA_HOME_CANDIDATE/bin/java" ]; then
                JAVA_CMD="$JAVA_HOME_CANDIDATE/bin/java"
                JAVA_VERSION=$(check_java_version "$JAVA_CMD")
                if [ -n "$JAVA_VERSION" ] && [ "$JAVA_VERSION" -ge 11 ]; then
                    export JAVA_HOME="$JAVA_HOME_CANDIDATE"
                    echo -e "${GREEN}✓ Using Java $JAVA_VERSION from java_home${NC}"
                    break
                fi
            fi
        done
    fi
fi

# Final check - use system java if nothing else found
if [ -z "$JAVA_VERSION" ] || [ "$JAVA_VERSION" -lt 11 ]; then
    if command -v java &> /dev/null; then
        JAVA_CMD="java"
        JAVA_VERSION=$(check_java_version "$JAVA_CMD")
    fi
fi

# Validate Java version
if [ -z "$JAVA_VERSION" ] || [ "$JAVA_VERSION" -lt 11 ]; then
    echo -e "${RED}✗ Java version $JAVA_VERSION is too old${NC}"
    echo -e "${YELLOW}OpenAPI Generator CLI requires Java 11 or higher${NC}"
    if [ -n "$JAVA_VERSION" ]; then
        echo -e "${YELLOW}Current version: $($JAVA_CMD -version 2>&1 | head -n 1)${NC}"
    fi
    echo ""
    echo -e "${YELLOW}To install Java 11+:${NC}"
    echo -e "  macOS: brew install openjdk@11"
    echo -e "  Or: brew install openjdk (installs latest LTS)"
    echo -e "  Then set JAVA_HOME: export JAVA_HOME=\$(/usr/libexec/java_home -v 11)"
    echo -e "  Or download from: https://adoptium.net/"
    exit 1
fi

echo -e "${GREEN}✓ Java version $JAVA_VERSION detected${NC}"

# Check if OpenAPI Generator CLI is available via npm
echo -e "${BLUE}Checking OpenAPI Generator CLI...${NC}"

# Check if node_modules exists (dependencies installed)
if [ ! -d "$SCRIPT_DIR/node_modules/@openapitools/openapi-generator-cli" ]; then
    echo -e "${YELLOW}⚠ OpenAPI Generator CLI not found in node_modules${NC}"
    echo -e "${BLUE}Installing dependencies...${NC}"
    echo ""
    
    cd "$SCRIPT_DIR"
    npm install
    cd "$BASE_DIR"
    
    echo ""
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ OpenAPI Generator CLI ready${NC}"
fi

# Function to run openapi-generator-cli
# This ensures we're in the correct directory with node_modules
run_openapi_generator() {
    (cd "$SCRIPT_DIR" && npx @openapitools/openapi-generator-cli "$@")
}

echo ""

# Function to generate SDK for a language
generate_sdk() {
    local lang=$1
    local generator=""
    local config_file=""
    local output_dir=""
    
    case $lang in
        typescript)
            generator="typescript-axios"
            config_file="$SCRIPT_DIR/configs/typescript.json"
            output_dir="$SCRIPT_DIR/generated/typescript"
            ;;
        python)
            generator="python"
            config_file="$SCRIPT_DIR/configs/python.json"
            output_dir="$SCRIPT_DIR/generated/python"
            ;;
        go)
            generator="go"
            config_file="$SCRIPT_DIR/configs/go.json"
            output_dir="$SCRIPT_DIR/generated/go"
            ;;
        php)
            generator="php"
            config_file="$SCRIPT_DIR/configs/php.json"
            output_dir="$SCRIPT_DIR/generated/php"
            ;;
        rust)
            generator="rust"
            config_file="$SCRIPT_DIR/configs/rust.json"
            output_dir="$SCRIPT_DIR/generated/rust"
            ;;
        ruby)
            generator="ruby"
            config_file="$SCRIPT_DIR/configs/ruby.json"
            output_dir="$SCRIPT_DIR/generated/ruby"
            ;;
        java)
            generator="java"
            config_file="$SCRIPT_DIR/configs/java.json"
            output_dir="$SCRIPT_DIR/generated/java"
            ;;
        kotlin)
            generator="kotlin"
            config_file="$SCRIPT_DIR/configs/kotlin.json"
            output_dir="$SCRIPT_DIR/generated/kotlin"
            ;;
        *)
            echo -e "${RED}Error: Unknown language '$lang'${NC}"
            return 1
            ;;
    esac
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Generating $(echo $lang | tr '[:lower:]' '[:upper:]') SDK...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"
    
    # Generate SDK
    if run_openapi_generator generate \
        -i "$OPENAPI_PATH" \
        -g "$generator" \
        -o "$output_dir" \
        -c "$config_file" \
        --skip-validate-spec; then
        
        echo -e "${GREEN}✓ $(echo $lang | tr '[:lower:]' '[:upper:]') SDK generated successfully${NC}"
        
        # Copy wrapper code
        if [ -d "$SCRIPT_DIR/wrappers/$lang" ]; then
            echo -e "${YELLOW}  Copying wrapper code...${NC}"
            cp -r "$SCRIPT_DIR/wrappers/$lang"/* "$output_dir/" 2>/dev/null || true
            echo -e "${GREEN}  ✓ Wrapper code copied${NC}"
        fi
        
        echo ""
        return 0
    else
        echo -e "${RED}✗ $(echo $lang | tr '[:lower:]' '[:upper:]') SDK generation failed${NC}"
        echo ""
        return 1
    fi
}

# Generate SDKs
echo -e "${BLUE}Starting SDK generation...${NC}"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_LANGUAGES=""

for lang in $LANGUAGES_TO_GENERATE; do
    if generate_sdk "$lang"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
        FAILED_LANGUAGES="$FAILED_LANGUAGES $lang"
    fi
done

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Generation Summary              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Successful: $SUCCESS_COUNT${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo -e "${RED}Failed languages:$FAILED_LANGUAGES${NC}"
fi
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}🎉 All SDKs generated successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review generated code in sdk/generated/"
    echo "  2. Test the SDKs with your API"
    echo "  3. Publish to package registries"
    exit 0
else
    echo -e "${RED}⚠️  Some SDKs failed to generate${NC}"
    exit 1
fi

