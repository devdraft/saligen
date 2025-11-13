package com.yourorg.yourapi

import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.delay
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * YourAPI Kotlin SDK Client
 *
 * Production-ready Kotlin SDK with support for:
 * - Authentication (API Key & Bearer Token)
 * - Automatic retries with exponential backoff
 * - Configurable timeouts
 * - Pagination helpers
 * - Normalized error handling
 * - Telemetry headers
 * - Coroutines support
 */
class Client(private val options: ClientOptions) {
    private val baseUrl = options.baseUrl.trimEnd('/')
    private val httpClient: OkHttpClient
    private val gson = Gson()
    private val defaultHeaders: Map<String, String>

    init {
        // Build default headers
        val headers = mutableMapOf(
            "User-Agent" to options.userAgent,
            "X-SDK-Language" to "kotlin",
            "X-SDK-Version" to VERSION,
            "Content-Type" to "application/json",
            "Accept" to "application/json"
        )

        // Add auth headers
        when {
            options.bearerToken != null -> headers["Authorization"] = "Bearer ${options.bearerToken}"
            options.apiKey != null -> headers["X-API-Key"] = options.apiKey
        }

        // Add custom headers
        options.customHeaders?.let { headers.putAll(it) }
        defaultHeaders = headers

        // Build HTTP client
        httpClient = OkHttpClient.Builder()
            .connectTimeout(options.timeoutSeconds.toLong(), TimeUnit.SECONDS)
            .readTimeout(options.timeoutSeconds.toLong(), TimeUnit.SECONDS)
            .writeTimeout(options.timeoutSeconds.toLong(), TimeUnit.SECONDS)
            .build()
    }

    private fun logDebug(message: String) {
        if (options.debug) {
            println("[${Instant.now()}] [YourAPI] $message")
        }
    }

    private fun calculateBackoff(attempt: Int, retryAfter: String?): Long {
        retryAfter?.let {
            return try {
                it.toLong() * 1000
            } catch (e: NumberFormatException) {
                null
            }
        } ?: run {
            // Exponential backoff: 2^attempt, capped at 8 seconds
            return minOf((1L shl attempt) * 1000, 8000)
        }
    }

    private fun parseError(response: Response): APIError {
        val status = response.code
        var requestId = response.header("X-Request-Id")

        val body = response.body?.string()
        return if (body != null) {
            try {
                val json = gson.fromJson(body, JsonObject::class.java)
                val message = json.get("message")?.asString ?: "Request failed with status $status"
                val code = json.get("code")?.asString
                val details = json.get("details")
                requestId = json.get("requestId")?.asString ?: requestId

                APIError(message, status, code, details, requestId)
            } catch (e: Exception) {
                APIError("Request failed with status $status", status, null, null, requestId)
            }
        } else {
            APIError("Request failed with status $status", status, null, null, requestId)
        }
    }

    private suspend fun <T> makeRequest(
        method: String,
        path: String,
        data: Any? = null,
        additionalHeaders: Map<String, String>? = null,
        responseClass: Class<T>
    ): T? {
        val url = "$baseUrl$path"
        var lastError: APIError? = null

        repeat(options.maxRetries + 1) { attempt ->
            logDebug("$method $url (attempt ${attempt + 1}/${options.maxRetries + 1})")

            try {
                val requestBuilder = Request.Builder().url(url)

                // Add headers
                defaultHeaders.forEach { (key, value) ->
                    requestBuilder.addHeader(key, value)
                }
                additionalHeaders?.forEach { (key, value) ->
                    requestBuilder.addHeader(key, value)
                }

                // Add body and method
                val body = data?.let {
                    val json = gson.toJson(it)
                    json.toRequestBody("application/json".toMediaType())
                }

                when (method) {
                    "GET" -> requestBuilder.get()
                    "POST" -> requestBuilder.post(body ?: "".toRequestBody(null))
                    "PATCH" -> requestBuilder.patch(body ?: "".toRequestBody(null))
                    "PUT" -> requestBuilder.put(body ?: "".toRequestBody(null))
                    "DELETE" -> requestBuilder.delete(body)
                    else -> throw APIError("Unsupported HTTP method: $method", null, "INVALID_METHOD", null, null)
                }

                val request = requestBuilder.build()
                val response = httpClient.newCall(request).execute()

                logDebug("Response: ${response.code}")

                // Success
                if (response.isSuccessful) {
                    if (response.code == 204 || responseClass == Void::class.java) {
                        response.close()
                        return null
                    }

                    val responseBody = response.body?.string()
                    response.close()
                    return if (responseBody != null) {
                        gson.fromJson(responseBody, responseClass)
                    } else {
                        null
                    }
                }

                // Check for retryable errors
                val retryableStatuses = setOf(429, 500, 502, 503, 504)
                if (response.code in retryableStatuses && attempt < options.maxRetries) {
                    val retryAfter = response.header("Retry-After")
                    val backoff = calculateBackoff(attempt, retryAfter)
                    logDebug("Retrying after ${backoff}ms")
                    response.close()
                    delay(backoff)
                    return@repeat
                }

                // Non-retryable error
                val error = parseError(response)
                response.close()
                throw error

            } catch (e: APIError) {
                throw e
            } catch (e: Exception) {
                lastError = APIError("Request failed: ${e.message}", null, "REQUEST_ERROR", null, null)
                if (attempt < options.maxRetries) {
                    val backoff = calculateBackoff(attempt, null)
                    logDebug("Request error, retrying after ${backoff}ms: ${e.message}")
                    delay(backoff)
                    return@repeat
                }
            }
        }

        throw lastError ?: APIError("Max retries exceeded", null, "MAX_RETRIES_EXCEEDED", null, null)
    }

