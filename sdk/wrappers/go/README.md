# YourAPI Go SDK

Production-ready Go SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Context support
- ✅ Debug logging
- ✅ Zero external dependencies (uses only standard library)

## Installation

```bash
go get github.com/yourorg/yourapi-go
```

## Quick Start

```go
package main

import (
    "context"
    "fmt"
    "log"
    
    yourapi "github.com/yourorg/yourapi-go"
)

func main() {
    // Initialize with API key
    client, err := yourapi.NewClient(yourapi.ClientOptions{
        BaseURL: "https://api.yourorg.com/v1",
        APIKey:  "your-api-key",
    })
    if err != nil {
        log.Fatal(err)
    }
    
    // Make a simple request
    var customer map[string]interface{}
    err = client.Get(context.Background(), "/customers/123", &customer)
    if err != nil {
        log.Fatal(err)
    }
    
    fmt.Printf("Customer: %+v\n", customer)
}
```

## Configuration Options

```go
client, err := yourapi.NewClient(yourapi.ClientOptions{
    BaseURL:      "https://api.yourorg.com/v1", // Required: API base URL
    APIKey:       "your-api-key",                // Optional: API key auth
    BearerToken:  "your-token",                  // Optional: Bearer token auth
    Timeout:      15 * time.Second,              // Optional: Request timeout (default: 15s)
    MaxRetries:   3,                             // Optional: Max retry attempts (default: 3)
    UserAgent:    "my-app/1.0",                  // Optional: Custom user agent
    CustomHeaders: map[string]string{            // Optional: Additional headers
        "X-App-Version": "1.0.0",
    },
    Debug: true,                                 // Optional: Enable debug logging
})
if err != nil {
    log.Fatal(err)
}
```

## Pagination

### Cursor-based pagination (callback)

```go
// Iterate through all customers
err := client.PaginateCursor(ctx, "/customers", func(item interface{}) error {
    customer := item.(map[string]interface{})
    fmt.Println(customer["email"])
    return nil
})
if err != nil {
    log.Fatal(err)
}

// Or fetch all at once
items, err := client.GetAllCursor(ctx, "/customers")
if err != nil {
    log.Fatal(err)
}
```

## Error Handling

```go
var customer map[string]interface{}
err := client.Get(ctx, "/customers/123", &customer)
if err != nil {
    if apiErr, ok := err.(*yourapi.APIError); ok {
        fmt.Printf("Status: %d\n", apiErr.Status)
        fmt.Printf("Code: %s\n", apiErr.Code)
        fmt.Printf("Message: %s\n", apiErr.Message)
        fmt.Printf("Details: %+v\n", apiErr.Details)
        fmt.Printf("Request ID: %s\n", apiErr.RequestID)
    } else {
        log.Fatal(err)
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

```go
ctx := context.Background()

// GET
var customer map[string]interface{}
err := client.Get(ctx, "/customers/123", &customer)

// POST
newCustomer := map[string]interface{}{
    "email": "user@example.com",
    "name":  "John Doe",
}
var created map[string]interface{}
err := client.Post(ctx, "/customers", newCustomer, &created, "")

// POST with idempotency key
err := client.Post(ctx, "/customers", newCustomer, &created, "idem-key-123")

// PATCH
update := map[string]interface{}{"name": "New Name"}
var updated map[string]interface{}
err := client.Patch(ctx, "/customers/123", update, &updated)

// PUT
fullCustomer := map[string]interface{}{
    "email": "user@example.com",
    "name":  "John Doe",
}
var replaced map[string]interface{}
err := client.Put(ctx, "/customers/123", fullCustomer, &replaced)

// DELETE
err := client.Delete(ctx, "/customers/123")
```

## Context Support

All methods accept a `context.Context` for cancellation and timeout control:

```go
// With timeout
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

var customer map[string]interface{}
err := client.Get(ctx, "/customers/123", &customer)

// With cancellation
ctx, cancel := context.WithCancel(context.Background())
go func() {
    time.Sleep(2 * time.Second)
    cancel()
}()

err := client.Get(ctx, "/customers/123", &customer)
```

## Typed Responses

Define structs for type-safe responses:

```go
type Customer struct {
    ID        string    `json:"id"`
    Email     string    `json:"email"`
    Name      string    `json:"name"`
    CreatedAt time.Time `json:"createdAt"`
}

var customer Customer
err := client.Get(ctx, "/customers/123", &customer)
if err != nil {
    log.Fatal(err)
}

fmt.Printf("Customer: %s (%s)\n", customer.Name, customer.Email)
```

## Environment-specific Configuration

```go
import "os"

func getBaseURL() string {
    env := os.Getenv("ENVIRONMENT")
    switch env {
    case "production":
        return "https://api.yourorg.com/v1"
    case "staging":
        return "https://staging-api.yourorg.com/v1"
    default:
        return "https://sandbox-api.yourorg.com/v1"
    }
}

client, err := yourapi.NewClient(yourapi.ClientOptions{
    BaseURL: getBaseURL(),
    APIKey:  os.Getenv("API_KEY"),
})
```

## Custom HTTP Client

You can provide your own `http.Client` for advanced configuration:

```go
import (
    "net/http"
    "time"
)

customHTTPClient := &http.Client{
    Timeout: 30 * time.Second,
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 10,
        IdleConnTimeout:     90 * time.Second,
    },
}

client, err := yourapi.NewClient(yourapi.ClientOptions{
    BaseURL:    "https://api.yourorg.com/v1",
    APIKey:     "your-api-key",
    HTTPClient: customHTTPClient,
})
```

## Requirements

- Go 1.21 or higher
- No external dependencies (uses only standard library)

## License

MIT

