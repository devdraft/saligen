# DevDraft TypeScript SDK

Production-ready TypeScript SDK for DevDraft API with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor and page-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Type safety with TypeScript
- ✅ Debug logging

## Installation

```bash
npm install @devdraft/devdraft-sdk
# or
yarn add @devdraft/devdraft-sdk
```

## Quick Start

```typescript
import { DevDraftClient } from '@devdraft/devdraft-sdk';

// Initialize with API key
const client = new DevDraftClient({
  baseUrl: 'https://api.devdraft.ai/v1',
  apiKey: 'your-api-key'
});

// Make a simple request
const customer = await client.get('/customers/123');

// Make a POST request with idempotency
const newCustomer = await client.post(
  '/customers',
  {
    email: 'user@example.com',
    name: 'John Doe'
  },
  'idempotency-key-123'
);
```

## Configuration Options

```typescript
const client = new DevDraftClient({
  baseUrl: 'https://api.devdraft.ai/v1',  // Required: API base URL
  apiKey: 'your-api-key',                  // Optional: API key auth
  bearerToken: 'your-token',               // Optional: Bearer token auth
  timeoutMs: 15000,                        // Optional: Request timeout (default: 15000)
  maxRetries: 3,                           // Optional: Max retry attempts (default: 3)
  userAgent: 'my-app/1.0',                 // Optional: Custom user agent
  customHeaders: {                         // Optional: Additional headers
    'X-App-Version': '1.0.0'
  },
  debug: true                              // Optional: Enable debug logging
});
```

## Pagination

### Cursor-based pagination (async iterator)

```typescript
// Iterate through all customers
for await (const customer of client.paginateCursor('/customers')) {
  console.log(customer.email);
}

// With filters
for await (const order of client.paginateCursor('/orders', { status: 'pending' })) {
  console.log(order.id);
}

// Or fetch all at once
const allCustomers = await client.getAllCursor('/customers');
```

### Page-based pagination

```typescript
// Iterate through all products
for await (const product of client.paginatePage('/products')) {
  console.log(product.name);
}

// With filters and page size
for await (const product of client.paginatePage('/products', { 
  category: 'electronics',
  perPage: 50 
})) {
  console.log(product.name);
}

// Or fetch all at once
const allProducts = await client.getAllPage('/products');
```

## Error Handling

```typescript
import { APIError } from '@devdraft/devdraft-sdk';

try {
  const customer = await client.get('/customers/123');
} catch (error) {
  if (error instanceof APIError) {
    console.error('Status:', error.status);
    console.error('Code:', error.code);
    console.error('Message:', error.message);
    console.error('Details:', error.details);
    console.error('Request ID:', error.requestId);
  }
}
```

## Retries

The SDK automatically retries failed requests for the following status codes:
- `429` (Too Many Requests)
- `500` (Internal Server Error)
- `502` (Bad Gateway)
- `503` (Service Unavailable)
- `504` (Gateway Timeout)

Retries use exponential backoff with a maximum wait time of 8 seconds. If the server returns a `Retry-After` header, it will be respected.

## HTTP Methods

```typescript
// GET
const data = await client.get<Customer>('/customers/123');

// POST
const created = await client.post<Customer>('/customers', customerData);

// POST with idempotency key
const safe = await client.post<Customer>('/customers', customerData, 'idem-key-123');

// PATCH
const updated = await client.patch<Customer>('/customers/123', { name: 'New Name' });

// PUT
const replaced = await client.put<Customer>('/customers/123', fullCustomerData);

// DELETE
await client.delete('/customers/123');
```

## Advanced Usage

### Access Axios instance directly

```typescript
const axiosInstance = client.getAxiosInstance();

// Add custom interceptors
axiosInstance.interceptors.request.use((config) => {
  // Custom logic
  return config;
});
```

## Environment-specific Configuration

```typescript
const environment = process.env.NODE_ENV;

const baseUrl = {
  production: 'https://api.devdraft.ai/v1',
  staging: 'https://staging-api.devdraft.ai/v1',
  development: 'https://sandbox-api.devdraft.ai/v1'
}[environment] || 'https://sandbox-api.devdraft.ai/v1';

const client = new DevDraftClient({ baseUrl, apiKey: process.env.API_KEY });
```

## License

MIT

