# YourAPI Rust SDK

Production-ready Rust SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Async/await support with tokio
- ✅ Type safety with serde
- ✅ Debug logging

## Installation

Add this to your `Cargo.toml`:

```toml
[dependencies]
yourapi = "0.1.0"
tokio = { version = "1.0", features = ["full"] }
```

## Quick Start

```rust
use yourapi::{Client, ClientOptions};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize with API key
    let client = Client::new(
        ClientOptions::new("https://api.yourorg.com/v1")
            .with_api_key("your-api-key")
    )?;

    // Make a simple request
    let customer = client.get("/customers/123").await?;
    println!("{:?}", customer);

    Ok(())
}
```

## Configuration Options

```rust
use yourapi::{Client, ClientOptions};

let client = Client::new(
    ClientOptions::new("https://api.yourorg.com/v1")  // Required: API base URL
        .with_api_key("your-api-key")                  // Optional: API key auth
        .with_bearer_token("your-token")               // Optional: Bearer token auth
        .with_timeout(15)                              // Optional: Timeout in seconds (default: 15)
        .with_max_retries(3)                           // Optional: Max retries (default: 3)
        .with_debug(true)                              // Optional: Enable debug logging
)?;
```

## Pagination

### Cursor-based pagination

```rust
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct Customer {
    id: String,
    email: String,
    name: String,
}

// Fetch all customers
let customers: Vec<Customer> = client.paginate_cursor("/customers").await?;

for customer in customers {
    println!("{}: {}", customer.name, customer.email);
}
```

## Error Handling

```rust
use yourapi::APIError;

match client.get("/customers/123").await {
    Ok(Some(data)) => println!("Success: {:?}", data),
    Ok(None) => println!("No content"),
    Err(e) => {
        if let Some(status) = e.status {
            eprintln!("Status: {}", status);
        }
        if let Some(code) = e.code {
            eprintln!("Code: {}", code);
        }
        eprintln!("Message: {}", e.message);
        if let Some(request_id) = e.request_id {
            eprintln!("Request ID: {}", request_id);
        }
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

```rust
use serde_json::json;

// GET
let data = client.get("/customers/123").await?;

// POST
let new_customer = json!({
    "email": "user@example.com",
    "name": "John Doe"
});
let created = client.post("/customers", new_customer, None).await?;

// POST with idempotency key
let created = client.post(
    "/customers",
    new_customer,
    Some("idem-key-123".to_string())
).await?;

// PATCH
let update = json!({"name": "New Name"});
let updated = client.patch("/customers/123", update).await?;

// PUT
let full_customer = json!({
    "email": "user@example.com",
    "name": "John Doe"
});
let replaced = client.put("/customers/123", full_customer).await?;

// DELETE
client.delete("/customers/123").await?;
```

## Typed Responses

Define structs with serde for type-safe responses:

```rust
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Deserialize, Serialize)]
struct Customer {
    id: String,
    email: String,
    name: String,
    #[serde(rename = "createdAt")]
    created_at: DateTime<Utc>,
}

// Parse response as Customer
if let Some(data) = client.get("/customers/123").await? {
    let customer: Customer = serde_json::from_value(data)?;
    println!("Customer: {} ({})", customer.name, customer.email);
}
```

## Environment-specific Configuration

```rust
use std::env;

fn get_base_url() -> String {
    match env::var("ENVIRONMENT").as_deref() {
        Ok("production") => "https://api.yourorg.com/v1".to_string(),
        Ok("staging") => "https://staging-api.yourorg.com/v1".to_string(),
        _ => "https://sandbox-api.yourorg.com/v1".to_string(),
    }
}

let client = Client::new(
    ClientOptions::new(get_base_url())
        .with_api_key(&env::var("API_KEY")?)
)?;
```

## Async Runtime

This SDK requires the tokio runtime. Make sure to include it in your dependencies:

```toml
[dependencies]
tokio = { version = "1.0", features = ["full"] }
```

Or use the `#[tokio::main]` attribute on your main function:

```rust
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Your async code here
    Ok(())
}
```

## Requirements

- Rust 1.70 or higher
- tokio runtime for async support

## License

MIT

