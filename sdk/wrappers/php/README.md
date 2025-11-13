# YourAPI PHP SDK

Production-ready PHP SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor and page-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Type hints
- ✅ PSR-4 autoloading
- ✅ Debug logging

## Requirements

- PHP 8.1 or higher
- cURL extension
- JSON extension

## Installation

```bash
composer require yourorg/yourapi-sdk
```

## Quick Start

```php
<?php

require_once 'vendor/autoload.php';

use YourOrg\YourAPI\Client;

// Initialize with API key
$client = new Client([
    'baseUrl' => 'https://api.yourorg.com/v1',
    'apiKey' => 'your-api-key'
]);

// Make a simple request
$customer = $client->get('/customers/123');

// Make a POST request with idempotency
$newCustomer = $client->post(
    '/customers',
    [
        'email' => 'user@example.com',
        'name' => 'John Doe'
    ],
    'idempotency-key-123'
);
```

## Configuration Options

```php
$client = new Client([
    'baseUrl' => 'https://api.yourorg.com/v1',  // Required: API base URL
    'apiKey' => 'your-api-key',                  // Optional: API key auth
    'bearerToken' => 'your-token',               // Optional: Bearer token auth
    'timeout' => 15,                             // Optional: Request timeout in seconds (default: 15)
    'maxRetries' => 3,                           // Optional: Max retry attempts (default: 3)
    'userAgent' => 'my-app/1.0',                 // Optional: Custom user agent
    'customHeaders' => [                         // Optional: Additional headers
        'X-App-Version' => '1.0.0'
    ],
    'debug' => true                              // Optional: Enable debug logging
]);
```

## Pagination

### Cursor-based pagination (generator)

```php
// Iterate through all customers
foreach ($client->paginateCursor('/customers') as $customer) {
    echo $customer['email'] . "\n";
}

// With filters
foreach ($client->paginateCursor('/orders', ['status' => 'pending']) as $order) {
    echo $order['id'] . "\n";
}

// Or fetch all at once
$allCustomers = $client->getAllCursor('/customers');
```

### Page-based pagination

```php
// Iterate through all products
foreach ($client->paginatePage('/products') as $product) {
    echo $product['name'] . "\n";
}

// With filters and page size
foreach ($client->paginatePage('/products', ['category' => 'electronics', 'perPage' => 50]) as $product) {
    echo $product['name'] . "\n";
}

// Or fetch all at once
$allProducts = $client->getAllPage('/products');
```

## Error Handling

```php
use YourOrg\YourAPI\APIError;

try {
    $customer = $client->get('/customers/123');
} catch (APIError $e) {
    echo "Status: " . $e->getStatus() . "\n";
    echo "Code: " . $e->getErrorCode() . "\n";
    echo "Message: " . $e->getMessage() . "\n";
    echo "Details: " . print_r($e->getDetails(), true) . "\n";
    echo "Request ID: " . $e->getRequestId() . "\n";
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

```php
// GET
$data = $client->get('/customers/123');

// GET with query parameters
$data = $client->get('/customers', ['email' => 'user@example.com']);

// POST
$created = $client->post('/customers', [
    'email' => 'user@example.com',
    'name' => 'John Doe'
]);

// POST with idempotency key
$safe = $client->post('/customers', $customerData, 'idem-key-123');

// PATCH
$updated = $client->patch('/customers/123', ['name' => 'New Name']);

// PUT
$replaced = $client->put('/customers/123', $fullCustomerData);

// DELETE
$client->delete('/customers/123');
```

## Environment-specific Configuration

```php
$environment = getenv('ENVIRONMENT') ?: 'development';

$baseUrls = [
    'production' => 'https://api.yourorg.com/v1',
    'staging' => 'https://staging-api.yourorg.com/v1',
    'development' => 'https://sandbox-api.yourorg.com/v1'
];

$client = new Client([
    'baseUrl' => $baseUrls[$environment] ?? $baseUrls['development'],
    'apiKey' => getenv('API_KEY')
]);
```

## Debug Logging

Enable debug logging to see detailed request/response information:

```php
$client = new Client([
    'baseUrl' => 'https://api.yourorg.com/v1',
    'apiKey' => 'your-api-key',
    'debug' => true
]);

// This will print:
// [2025-11-12T10:30:00+00:00] [YourAPI] GET https://api.yourorg.com/v1/customers/123 (attempt 1/4)
// [2025-11-12T10:30:01+00:00] [YourAPI] Response: 200
```

## License

MIT

