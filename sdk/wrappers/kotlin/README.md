# YourAPI Kotlin SDK

Production-ready Kotlin SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Coroutines support
- ✅ Type safety with data classes
- ✅ Debug logging
- ✅ Idiomatic Kotlin API

## Requirements

- Kotlin 1.9 or higher
- Java 11 or higher
- Gradle or Maven

## Installation

### Gradle (Kotlin DSL)

Add this to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.yourorg:yourapi-sdk-kotlin:0.1.0")
}
```

### Gradle (Groovy)

Add this to your `build.gradle`:

```groovy
dependencies {
    implementation 'com.yourorg:yourapi-sdk-kotlin:0.1.0'
}
```

### Maven

Add this to your `pom.xml`:

```xml
<dependency>
    <groupId>com.yourorg</groupId>
    <artifactId>yourapi-sdk-kotlin</artifactId>
    <version>0.1.0</version>
</dependency>
```

## Quick Start

```kotlin
import com.yourorg.yourapi.Client
import com.yourorg.yourapi.ClientOptions
import kotlinx.coroutines.runBlocking

data class Customer(
    val id: String,
    val email: String,
    val name: String
)

fun main() = runBlocking {
    // Initialize with API key
    val client = Client(
        ClientOptions(
            baseUrl = "https://api.yourorg.com/v1",
            apiKey = "your-api-key"
        )
    )
    
    try {
        // Make a simple request
        val customer = client.get("/customers/123", Customer::class.java)
        println(customer?.name)
    } catch (e: Exception) {
        println("Error: ${e.message}")
    }
}
```

## Configuration Options

```kotlin
val options = ClientOptions(
    baseUrl = "https://api.yourorg.com/v1",    // Required: API base URL
    apiKey = "your-api-key",                    // Optional: API key auth
    bearerToken = "your-token",                 // Optional: Bearer token auth
    timeoutSeconds = 15,                        // Optional: Timeout in seconds (default: 15)
    maxRetries = 3,                             // Optional: Max retries (default: 3)
    userAgent = "my-app/1.0",                   // Optional: Custom user agent
    customHeaders = mapOf(                      // Optional: Additional headers
        "X-App-Version" to "1.0.0"
    ),
    debug = true                                // Optional: Enable debug logging
)

val client = Client(options)
```

## Pagination

### Cursor-based pagination

```kotlin
import kotlinx.coroutines.runBlocking

data class Customer(
    val id: String,
    val email: String,
    val name: String
)

fun main() = runBlocking {
    try {
        // Fetch all customers across all pages
        val customers = client.paginateCursor("/customers", Customer::class.java)
        
        customers.forEach { customer ->
            println("${customer.name}: ${customer.email}")
        }
    } catch (e: Exception) {
        println("Error: ${e.message}")
    }
}
```

## Error Handling

```kotlin
import com.yourorg.yourapi.APIError

try {
    val customer = client.get("/customers/123", Customer::class.java)
    println(customer?.name)
} catch (e: APIError) {
    println("Status: ${e.status}")
    println("Code: ${e.code}")
    println("Message: ${e.message}")
    println("Details: ${e.details}")
    println("Request ID: ${e.requestId}")
} catch (e: Exception) {
    println("Unexpected error: ${e.message}")
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

```kotlin
data class CustomerCreate(
    val email: String,
    val name: String
)

data class CustomerUpdate(
    val name: String
)

suspend fun examples() {
    // GET
    val customer = client.get("/customers/123", Customer::class.java)
    
    // POST
    val newCustomer = CustomerCreate(email = "user@example.com", name = "John Doe")
    val created = client.post("/customers", newCustomer, Customer::class.java)
    
    // POST with idempotency key
    val safe = client.post("/customers", newCustomer, "idem-key-123", Customer::class.java)
    
    // PATCH
    val update = CustomerUpdate(name = "New Name")
    val updated = client.patch("/customers/123", update, Customer::class.java)
    
    // PUT
    val fullCustomer = CustomerCreate(email = "user@example.com", name = "John Doe")
    val replaced = client.put("/customers/123", fullCustomer, Customer::class.java)
    
    // DELETE
    client.delete("/customers/123")
}
```

## Environment-specific Configuration

```kotlin
object Config {
    fun getBaseUrl(): String {
        val environment = System.getenv("ENVIRONMENT") ?: "development"
        return when (environment) {
            "production" -> "https://api.yourorg.com/v1"
            "staging" -> "https://staging-api.yourorg.com/v1"
            else -> "https://sandbox-api.yourorg.com/v1"
        }
    }
}

// Usage
val client = Client(
    ClientOptions(
        baseUrl = Config.getBaseUrl(),
        apiKey = System.getenv("API_KEY")
    )
)
```

## Coroutines Support

The SDK is built with Kotlin coroutines for async operations:

```kotlin
import kotlinx.coroutines.*

fun main() = runBlocking {
    val client = Client(
        ClientOptions(
            baseUrl = "https://api.yourorg.com/v1",
            apiKey = "your-api-key"
        )
    )
    
    // Launch multiple requests concurrently
    val deferredCustomer = async { client.get("/customers/123", Customer::class.java) }
    val deferredOrders = async { client.get("/orders", OrderList::class.java) }
    
    val customer = deferredCustomer.await()
    val orders = deferredOrders.await()
    
    println("Customer: ${customer?.name}")
    println("Orders: ${orders?.items?.size}")
}
```

## Thread Safety

The `Client` instance is thread-safe and can be shared across coroutines and threads.

## License

MIT

