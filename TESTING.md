# SDK Testing Guide

This guide explains how to test your generated SDKs, with a focus on the TypeScript SDK.

## 🧪 TypeScript SDK Testing

### Quick Start (Recommended)

**1. Generate the SDK:**
```bash
./sdk/generate.sh -o swagger.yml -l typescript
```

**2. Navigate to the generated SDK:**
```bash
cd sdk/generated/typescript
```

**3. Install dependencies:**
```bash
npm install
```

**4. Build the SDK:**
```bash
npm run build
```

**5. Run the test script:**
```bash
cd ../..  # Back to sdk directory
node test-sdk.js
```

---

## Testing Methods

### Method 1: Quick Test Script (Easiest)

Use the provided test script to verify the SDK structure and basic functionality:

```bash
# From the SDKgen root directory
node sdk/test-sdk.js
```

This script:
- ✅ Verifies the SDK is built correctly
- ✅ Checks all required methods exist
- ✅ Tests error handling
- ✅ Shows you how to customize it for your API

**Customize the test:**

Edit `sdk/test-sdk.js` and update:
```javascript
const client = new YourAPIClient({
  baseUrl: 'https://your-actual-api.com/v1',  // Your API URL
  apiKey: 'your-actual-api-key',              // Your API key
  debug: true
});
```

---

### Method 2: npm link (Local Development)

Use npm link to test the SDK in another project:

**1. Link the SDK globally:**
```bash
cd sdk/generated/typescript
npm link
```

**2. In your test project:**
```bash
cd /path/to/your-test-project
npm link <your-sdk-name>  # e.g., npm link hiver or @yourorg/yourapi
```

**3. Use it in your test project:**
```typescript
import { YourAPIClient } from '<your-sdk-name>';

const client = new YourAPIClient({
  baseUrl: 'https://api.example.com/v1',
  apiKey: process.env.API_KEY
});

async function test() {
  const result = await client.get('/some-endpoint');
  console.log(result);
}

test();
```

**4. Unlink when done:**
```bash
npm unlink <your-sdk-name>
```

---

### Method 3: Direct Import (Manual Testing)

Create a standalone test file:

**1. Create `test-manual.js` in your project root:**

```javascript
const { YourAPIClient } = require('./sdk/generated/typescript/dist/index.js');

async function test() {
  const client = new YourAPIClient({
    baseUrl: 'https://api.example.com/v1',
    apiKey: 'your-api-key',
    debug: true
  });

  try {
    // Test GET request
    const data = await client.get('/endpoint');
    console.log('✅ Success:', data);

    // Test POST request
    const created = await client.post('/items', {
      name: 'Test Item'
    });
    console.log('✅ Created:', created);

    // Test pagination
    for await (const item of client.paginateCursor('/items')) {
      console.log('Item:', item);
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

test();
```

**2. Run it:**
```bash
node test-manual.js
```

---

### Method 4: Add Jest Testing (Comprehensive)

For production-ready testing with a proper test framework:

**1. Install Jest:**
```bash
cd sdk/generated/typescript
npm install --save-dev jest @types/jest ts-jest
```

**2. Create `jest.config.js`:**
```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
  ],
};
```

**3. Create `tests/client.test.ts`:**
```typescript
import { YourAPIClient, APIError } from '../src';

describe('YourAPIClient', () => {
  let client: YourAPIClient;

  beforeEach(() => {
    client = new YourAPIClient({
      baseUrl: 'https://api.test.com',
      apiKey: 'test-key'
    });
  });

  test('should initialize correctly', () => {
    expect(client).toBeDefined();
  });

  test('should have all required methods', () => {
    expect(typeof client.get).toBe('function');
    expect(typeof client.post).toBe('function');
    expect(typeof client.put).toBe('function');
    expect(typeof client.patch).toBe('function');
    expect(typeof client.delete).toBe('function');
  });

  test('should handle errors correctly', () => {
    const error = new APIError('Test', 404, 'NOT_FOUND', {}, 'req-123');
    expect(error.status).toBe(404);
    expect(error.code).toBe('NOT_FOUND');
    expect(error.requestId).toBe('req-123');
  });
});
```

**4. Add test script to `package.json`:**
```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage"
  }
}
```

**5. Run tests:**
```bash
npm test
```

---

## Testing with Mock Server

For more realistic testing, use a mock API server:

**1. Install json-server:**
```bash
npm install -g json-server
```

**2. Create `mock-api.json`:**
```json
{
  "items": [
    { "id": 1, "name": "Item 1" },
    { "id": 2, "name": "Item 2" }
  ],
  "users": [
    { "id": 1, "email": "user1@example.com" }
  ]
}
```

**3. Start mock server:**
```bash
json-server --watch mock-api.json --port 3000
```

