#!/usr/bin/env node

/**
 * Saligen CLI
 * 
 * This is the entry point when installed via npm
 * Usage: saligen [options]
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Get the directory where this package is installed
const packageDir = path.resolve(__dirname, '..');
const generateScript = path.join(packageDir, 'sdk', 'generate.sh');

// Check if generate.sh exists
if (!fs.existsSync(generateScript)) {
  console.error('❌ Error: generate.sh not found at', generateScript);
  process.exit(1);
}

// Make sure it's executable
try {
  fs.chmodSync(generateScript, '755');
} catch (err) {
  // Ignore chmod errors (might not have permissions, but script might still work)
}

// Get all command line arguments (skip node and script name)
const args = process.argv.slice(2);

// Spawn the bash script
const child = spawn('bash', [generateScript, ...args], {
  stdio: 'inherit',
  cwd: packageDir,
  env: {
    ...process.env,
    // Ensure we're in the right directory
    SDKGEN_PACKAGE_DIR: packageDir
  }
});

child.on('error', (error) => {
  console.error('❌ Error running SDK generator:', error.message);
  if (error.code === 'ENOENT') {
    console.error('   Make sure bash is installed and available in your PATH');
  }
  process.exit(1);
});

child.on('exit', (code) => {
  process.exit(code || 0);
});

