package com.yourorg.yourapi;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import okhttp3.*;

import java.io.IOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * YourAPI Java SDK Client
 * 
 * Production-ready Java SDK with support for:
 * - Authentication (API Key & Bearer Token)
 * - Automatic retries with exponential backoff
 * - Configurable timeouts
 * - Pagination helpers
 * - Normalized error handling
 * - Telemetry headers
 */
public class Client {
    private static final String VERSION = "0.1.0";
    private static final int DEFAULT_TIMEOUT_SECONDS = 15;
    private static final int DEFAULT_MAX_RETRIES = 3;
    
    private final String baseUrl;
    private final OkHttpClient httpClient;
    private final int maxRetries;
    private final boolean debug;
    private final Gson gson;
    private final Map<String, String> defaultHeaders;
    
    /**
     * Create a new YourAPI client with options
     */
    public Client(ClientOptions options) {
        this.baseUrl = options.getBaseUrl().replaceAll("/$", "");
        this.maxRetries = options.getMaxRetries();
        this.debug = options.isDebug();
        this.gson = new Gson();
        
        // Build default headers
        this.defaultHeaders = new HashMap<>();
        defaultHeaders.put("User-Agent", options.getUserAgent());
        defaultHeaders.put("X-SDK-Language", "java");
        defaultHeaders.put("X-SDK-Version", VERSION);
        defaultHeaders.put("Content-Type", "application/json");
        defaultHeaders.put("Accept", "application/json");
        
        // Add auth headers
        if (options.getBearerToken() != null) {
            defaultHeaders.put("Authorization", "Bearer " + options.getBearerToken());
        } else if (options.getApiKey() != null) {
            defaultHeaders.put("X-API-Key", options.getApiKey());
        }
        
        // Add custom headers
        if (options.getCustomHeaders() != null) {
            defaultHeaders.putAll(options.getCustomHeaders());
        }
        
        // Build HTTP client
        OkHttpClient.Builder builder = new OkHttpClient.Builder()
            .connectTimeout(options.getTimeoutSeconds(), TimeUnit.SECONDS)
            .readTimeout(options.getTimeoutSeconds(), TimeUnit.SECONDS)
            .writeTimeout(options.getTimeoutSeconds(), TimeUnit.SECONDS);
        
        this.httpClient = builder.build();
    }
    
    private void logDebug(String message) {
        if (debug) {
            System.out.println(String.format("[%s] [YourAPI] %s",
                java.time.Instant.now().toString(), message));
        }
    }
    
    private long calculateBackoff(int attempt, String retryAfter) {
        if (retryAfter != null && !retryAfter.isEmpty()) {
            try {
                // Try parsing as seconds
                return Long.parseLong(retryAfter) * 1000;
            } catch (NumberFormatException e) {
                // Could parse as date, but for simplicity, fall through
            }
        }
        
        // Exponential backoff: 2^attempt, capped at 8 seconds
        return Math.min((long) Math.pow(2, attempt) * 1000, 8000);
    }
    
    private APIError parseError(Response response) throws IOException {
        int status = response.code();
        String requestId = response.header("X-Request-Id");
        
        ResponseBody body = response.body();
        if (body != null) {
            try {
                String bodyStr = body.string();
                JsonObject json = gson.fromJson(bodyStr, JsonObject.class);
                
                String message = json.has("message") ? json.get("message").getAsString() 
                    : "Request failed with status " + status;
                String code = json.has("code") ? json.get("code").getAsString() : null;
                Object details = json.has("details") ? json.get("details") : null;
                if (json.has("requestId")) {
                    requestId = json.get("requestId").getAsString();
                }
                
                return new APIError(message, status, code, details, requestId);
            } catch (Exception e) {
                // Failed to parse error body
            }
        }
        
        return new APIError("Request failed with status " + status, status, null, null, requestId);
    }
    