    /**
     * Make a GET request
     */
    suspend fun <T> get(path: String, responseClass: Class<T>): T? {
        return makeRequest("GET", path, responseClass = responseClass)
    }

    /**
     * Make a POST request
     */
    suspend fun <T> post(path: String, data: Any?, responseClass: Class<T>): T? {
        return makeRequest("POST", path, data, responseClass = responseClass)
    }

    /**
     * Make a POST request with idempotency key
     */
    suspend fun <T> post(path: String, data: Any?, idempotencyKey: String, responseClass: Class<T>): T? {
        val headers = mapOf("Idempotency-Key" to idempotencyKey)
        return makeRequest("POST", path, data, headers, responseClass)
    }

    /**
     * Make a PATCH request
     */
    suspend fun <T> patch(path: String, data: Any?, responseClass: Class<T>): T? {
        return makeRequest("PATCH", path, data, responseClass = responseClass)
    }

    /**
     * Make a PUT request
     */
    suspend fun <T> put(path: String, data: Any?, responseClass: Class<T>): T? {
        return makeRequest("PUT", path, data, responseClass = responseClass)
    }

    /**
     * Make a DELETE request
     */
    suspend fun delete(path: String) {
        makeRequest("DELETE", path, responseClass = Void::class.java)
    }

    /**
     * Paginate through cursor-based API results
     */
    suspend fun <T> paginateCursor(path: String, itemClass: Class<T>): List<T> {
        val allItems = mutableListOf<T>()
        var cursor: String? = null
        var hasMore = true

        while (hasMore) {
            val currentPath = if (cursor != null) {
                val separator = if (path.contains("?")) "&" else "?"
                "$path${separator}cursor=$cursor"
            } else {
                path
            }

            val response = get(currentPath, CursorPaginatedResponse::class.java)
            response?.let {
                @Suppress("UNCHECKED_CAST")
                val items = it.items as? List<T> ?: emptyList()
                allItems.addAll(items)
                cursor = it.nextCursor
                hasMore = it.hasMore && cursor != null
            } ?: run {
                hasMore = false
            }
        }

        return allItems
    }

    companion object {
        const val VERSION = "0.1.0"
    }
}

/**
 * Configuration options for the YourAPI client
 */
data class ClientOptions(
    val baseUrl: String,
    val apiKey: String? = null,
    val bearerToken: String? = null,
    val timeoutSeconds: Int = 15,
    val maxRetries: Int = 3,
    val userAgent: String = "yourapi-kotlin-sdk/${Client.VERSION}",
    val customHeaders: Map<String, String>? = null,
    val debug: Boolean = false
)

/**
 * Normalized API error
 */
class APIError(
    override val message: String,
    val status: Int?,
    val code: String?,
    val details: Any?,
    val requestId: String?
) : Exception(buildMessage(message, status, code, requestId)) {

    companion object {
        private fun buildMessage(message: String, status: Int?, code: String?, requestId: String?): String {
            val parts = mutableListOf(message)
            status?.let { parts.add("(status=$it)") }
            code?.let { parts.add("(code=$it)") }
            requestId?.let { parts.add("(request_id=$it)") }
            return parts.joinToString(" ")
        }
    }
}

/**
 * Cursor-based paginated response
 */
data class CursorPaginatedResponse<T>(
    val items: List<T> = emptyList(),
    val nextCursor: String? = null,
    val hasMore: Boolean = false
)

