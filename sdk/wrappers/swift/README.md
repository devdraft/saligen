# YourAPI Swift SDK

Production-ready Swift SDK for YourAPI with built-in support for:

- ✅ Authentication (API Key & Bearer Token)
- ✅ Automatic retries with exponential backoff
- ✅ Configurable timeouts
- ✅ Cursor-based pagination helpers
- ✅ Normalized error handling
- ✅ Telemetry headers
- ✅ Async/await support
- ✅ Type safety with Codable
- ✅ Debug logging
- ✅ Zero external dependencies

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.7+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourorg/yourapi-swift.git", from: "0.1.0")
]
```

Or add it through Xcode: File > Add Packages...

## Quick Start

```swift
import YourAPI

// Initialize with API key
let client = Client(options: ClientOptions(
    baseURL: "https://api.yourorg.com/v1",
    apiKey: "your-api-key"
))

// Make a simple request
struct Customer: Codable {
    let id: String
    let email: String
    let name: String
}

Task {
    do {
        let customer: Customer? = try await client.get(path: "/customers/123")
        print(customer?.name ?? "Not found")
    } catch {
        print("Error: \(error)")
    }
}
```

## Configuration Options

```swift
let options = ClientOptions(
    baseURL: "https://api.yourorg.com/v1",    // Required: API base URL
    apiKey: "your-api-key",                    // Optional: API key auth
    bearerToken: "your-token",                 // Optional: Bearer token auth
    timeoutSeconds: 15,                        // Optional: Timeout in seconds (default: 15)
    maxRetries: 3,                             // Optional: Max retries (default: 3)
    userAgent: "my-app/1.0",                   // Optional: Custom user agent
    customHeaders: [                           // Optional: Additional headers
        "X-App-Version": "1.0.0"
    ],
    debug: true                                // Optional: Enable debug logging
)

let client = Client(options: options)
```

## Pagination

### Cursor-based pagination

```swift
struct Customer: Codable {
    let id: String
    let email: String
    let name: String
}

Task {
    do {
        // Fetch all customers across all pages
        let customers: [Customer] = try await client.paginateCursor(path: "/customers")
        
        for customer in customers {
            print("\(customer.name): \(customer.email)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

## Error Handling

```swift
do {
    let customer: Customer? = try await client.get(path: "/customers/123")
    print(customer?.name ?? "Not found")
} catch let error as APIError {
    print("Status: \(error.status ?? 0)")
    print("Code: \(error.code ?? "unknown")")
    print("Message: \(error.message)")
    if let requestID = error.requestID {
        print("Request ID: \(requestID)")
    }
} catch {
    print("Unexpected error: \(error)")
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

```swift
struct Customer: Codable {
    let id: String
    let email: String
    let name: String
}

struct CustomerCreate: Codable {
    let email: String
    let name: String
}

struct CustomerUpdate: Codable {
    let name: String
}

Task {
    // GET
    let customer: Customer? = try await client.get(path: "/customers/123")
    
    // POST
    let newCustomer = CustomerCreate(email: "user@example.com", name: "John Doe")
    let created: Customer? = try await client.post(path: "/customers", body: newCustomer)
    
    // POST with idempotency key
    let safe: Customer? = try await client.post(
        path: "/customers",
        body: newCustomer,
        idempotencyKey: "idem-key-123"
    )
    
    // PATCH
    let update = CustomerUpdate(name: "New Name")
    let updated: Customer? = try await client.patch(path: "/customers/123", body: update)
    
    // PUT
    let fullCustomer = CustomerCreate(email: "user@example.com", name: "John Doe")
    let replaced: Customer? = try await client.put(path: "/customers/123", body: fullCustomer)
    
    // DELETE
    try await client.delete(path: "/customers/123")
}
```

## Environment-specific Configuration

```swift
import Foundation

func getBaseURL() -> String {
    let environment = ProcessInfo.processInfo.environment["ENVIRONMENT"] ?? "development"
    switch environment {
    case "production":
        return "https://api.yourorg.com/v1"
    case "staging":
        return "https://staging-api.yourorg.com/v1"
    default:
        return "https://sandbox-api.yourorg.com/v1"
    }
}

let client = Client(options: ClientOptions(
    baseURL: getBaseURL(),
    apiKey: ProcessInfo.processInfo.environment["API_KEY"]
))
```

## Using with SwiftUI

```swift
import SwiftUI
import YourAPI

struct Customer: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
}

class CustomerViewModel: ObservableObject {
    @Published var customers: [Customer] = []
    @Published var error: String?
    
    private let client = Client(options: ClientOptions(
        baseURL: "https://api.yourorg.com/v1",
        apiKey: "your-api-key"
    ))
    
    func loadCustomers() async {
        do {
            customers = try await client.paginateCursor(path: "/customers")
        } catch let error as APIError {
            self.error = error.message
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct CustomerListView: View {
    @StateObject private var viewModel = CustomerViewModel()
    
    var body: some View {
        List(viewModel.customers) { customer in
            VStack(alignment: .leading) {
                Text(customer.name)
                    .font(.headline)
                Text(customer.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await viewModel.loadCustomers()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}
```

## License

MIT

