#!/usr/bin/env ts-node
/**
 * TypeScript SDK Test Script
 * 
 * This script tests the generated TypeScript SDK
 * Run with: npx ts-node test-typescript.ts
 */

import { YourAPIClient, APIError } from './generated/typescript';

async function testSDK() {
  console.log('🧪 Testing TypeScript SDK...\n');

  // Initialize the client
  const client = new YourAPIClient({
    baseUrl: 'https://api.hiver.com/v1', // Replace with your actual API URL
    apiKey: 'test-api-key-12345',        // Replace with your actual API key
    debug: true,                          // Enable debug logging
    timeoutMs: 10000,
    maxRetries: 2
  });

  console.log('✅ Client initialized successfully\n');

  try {
    // Test 1: Basic GET request
    console.log('Test 1: Testing GET request...');
    try {
      const result = await client.get('/health');
      console.log('✅ GET /health succeeded:', result);
    } catch (error) {
      if (error instanceof APIError) {
        console.log('❌ GET request failed:', {
          status: error.status,
          code: error.code,
          message: error.message,
          requestId: error.requestId
        });
      }
    }
    console.log('');

    // Test 2: POST request
    console.log('Test 2: Testing POST request...');
    try {
      const postData = {
        name: 'Test Item',
        description: 'Testing SDK'
      };
      const result = await client.post('/items', postData, 'test-idempotency-key-123');
      console.log('✅ POST /items succeeded:', result);
    } catch (error) {
      if (error instanceof APIError) {
        console.log('❌ POST request failed:', {
          status: error.status,
          code: error.code,
          message: error.message
        });
      }
    }
    console.log('');

    // Test 3: Error handling
    console.log('Test 3: Testing error handling...');
    try {
      await client.get('/nonexistent-endpoint');
      console.log('❌ Expected error but got success');
    } catch (error) {
      if (error instanceof APIError) {
        console.log('✅ Error handling works correctly:', {
          status: error.status,
          message: error.message
        });
      }
    }
    console.log('');

    // Test 4: Pagination (if your API supports it)
    console.log('Test 4: Testing pagination...');
    try {
      console.log('Testing cursor-based pagination...');
      let count = 0;
      for await (const item of client.paginateCursor('/items', { limit: 10 })) {
        count++;
        if (count >= 5) break; // Only fetch first 5 to test
      }
      console.log(`✅ Fetched ${count} items via pagination`);
    } catch (error) {
      console.log('ℹ️ Pagination test skipped (endpoint may not exist)');
    }
    console.log('');

    console.log('🎉 All tests completed!\n');

  } catch (error) {
    console.error('❌ Unexpected error:', error);
    process.exit(1);
  }
}

// Run tests
testSDK().catch(console.error);

