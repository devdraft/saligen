# YourAPI Java SDK

Production-ready Java SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Type safety with Gson
- ✅ Debug logging
- ✅ Builder pattern for configuration

## Requirements

- Java 11 or higher
- Maven or Gradle

## Installation

### Maven

Add this to your `pom.xml`:

```xml
<dependency>
    <groupId>com.yourorg</groupId>
    <artifactId>yourapi-sdk</artifactId>
    <version>0.1.0</version>
</dependency>
```

### Gradle

Add this to your `build.gradle`:

```gradle
implementation 'com.yourorg:yourapi-sdk:0.1.0'
```

## Quick Start

```java
import com.yourorg.yourapi.*;

public class Example {
    public static void main(String[] args) {
        // Initialize with API key
        ClientOptions options = new ClientOptions.Builder("https://api.yourorg.com/v1")
            .apiKey("your-api-key")
            .build();
        
        Client client = new Client(options);
        
        try {
            // Make a simple request
            Customer customer = client.get("/customers/123", Customer.class);
            System.out.println(customer.getName());
        } catch (APIError e) {
            System.err.println("Error: " + e.getMessage());
        }
    }
}
```

## Configuration Options

```java
ClientOptions options = new ClientOptions.Builder("https://api.yourorg.com/v1")
    .apiKey("your-api-key")              // Optional: API key auth
    .bearerToken("your-token")           // Optional: Bearer token auth
    .timeoutSeconds(15)                  // Optional: Timeout in seconds (default: 15)
    .maxRetries(3)                       // Optional: Max retries (default: 3)
    .userAgent("my-app/1.0")             // Optional: Custom user agent
    .addCustomHeader("X-App-Version", "1.0.0")  // Optional: Additional headers
    .debug(true)                         // Optional: Enable debug logging
    .build();

Client client = new Client(options);
```

## Pagination

### Cursor-based pagination

```java
// Define your model
class Customer {
    private String id;
    private String email;
    private String name;
    
    // Getters and setters...
}

try {
    // Fetch all customers across all pages
    List<Customer> customers = client.paginateCursor("/customers", Customer.class);
    
    for (Customer customer : customers) {
        System.out.println(customer.getName() + ": " + customer.getEmail());
    }
} catch (APIError e) {
    System.err.println("Error: " + e.getMessage());
}
```

## Error Handling

```java
try {
    Customer customer = client.get("/customers/123", Customer.class);
    System.out.println(customer.getName());
} catch (APIError e) {
    System.err.println("Status: " + e.getStatus());
    System.err.println("Code: " + e.getCode());
    System.err.println("Message: " + e.getMessage());
    System.err.println("Details: " + e.getDetails());
    System.err.println("Request ID: " + e.getRequestId());
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

```java
// Define your models
class CustomerCreate {
    private String email;
    private String name;
    // Constructors, getters, setters...
}

class CustomerUpdate {
    private String name;
    // Constructors, getters, setters...
}

try {
    // GET
    Customer customer = client.get("/customers/123", Customer.class);
    
    // POST
    CustomerCreate newCustomer = new CustomerCreate("user@example.com", "John Doe");
    Customer created = client.post("/customers", newCustomer, Customer.class);
    
    // POST with idempotency key
    Customer safe = client.post("/customers", newCustomer, "idem-key-123", Customer.class);
    
    // PATCH
    CustomerUpdate update = new CustomerUpdate("New Name");
    Customer updated = client.patch("/customers/123", update, Customer.class);
    
    // PUT
    CustomerCreate fullCustomer = new CustomerCreate("user@example.com", "John Doe");
    Customer replaced = client.put("/customers/123", fullCustomer, Customer.class);
    
    // DELETE
    client.delete("/customers/123");
    
} catch (APIError e) {
    System.err.println("Error: " + e.getMessage());
}
```

## Environment-specific Configuration

```java
public class Config {
    public static String getBaseUrl() {
        String environment = System.getenv("ENVIRONMENT");
        if (environment == null) environment = "development";
        
        switch (environment) {
            case "production":
                return "https://api.yourorg.com/v1";
            case "staging":
                return "https://staging-api.yourorg.com/v1";
            default:
                return "https://sandbox-api.yourorg.com/v1";
        }
    }
}

// Usage
ClientOptions options = new ClientOptions.Builder(Config.getBaseUrl())
    .apiKey(System.getenv("API_KEY"))
    .build();
Client client = new Client(options);
```

## Thread Safety

The `Client` instance is thread-safe and can be shared across threads. It's recommended to create a single `Client` instance and reuse it throughout your application.

## License

MIT