**4. Test against mock server:**
```javascript
const client = new YourAPIClient({
  baseUrl: 'http://localhost:3000',
  apiKey: 'test-key'
});

const items = await client.get('/items');
console.log(items); // Should return mock data
```

---

## Verifying SDK Features

### ✅ Authentication
```javascript
// API Key
const client1 = new YourAPIClient({
  baseUrl: 'https://api.example.com',
  apiKey: 'your-key'
});

// Bearer Token
const client2 = new YourAPIClient({
  baseUrl: 'https://api.example.com',
  bearerToken: 'your-token'
});
```

### ✅ Retries
```javascript
const client = new YourAPIClient({
  baseUrl: 'https://api.example.com',
  maxRetries: 3  // Will retry on 429, 500, 502, 503, 504
});
```

### ✅ Pagination
```javascript
// Cursor-based
for await (const item of client.paginateCursor('/items')) {
  console.log(item);
}

// Page-based
for await (const item of client.paginatePage('/products')) {
  console.log(item);
}

// Get all at once
const allItems = await client.getAllCursor('/items');
```

### ✅ Error Handling
```javascript
try {
  await client.get('/nonexistent');
} catch (error) {
  if (error instanceof APIError) {
    console.log('Status:', error.status);
    console.log('Code:', error.code);
    console.log('Message:', error.message);
    console.log('Request ID:', error.requestId);
  }
}
```

### ✅ Custom Headers
```javascript
const client = new YourAPIClient({
  baseUrl: 'https://api.example.com',
  apiKey: 'your-key',
  customHeaders: {
    'X-App-Version': '1.0.0',
    'X-Custom-Header': 'value'
  }
});
```

---

## Troubleshooting

### Error: Cannot find module

**Problem:** `Error: Cannot find module './generated/typescript/dist/index.js'`

**Solution:**
```bash
cd sdk/generated/typescript
npm install
npm run build
```

### Error: axios not found

**Problem:** `Error: Cannot find module 'axios'`

**Solution:**
```bash
cd sdk/generated/typescript
npm install axios
```

### TypeScript Errors

**Problem:** TypeScript compilation errors

**Solution:**
1. Check `tsconfig.json` settings
2. Ensure all dependencies are installed
3. Run `npm run build` with verbose output:
   ```bash
   npm run build -- --verbose
   ```

### Network Errors

**Problem:** `ECONNREFUSED` or `ENOTFOUND` errors

**Solution:**
- Verify your API URL is correct
- Check if your API server is running
- Test with a mock server (see above)
- Try with a public test API like `https://jsonplaceholder.typicode.com`

---

## Example: Full Integration Test

Here's a complete example testing all features:

```typescript
import { YourAPIClient, APIError } from './sdk/generated/typescript';

async function integrationTest() {
  const client = new YourAPIClient({
    baseUrl: 'https://api.example.com/v1',
    apiKey: process.env.API_KEY,
    timeoutMs: 15000,
    maxRetries: 3,
    debug: true
  });

  console.log('🧪 Running integration tests...\n');

  // Test 1: Health check
  try {
    const health = await client.get('/health');
    console.log('✅ Health check:', health);
  } catch (e) {
    console.log('❌ Health check failed');
  }

  // Test 2: CRUD operations
  try {
    // Create
    const created = await client.post('/items', {
      name: 'Test Item',
      price: 99.99
    }, 'idempotency-key-123');
    console.log('✅ Created:', created);

    // Read
    const item = await client.get(`/items/${created.id}`);
    console.log('✅ Retrieved:', item);

    // Update
    const updated = await client.patch(`/items/${created.id}`, {
      price: 79.99
    });
    console.log('✅ Updated:', updated);

    // Delete
    await client.delete(`/items/${created.id}`);
    console.log('✅ Deleted');
  } catch (e) {
    console.log('❌ CRUD test failed:', e.message);
  }

  // Test 3: Pagination
  try {
    let count = 0;
    for await (const item of client.paginateCursor('/items')) {
      count++;
      if (count >= 10) break;
    }
    console.log(`✅ Pagination: Retrieved ${count} items`);
  } catch (e) {
    console.log('❌ Pagination failed:', e.message);
  }

  // Test 4: Error handling
  try {
    await client.get('/nonexistent-endpoint');
  } catch (error) {
    if (error instanceof APIError) {
      console.log('✅ Error handling works:', {
        status: error.status,
        code: error.code
      });
    }
  }

  console.log('\n🎉 Integration tests completed!');
}

integrationTest().catch(console.error);
```

---

## Next Steps

1. **Run the basic test:** `node sdk/test-sdk.js`
2. **Customize for your API:** Update baseUrl and apiKey
3. **Add more tests:** Create test cases for your specific endpoints
4. **Set up CI/CD:** Add tests to your GitHub Actions workflow

For other languages (Python, Go, etc.), see their respective testing guides in `sdk/wrappers/<language>/README.md`.

