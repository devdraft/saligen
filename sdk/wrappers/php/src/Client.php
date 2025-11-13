<?php

namespace YourOrg\YourAPI;

use Exception;

/**
 * YourAPI PHP SDK Client
 * 
 * Production-ready PHP SDK with support for:
 * - Authentication (API Key & Bearer Token)
 * - Automatic retries with exponential backoff
 * - Configurable timeouts
 * - Pagination helpers
 * - Normalized error handling
 * - Telemetry headers
 */
class Client
{
    const VERSION = '0.1.0';
    const DEFAULT_TIMEOUT = 15;
    const DEFAULT_MAX_RETRIES = 3;

    private string $baseUrl;
    private int $timeout;
    private int $maxRetries;
    private string $userAgent;
    private array $defaultHeaders = [];
    private bool $debug;

    /**
     * Create a new YourAPI client
     *
     * @param array $options Configuration options
     *   - baseUrl (string, required): Base URL for the API
     *   - apiKey (string, optional): API key for authentication
     *   - bearerToken (string, optional): Bearer token for authentication
     *   - timeout (int, optional): Request timeout in seconds (default: 15)
     *   - maxRetries (int, optional): Maximum number of retry attempts (default: 3)
     *   - userAgent (string, optional): Custom user agent
     *   - customHeaders (array, optional): Additional headers
     *   - debug (bool, optional): Enable debug logging (default: false)
     * @throws Exception if baseUrl is not provided
     */
    public function __construct(array $options)
    {
        if (empty($options['baseUrl'])) {
            throw new Exception('baseUrl is required');
        }

        $this->baseUrl = rtrim($options['baseUrl'], '/');
        $this->timeout = $options['timeout'] ?? self::DEFAULT_TIMEOUT;
        $this->maxRetries = $options['maxRetries'] ?? self::DEFAULT_MAX_RETRIES;
        $this->userAgent = $options['userAgent'] ?? 'yourapi-php-sdk/' . self::VERSION;
        $this->debug = $options['debug'] ?? false;

        // Build default headers
        $this->defaultHeaders = [
            'User-Agent' => $this->userAgent,
            'X-SDK-Language' => 'php',
            'X-SDK-Version' => self::VERSION,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
        ];

        // Add auth headers
        if (!empty($options['bearerToken'])) {
            $this->defaultHeaders['Authorization'] = 'Bearer ' . $options['bearerToken'];
        } elseif (!empty($options['apiKey'])) {
            $this->defaultHeaders['X-API-Key'] = $options['apiKey'];
        }

        // Add custom headers
        if (!empty($options['customHeaders'])) {
            $this->defaultHeaders = array_merge($this->defaultHeaders, $options['customHeaders']);
        }
    }

    /**
     * Log debug message if debug is enabled
     */
    private function logDebug(string $message): void
    {
        if ($this->debug) {
            $timestamp = date('c');
            echo "[{$timestamp}] [YourAPI] {$message}\n";
        }
    }

