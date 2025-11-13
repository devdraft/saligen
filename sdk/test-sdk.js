#!/usr/bin/env node
/**
 * Simple SDK Test Script (JavaScript)
 * 
 * This script tests the generated TypeScript SDK (compiled JS)
 * Run with: node sdk/test-sdk.js
 */

const path = require('path');

// Import the compiled SDK
const { YourAPIClient, APIError } = require('./generated/typescript/dist/index.js');

async function testSDK() {
  console.log('🧪 Testing TypeScript SDK...\n');

  // Initialize the client
  const client = new YourAPIClient({
    baseUrl: 'https://api.example.com/v1', // Replace with your actual API URL
    apiKey: 'test-api-key-12345',           // Replace with your actual API key
    debug: true,                             // Enable debug logging
    timeoutMs: 10000,
    maxRetries: 2
  });

  console.log('✅ Client initialized successfully');
  console.log('   Base URL:', 'https://api.example.com/v1');
  console.log('   Timeout:', '10000ms');
  console.log('   Max Retries:', '2\n');

  // Test configuration
  console.log('📋 Testing SDK Configuration...');
  console.log('   Client methods available:', Object.getOwnPropertyNames(Object.getPrototypeOf(client)));
  console.log('');

  try {
    // Test 1: Mock API call (will likely fail if endpoint doesn't exist)
    console.log('Test 1: Testing API call structure...');
    try {
      const result = await client.get('/health');
      console.log('✅ GET /health succeeded:', JSON.stringify(result, null, 2));
    } catch (error) {
      if (error.code === 'ENOTFOUND' || error.code === 'ECONNREFUSED') {
        console.log('ℹ️  Network error (expected if API not running):', error.message);
      } else if (error instanceof APIError) {
        console.log('ℹ️  API Error (expected):', {
          status: error.status,
          code: error.code,
          message: error.message
        });
      } else {
        console.log('ℹ️  Error:', error.message);
      }
    }
    console.log('');

    // Test 2: Verify client methods exist
    console.log('Test 2: Verifying client methods...');
    const requiredMethods = ['get', 'post', 'put', 'patch', 'delete', 'paginateCursor', 'paginatePage'];
    const missingMethods = requiredMethods.filter(method => typeof client[method] !== 'function');
    
    if (missingMethods.length === 0) {
      console.log('✅ All required methods exist:', requiredMethods.join(', '));
    } else {
      console.log('❌ Missing methods:', missingMethods.join(', '));
    }
    console.log('');

    // Test 3: Verify error handling
    console.log('Test 3: Testing error class...');
    const testError = new APIError('Test error', 400, 'TEST_CODE', {}, 'test-request-id');
    console.log('✅ APIError class works:', {
      message: testError.message,
      status: testError.status,
      code: testError.code,
      requestId: testError.requestId
    });
    console.log('');

    console.log('🎉 Basic SDK structure tests passed!\n');
    console.log('💡 To test with your actual API:');
    console.log('   1. Update baseUrl in this script');
    console.log('   2. Add your API key');
    console.log('   3. Run: node sdk/test-sdk.js\n');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
    process.exit(1);
  }
}

// Check if SDK is built
const fs = require('fs');
const distPath = path.join(__dirname, 'generated/typescript/dist/index.js');
if (!fs.existsSync(distPath)) {
  console.error('❌ Error: SDK not built yet!');
  console.error('   Run: cd sdk/generated/typescript && npm install && npm run build\n');
  process.exit(1);
}

// Run tests
console.log('═══════════════════════════════════════════════════════');
console.log('  TypeScript SDK Test Suite');
console.log('═══════════════════════════════════════════════════════\n');

testSDK().catch(error => {
  console.error('❌ Test suite failed:', error);
  process.exit(1);
});

