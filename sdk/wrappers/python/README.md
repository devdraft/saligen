# YourAPI Python SDK

Production-ready Python SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor and page-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Type hints
- ✅ Debug logging

## Installation

```bash
pip install yourapi-sdk
```

## Quick Start

```python
from yourapi import YourAPIClient

# Initialize with API key
client = YourAPIClient({
    'base_url': 'https://api.yourorg.com/v1',
    'api_key': 'your-api-key'
})

# Make a simple request
customer = client.get('/customers/123')

# Make a POST request with idempotency
new_customer = client.post(
    '/customers',
    data={
        'email': 'user@example.com',
        'name': 'John Doe'
    },
    idempotency_key='idempotency-key-123'
)
```

## Configuration Options

```python
from yourapi import YourAPIClient, SDKOptions

# Using SDKOptions dataclass
options = SDKOptions(
    base_url='https://api.yourorg.com/v1',  # Required
    api_key='your-api-key',                  # Optional: API key auth
    bearer_token='your-token',               # Optional: Bearer token auth
    timeout_seconds=15,                      # Optional: Request timeout (default: 15)
    max_retries=3,                           # Optional: Max retry attempts (default: 3)
    user_agent='my-app/1.0',                 # Optional: Custom user agent
    custom_headers={                         # Optional: Additional headers
        'X-App-Version': '1.0.0'
    },
    debug=True                               # Optional: Enable debug logging
)
client = YourAPIClient(options)

# Or using dictionary
client = YourAPIClient({
    'base_url': 'https://api.yourorg.com/v1',
    'api_key': 'your-api-key',
    'debug': True
})
```

## Pagination

### Cursor-based pagination (generator)

```python
# Iterate through all customers
for customer in client.paginate_cursor('/customers'):
    print(customer['email'])

# With filters
for order in client.paginate_cursor('/orders', params={'status': 'pending'}):
    print(order['id'])

# Or fetch all at once
all_customers = client.get_all_cursor('/customers')
```

### Page-based pagination

```python
# Iterate through all products
for product in client.paginate_page('/products'):
    print(product['name'])

# With filters and page size
for product in client.paginate_page('/products', params={
    'category': 'electronics',
    'perPage': 50
}):
    print(product['name'])

# Or fetch all at once
all_products = client.get_all_page('/products')
```

## Error Handling

```python
from yourapi import APIError

try:
    customer = client.get('/customers/123')
except APIError as error:
    print(f"Status: {error.status}")
    print(f"Code: {error.code}")
    print(f"Message: {error.message}")
    print(f"Details: {error.details}")
    print(f"Request ID: {error.request_id}")
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

```python
# GET
data = client.get('/customers/123')

# POST
created = client.post('/customers', data={'email': 'user@example.com', 'name': 'John Doe'})

# POST with idempotency key
safe = client.post('/customers', data=customer_data, idempotency_key='idem-key-123')

# PATCH
updated = client.patch('/customers/123', data={'name': 'New Name'})

# PUT
replaced = client.put('/customers/123', data=full_customer_data)

# DELETE
client.delete('/customers/123')
```

## Environment-specific Configuration

```python
import os
from yourapi import YourAPIClient

environment = os.getenv('ENVIRONMENT', 'development')

base_urls = {
    'production': 'https://api.yourorg.com/v1',
    'staging': 'https://staging-api.yourorg.com/v1',
    'development': 'https://sandbox-api.yourorg.com/v1'
}

client = YourAPIClient({
    'base_url': base_urls.get(environment, base_urls['development']),
    'api_key': os.getenv('API_KEY')
})
```

## Type Hints

The SDK includes type hints for better IDE support:

```python
from typing import Dict, Any, List
from yourapi import YourAPIClient

client = YourAPIClient({'base_url': 'https://api.example.com'})

# Type hints work with responses
customer: Dict[str, Any] = client.get('/customers/123')
customers: List[Dict[str, Any]] = client.get_all_cursor('/customers')
```

## Debug Logging

Enable debug logging to see detailed request/response information:

```python
client = YourAPIClient({
    'base_url': 'https://api.yourorg.com/v1',
    'api_key': 'your-api-key',
    'debug': True
})

# This will print:
# [2025-11-12T10:30:00] [YourAPI] GET https://api.yourorg.com/v1/customers/123 (attempt 1/4)
# [2025-11-12T10:30:01] [YourAPI] Response: 200
```

## Requirements

- Python 3.8 or higher
- urllib3 >= 2.0.0

## License

MIT