    private <T> T makeRequest(String method, String path, Object data, 
                             Map<String, String> additionalHeaders, Class<T> responseType) 
            throws APIError {
        String url = baseUrl + path;
        APIError lastError = null;
        
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            logDebug(String.format("%s %s (attempt %d/%d)", 
                method, url, attempt + 1, maxRetries + 1));
            
            try {
                Request.Builder requestBuilder = new Request.Builder().url(url);
                
                // Add headers
                for (Map.Entry<String, String> entry : defaultHeaders.entrySet()) {
                    requestBuilder.addHeader(entry.getKey(), entry.getValue());
                }
                if (additionalHeaders != null) {
                    for (Map.Entry<String, String> entry : additionalHeaders.entrySet()) {
                        requestBuilder.addHeader(entry.getKey(), entry.getValue());
                    }
                }
                
                // Add body and method
                RequestBody body = null;
                if (data != null) {
                    String json = gson.toJson(data);
                    body = RequestBody.create(json, MediaType.parse("application/json"));
                }
                
                switch (method) {
                    case "GET":
                        requestBuilder.get();
                        break;
                    case "POST":
                        requestBuilder.post(body != null ? body : RequestBody.create("", null));
                        break;
                    case "PATCH":
                        requestBuilder.patch(body != null ? body : RequestBody.create("", null));
                        break;
                    case "PUT":
                        requestBuilder.put(body != null ? body : RequestBody.create("", null));
                        break;
                    case "DELETE":
                        requestBuilder.delete(body);
                        break;
                    default:
                        throw new APIError("Unsupported HTTP method: " + method, 0, "INVALID_METHOD", null, null);
                }
                
                Request request = requestBuilder.build();
                Response response = httpClient.newCall(request).execute();
                
                logDebug("Response: " + response.code());
                
                // Success
                if (response.isSuccessful()) {
                    if (response.code() == 204 || responseType == Void.class) {
                        response.close();
                        return null;
                    }
                    
                    ResponseBody responseBody = response.body();
                    if (responseBody != null) {
                        String bodyStr = responseBody.string();
                        response.close();
                        return gson.fromJson(bodyStr, responseType);
                    }
                    response.close();
                    return null;
                }
                
                // Check for retryable errors
                int[] retryableStatuses = {429, 500, 502, 503, 504};
                boolean isRetryable = false;
                for (int status : retryableStatuses) {
                    if (response.code() == status) {
                        isRetryable = true;
                        break;
                    }
                }
                
                if (isRetryable && attempt < maxRetries) {
                    String retryAfter = response.header("Retry-After");
                    long backoff = calculateBackoff(attempt, retryAfter);
                    logDebug("Retrying after " + backoff + "ms");
                    response.close();
                    Thread.sleep(backoff);
                    continue;
                }
                
                // Non-retryable error
                APIError error = parseError(response);
                response.close();
                throw error;
                
            } catch (APIError e) {
                throw e;
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new APIError("Request interrupted: " + e.getMessage(), 0, "INTERRUPTED", null, null);
            } catch (Exception e) {
                lastError = new APIError("Request failed: " + e.getMessage(), 0, "REQUEST_ERROR", null, null);
                if (attempt < maxRetries) {
                    long backoff = calculateBackoff(attempt, null);
                    logDebug("Request error, retrying after " + backoff + "ms: " + e.getMessage());
                    try {
                        Thread.sleep(backoff);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        throw new APIError("Request interrupted", 0, "INTERRUPTED", null, null);
                    }
                    continue;
                }
            }
        }
        
        if (lastError != null) {
            throw lastError;
        }
        throw new APIError("Max retries exceeded", 0, "MAX_RETRIES_EXCEEDED", null, null);
    }
    
    /**
     * Make a GET request
     */
    public <T> T get(String path, Class<T> responseType) throws APIError {
        return makeRequest("GET", path, null, null, responseType);
    }
    
    /**
     * Make a POST request
     */
    public <T> T post(String path, Object data, Class<T> responseType) throws APIError {
        return makeRequest("POST", path, data, null, responseType);
    }
    
    /**
     * Make a POST request with idempotency key
     */
    public <T> T post(String path, Object data, String idempotencyKey, Class<T> responseType) throws APIError {
        Map<String, String> headers = new HashMap<>();
        headers.put("Idempotency-Key", idempotencyKey);
        return makeRequest("POST", path, data, headers, responseType);
    }
    
    /**
     * Make a PATCH request
     */
    public <T> T patch(String path, Object data, Class<T> responseType) throws APIError {
        return makeRequest("PATCH", path, data, null, responseType);
    }
    
    /**
     * Make a PUT request
     */
    public <T> T put(String path, Object data, Class<T> responseType) throws APIError {
        return makeRequest("PUT", path, data, null, responseType);
    }
    
    /**
     * Make a DELETE request
     */
    public void delete(String path) throws APIError {
        makeRequest("DELETE", path, null, null, Void.class);
    }
    
    /**
     * Paginate through cursor-based API results
     */
    public <T> List<T> paginateCursor(String path, Class<T> itemType) throws APIError {
        List<T> allItems = new ArrayList<>();
        String cursor = null;
        boolean hasMore = true;
        
        while (hasMore) {
            String currentPath = path;
            if (cursor != null) {
                String separator = path.contains("?") ? "&" : "?";
                currentPath = path + separator + "cursor=" + cursor;
            }
            
            CursorPaginatedResponse<T> response = get(currentPath, 
                com.google.gson.reflect.TypeToken.getParameterized(
                    CursorPaginatedResponse.class, itemType).getRawType());
            
            if (response != null && response.getItems() != null) {
                allItems.addAll(response.getItems());
                cursor = response.getNextCursor();
                hasMore = response.isHasMore() && cursor != null;
            } else {
                break;
            }
        }
        
        return allItems;
    }
}