    /**
     * Make HTTP request with retry logic
     *
     * @param string $method HTTP method
     * @param string $path API path
     * @param array|null $data Request body data
     * @param array $additionalHeaders Additional headers for this request
     * @return mixed Response data
     * @throws APIError on request failure
     */
    private function makeRequest(
        string $method,
        string $path,
        ?array $data = null,
        array $additionalHeaders = []
    ) {
        $url = $this->baseUrl . '/' . ltrim($path, '/');
        $headers = array_merge($this->defaultHeaders, $additionalHeaders);

        $lastError = null;

        for ($attempt = 0; $attempt <= $this->maxRetries; $attempt++) {
            $this->logDebug("{$method} {$url} (attempt " . ($attempt + 1) . "/" . ($this->maxRetries + 1) . ")");

            try {
                $ch = curl_init();

                // Set URL
                curl_setopt($ch, CURLOPT_URL, $url);

                // Set method and body
                curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
                if ($data !== null) {
                    $jsonData = json_encode($data);
                    curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);
                }

                // Set headers
                $headerLines = [];
                foreach ($headers as $key => $value) {
                    $headerLines[] = "{$key}: {$value}";
                }
                curl_setopt($ch, CURLOPT_HTTPHEADER, $headerLines);

                // Set timeout
                curl_setopt($ch, CURLOPT_TIMEOUT, $this->timeout);
                curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, $this->timeout);

                // Return response
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

                // Capture headers
                $responseHeaders = [];
                curl_setopt($ch, CURLOPT_HEADERFUNCTION, function ($curl, $header) use (&$responseHeaders) {
                    $len = strlen($header);
                    $header = explode(':', $header, 2);
                    if (count($header) < 2) {
                        return $len;
                    }
                    $responseHeaders[strtolower(trim($header[0]))] = trim($header[1]);
                    return $len;
                });

                // Execute request
                $responseBody = curl_exec($ch);
                $statusCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                $curlError = curl_error($ch);
                curl_close($ch);

                $this->logDebug("Response: {$statusCode}");

                // Handle curl errors
                if ($responseBody === false) {
                    $lastError = new Exception("cURL error: {$curlError}");
                    if ($attempt < $this->maxRetries) {
                        $backoff = $this->calculateBackoff($attempt, null, []);
                        $this->logDebug("cURL error, retrying after {$backoff}s");
                        sleep($backoff);
                        continue;
                    }
                    throw new APIError("Request failed: {$curlError}", 0, 'CURL_ERROR');
                }

                // Success
                if ($statusCode >= 200 && $statusCode < 300) {
                    if ($statusCode === 204 || empty($responseBody)) {
                        return null;
                    }
                    return json_decode($responseBody, true);
                }

                // Handle retryable errors
                $retryableStatuses = [429, 500, 502, 503, 504];
                if (in_array($statusCode, $retryableStatuses) && $attempt < $this->maxRetries) {
                    $backoff = $this->calculateBackoff($attempt, $statusCode, $responseHeaders);
                    $this->logDebug("Retrying after {$backoff}s");
                    sleep($backoff);
                    continue;
                }

                // Handle error response
                $errorData = json_decode($responseBody, true);
                throw $this->createError($statusCode, $errorData, $responseHeaders);

            } catch (APIError $e) {
                throw $e;
            } catch (Exception $e) {
                $lastError = $e;
                if ($attempt < $this->maxRetries) {
                    $backoff = $this->calculateBackoff($attempt, null, []);
                    $this->logDebug("Unexpected error, retrying after {$backoff}s: " . $e->getMessage());
                    sleep($backoff);
                    continue;
                }
                throw new APIError("Unexpected error: " . $e->getMessage(), 0, 'UNEXPECTED_ERROR');
            }
        }

        throw new APIError("Max retries exceeded", 0, 'MAX_RETRIES_EXCEEDED');
    }

    /**
     * Calculate backoff duration for retries
     */
    private function calculateBackoff(int $attempt, ?int $statusCode, array $headers): int
    {
        // Check for Retry-After header
        if (isset($headers['retry-after'])) {
            $retryAfter = $headers['retry-after'];
            if (is_numeric($retryAfter)) {
                return (int) $retryAfter;
            }
            // Try parsing as date
            $retryDate = strtotime($retryAfter);
            if ($retryDate !== false) {
                $backoff = $retryDate - time();
                if ($backoff > 0) {
                    return $backoff;
                }
            }
        }

        // Exponential backoff: 2^attempt, capped at 8 seconds
        return min(pow(2, $attempt), 8);
    }

    /**
     * Create APIError from response data
     */
    private function createError(int $status, ?array $data, array $headers): APIError
    {
        $message = $data['message'] ?? "Request failed with status {$status}";
        $code = $data['code'] ?? null;
        $details = $data['details'] ?? null;
        $requestId = $data['requestId'] ?? $headers['x-request-id'] ?? null;

        return new APIError($message, $status, $code, $details, $requestId);
    }

    /**
     * Make a GET request
     *
     * @param string $path API path
     * @param array $params Query parameters
     * @return mixed Response data
     */
    public function get(string $path, array $params = [])
    {
        if (!empty($params)) {
            $path .= '?' . http_build_query($params);
        }
        return $this->makeRequest('GET', $path);
    }

    /**
     * Make a POST request
     *
     * @param string $path API path
     * @param array|null $data Request body
     * @param string|null $idempotencyKey Idempotency key for safe retries
     * @return mixed Response data
     */
    public function post(string $path, ?array $data = null, ?string $idempotencyKey = null)
    {
        $headers = [];
        if ($idempotencyKey !== null) {
            $headers['Idempotency-Key'] = $idempotencyKey;
        }
        return $this->makeRequest('POST', $path, $data, $headers);
    }

    /**
     * Make a PATCH request
     *
     * @param string $path API path
     * @param array|null $data Request body
     * @return mixed Response data
     */
    public function patch(string $path, ?array $data = null)
    {
        return $this->makeRequest('PATCH', $path, $data);
    }

    /**
     * Make a PUT request
     *
     * @param string $path API path
     * @param array|null $data Request body
     * @return mixed Response data
     */
    public function put(string $path, ?array $data = null)
    {
        return $this->makeRequest('PUT', $path, $data);
    }

    /**
     * Make a DELETE request
     *
     * @param string $path API path
     * @return mixed Response data
     */
    public function delete(string $path)
    {
        return $this->makeRequest('DELETE', $path);
    }

    /**
     * Paginate through cursor-based API results
     *
     * @param string $path API path
     * @param array $params Query parameters
     * @param string $cursorParam Name of cursor query parameter
     * @param string $itemsKey Name of items array in response
     * @param string $nextCursorKey Name of next cursor field in response
     * @param string $hasMoreKey Name of hasMore boolean field in response
     * @return \Generator Yields individual items
     */
    public function paginateCursor(
        string $path,
        array $params = [],
        string $cursorParam = 'cursor',
        string $itemsKey = 'items',
        string $nextCursorKey = 'nextCursor',
        string $hasMoreKey = 'hasMore'
    ): \Generator {
        $cursor = null;
        $hasMore = true;

        while ($hasMore) {
            $queryParams = $params;
            if ($cursor !== null) {
                $queryParams[$cursorParam] = $cursor;
            }

            $response = $this->get($path, $queryParams);
            $items = $response[$itemsKey] ?? [];

            foreach ($items as $item) {
                yield $item;
            }

            $cursor = $response[$nextCursorKey] ?? null;
            $hasMore = $response[$hasMoreKey] ?? false;

            if ($cursor === null || !$hasMore) {
                break;
            }
        }
    }

    /**
     * Paginate through page-based API results
     *
     * @param string $path API path
     * @param array $params Query parameters
     * @param string $pageParam Name of page query parameter
     * @param string $perPageParam Name of per-page query parameter
     * @param string $itemsKey Name of items array in response
     * @param string $totalPagesKey Name of total pages field in response
     * @return \Generator Yields individual items
     */
    public function paginatePage(
        string $path,
        array $params = [],
        string $pageParam = 'page',
        string $perPageParam = 'perPage',
        string $itemsKey = 'items',
        string $totalPagesKey = 'totalPages'
    ): \Generator {
        $page = 1;
        $totalPages = 1;

        while ($page <= $totalPages) {
            $queryParams = $params;
            $queryParams[$pageParam] = $page;

            $response = $this->get($path, $queryParams);
            $items = $response[$itemsKey] ?? [];

            foreach ($items as $item) {
                yield $item;
            }

            $totalPages = $response[$totalPagesKey] ?? $page;
            $page++;
        }
    }

    /**
     * Fetch all pages and return as array (cursor-based)
     *
     * @param string $path API path
     * @param array $params Query parameters
     * @return array All items
     */
    public function getAllCursor(string $path, array $params = []): array
    {
        return iterator_to_array($this->paginateCursor($path, $params));
    }

    /**
     * Fetch all pages and return as array (page-based)
     *
     * @param string $path API path
     * @param array $params Query parameters
     * @return array All items
     */
    public function getAllPage(string $path, array $params = []): array
    {
        return iterator_to_array($this->paginatePage($path, $params));
    }
}

/**
 * Normalized API error
 */
class APIError extends Exception
{
    private ?string $code;
    private $details;
    private ?string $requestId;
    private int $status;

    public function __construct(
        string $message,
        int $status = 0,
        ?string $code = null,
        $details = null,
        ?string $requestId = null
    ) {
        parent::__construct($message);
        $this->status = $status;
        $this->code = $code;
        $this->details = $details;
        $this->requestId = $requestId;
    }

    public function getStatus(): int
    {
        return $this->status;
    }

    public function getErrorCode(): ?string
    {
        return $this->code;
    }

    public function getDetails()
    {
        return $this->details;
    }

    public function getRequestId(): ?string
    {
        return $this->requestId;
    }

    public function __toString(): string
    {
        $parts = [$this->getMessage()];
        if ($this->status > 0) {
            $parts[] = "(status={$this->status})";
        }
        if ($this->code) {
            $parts[] = "(code={$this->code})";
        }
        if ($this->requestId) {
            $parts[] = "(request_id={$this->requestId})";
        }
        return implode(' ', $parts);
    }
}

