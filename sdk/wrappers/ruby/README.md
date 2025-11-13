# YourAPI Ruby SDK

Production-ready Ruby SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor and page-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Debug logging
- ✅ Zero external dependencies (uses only standard library)

## Requirements

- Ruby 2.7 or higher

## Installation

Add this line to your Gemfile:

```ruby
gem 'yourapi'
```

And then execute:

```bash
bundle install
```

Or install it directly:

```bash
gem install yourapi
```

## Quick Start

```ruby
require 'yourapi'

# Initialize with API key
client = YourAPI::Client.new(
  base_url: 'https://api.yourorg.com/v1',
  api_key: 'your-api-key'
)

# Make a simple request
customer = client.get('/customers/123')
puts customer['name']

# Make a POST request with idempotency
new_customer = client.post(
  '/customers',
  data: {
    email: 'user@example.com',
    name: 'John Doe'
  },
  idempotency_key: 'idempotency-key-123'
)
```

## Configuration Options

```ruby
client = YourAPI::Client.new(
  base_url: 'https://api.yourorg.com/v1',    # Required: API base URL
  api_key: 'your-api-key',                    # Optional: API key auth
  bearer_token: 'your-token',                 # Optional: Bearer token auth
  timeout: 15,                                # Optional: Timeout in seconds (default: 15)
  max_retries: 3,                             # Optional: Max retries (default: 3)
  user_agent: 'my-app/1.0',                   # Optional: Custom user agent
  custom_headers: {                           # Optional: Additional headers
    'X-App-Version' => '1.0.0'
  },
  debug: true                                 # Optional: Enable debug logging
)
```

## Pagination

### Cursor-based pagination (enumerator)

```ruby
# Iterate through all customers
client.paginate_cursor('/customers').each do |customer|
  puts customer['email']
end

# With filters
client.paginate_cursor('/orders', params: { status: 'pending' }).each do |order|
  puts order['id']
end

# Or fetch all at once
all_customers = client.get_all_cursor('/customers')
```

### Page-based pagination

```ruby
# Iterate through all products
client.paginate_page('/products').each do |product|
  puts product['name']
end

# With filters and page size
client.paginate_page('/products', params: { category: 'electronics', perPage: 50 }).each do |product|
  puts product['name']
end

# Or fetch all at once
all_products = client.get_all_page('/products')
```

## Error Handling

```ruby
begin
  customer = client.get('/customers/123')
  puts customer['name']
rescue YourAPI::APIError => e
  puts "Status: #{e.status}"
  puts "Code: #{e.code}"
  puts "Message: #{e.message}"
  puts "Details: #{e.details}"
  puts "Request ID: #{e.request_id}"
end
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

```ruby
# GET
data = client.get('/customers/123')

# GET with query parameters
data = client.get('/customers', params: { email: 'user@example.com' })

# POST
created = client.post('/customers', data: { email: 'user@example.com', name: 'John Doe' })

# POST with idempotency key
safe = client.post('/customers', data: customer_data, idempotency_key: 'idem-key-123')

# PATCH
updated = client.patch('/customers/123', data: { name: 'New Name' })

# PUT
replaced = client.put('/customers/123', data: full_customer_data)

# DELETE
client.delete('/customers/123')
```

## Environment-specific Configuration

```ruby
environment = ENV['ENVIRONMENT'] || 'development'

base_urls = {
  'production' => 'https://api.yourorg.com/v1',
  'staging' => 'https://staging-api.yourorg.com/v1',
  'development' => 'https://sandbox-api.yourorg.com/v1'
}

client = YourAPI::Client.new(
  base_url: base_urls[environment],
  api_key: ENV['API_KEY']
)
```

## Debug Logging

Enable debug logging to see detailed request/response information:

```ruby
client = YourAPI::Client.new(
  base_url: 'https://api.yourorg.com/v1',
  api_key: 'your-api-key',
  debug: true
)

# This will print:
# [2025-11-12T10:30:00Z] [YourAPI] GET https://api.yourorg.com/v1/customers/123 (attempt 1/4)
# [2025-11-12T10:30:01Z] [YourAPI] Response: 200
```

## Thread Safety

Each `Client` instance is thread-safe and can be shared across threads. However, for optimal performance in multi-threaded applications, consider creating a client pool or using a separate client instance per thread.

## License

MIT

