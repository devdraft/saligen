package yourapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"time"
)

const (
	// Version is the SDK version
	Version = "0.1.0"
	// DefaultTimeout is the default request timeout
	DefaultTimeout = 15 * time.Second
	// DefaultMaxRetries is the default maximum number of retries
	DefaultMaxRetries = 3
)

// ClientOptions contains configuration options for the SDK client
type ClientOptions struct {
	// BaseURL is the base URL for the API (required)
	BaseURL string
	// APIKey is the API key for authentication (optional)
	APIKey string
	// BearerToken is the bearer token for authentication (optional)
	BearerToken string
	// Timeout is the request timeout (default: 15s)
	Timeout time.Duration
	// MaxRetries is the maximum number of retry attempts (default: 3)
	MaxRetries int
	// UserAgent is the custom user agent string
	UserAgent string
	// CustomHeaders are additional headers to include in all requests
	CustomHeaders map[string]string
	// HTTPClient is a custom HTTP client (optional)
	HTTPClient *http.Client
	// Debug enables debug logging
	Debug bool
}

// Client is the main SDK client
type Client struct {
	baseURL       string
	httpClient    *http.Client
	maxRetries    int
	userAgent     string
	customHeaders map[string]string
	debug         bool
}

// APIError represents a structured API error
type APIError struct {
	Message   string                 `json:"message"`
	Code      string                 `json:"code,omitempty"`
	Details   interface{}            `json:"details,omitempty"`
	RequestID string                 `json:"requestId,omitempty"`
	Status    int                    `json:"-"`
	Body      map[string]interface{} `json:"-"`
}

func (e *APIError) Error() string {
	if e.RequestID != "" {
		return fmt.Sprintf("[%d] %s (code=%s, request_id=%s)", e.Status, e.Message, e.Code, e.RequestID)
	}
	if e.Code != "" {
		return fmt.Sprintf("[%d] %s (code=%s)", e.Status, e.Message, e.Code)
	}
	return fmt.Sprintf("[%d] %s", e.Status, e.Message)
}

// CursorPaginatedResponse represents a cursor-based paginated response
type CursorPaginatedResponse struct {
	Items      []interface{} `json:"items"`
	NextCursor *string       `json:"nextCursor"`
	HasMore    bool          `json:"hasMore"`
}

// PagePaginatedResponse represents a page-based paginated response
type PagePaginatedResponse struct {
	Items      []interface{} `json:"items"`
	Page       int           `json:"page"`
	PerPage    int           `json:"perPage"`
	TotalPages int           `json:"totalPages"`
	TotalItems int           `json:"totalItems"`
}

// NewClient creates a new SDK client
func NewClient(opts ClientOptions) (*Client, error) {
	if opts.BaseURL == "" {
		return nil, fmt.Errorf("base URL is required")
	}

	// Set defaults
	if opts.Timeout == 0 {
		opts.Timeout = DefaultTimeout
	}
	if opts.MaxRetries == 0 {
		opts.MaxRetries = DefaultMaxRetries
	}
	if opts.UserAgent == "" {
		opts.UserAgent = fmt.Sprintf("yourapi-go-sdk/%s", Version)
	}

	// Create HTTP client with timeout
	httpClient := opts.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{
			Timeout: opts.Timeout,
		}
	}

	return &Client{
		baseURL:       opts.BaseURL,
		httpClient:    httpClient,
		maxRetries:    opts.MaxRetries,
		userAgent:     opts.UserAgent,
		customHeaders: opts.CustomHeaders,
		debug:         opts.Debug,
	}, nil
}

// logDebug logs debug messages if debug mode is enabled
func (c *Client) logDebug(format string, args ...interface{}) {
	if c.debug {
		timestamp := time.Now().Format(time.RFC3339)
		fmt.Printf("[%s] [YourAPI] %s\n", timestamp, fmt.Sprintf(format, args...))
	}
}

// buildHeaders creates headers for the request
func (c *Client) buildHeaders(opts ClientOptions, additionalHeaders map[string]string) map[string]string {
	headers := map[string]string{
		"User-Agent":     c.userAgent,
		"X-SDK-Language": "go",
		"X-SDK-Version":  Version,
		"Content-Type":   "application/json",
	}

	// Add auth headers
	if opts.BearerToken != "" {
		headers["Authorization"] = "Bearer " + opts.BearerToken
	} else if opts.APIKey != "" {
		headers["X-API-Key"] = opts.APIKey
	}

	// Add custom headers
	for k, v := range c.customHeaders {
		headers[k] = v
	}

	// Add request-specific headers
	for k, v := range additionalHeaders {
		headers[k] = v
	}

	return headers
}

// doRequest performs an HTTP request with retry logic
func (c *Client) doRequest(ctx context.Context, method, path string, body interface{}, headers map[string]string) (*http.Response, error) {
	url := c.baseURL + path

	var bodyReader io.Reader
	if body != nil {
		jsonData, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		bodyReader = bytes.NewReader(jsonData)
	}

	var lastErr error
	for attempt := 0; attempt <= c.maxRetries; attempt++ {
		c.logDebug("%s %s (attempt %d/%d)", method, url, attempt+1, c.maxRetries+1)

		// Reset body reader for retries
		if body != nil {
			jsonData, _ := json.Marshal(body)
			bodyReader = bytes.NewReader(jsonData)
		}

		req, err := http.NewRequestWithContext(ctx, method, url, bodyReader)
		if err != nil {
			return nil, fmt.Errorf("failed to create request: %w", err)
		}

		// Add headers
		for k, v := range headers {
			req.Header.Set(k, v)
		}

		resp, err := c.httpClient.Do(req)
		if err != nil {
			lastErr = err
			if attempt < c.maxRetries {
				backoff := c.calculateBackoff(attempt, nil)
				c.logDebug("Request error, retrying after %v: %v", backoff, err)
				time.Sleep(backoff)
				continue
			}
			return nil, fmt.Errorf("request failed: %w", err)
		}

		c.logDebug("Response: %d", resp.StatusCode)

		// Success
		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			return resp, nil
		}

		// Check if we should retry
		retryableStatuses := map[int]bool{
			429: true, 500: true, 502: true, 503: true, 504: true,
		}

		if retryableStatuses[resp.StatusCode] && attempt < c.maxRetries {
			backoff := c.calculateBackoff(attempt, resp)
			c.logDebug("Retrying after %v", backoff)
			
			// Drain and close the response body
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			
			time.Sleep(backoff)
			continue
		}

		// Not retryable, return error
		return resp, nil
	}

	return nil, fmt.Errorf("max retries exceeded: %w", lastErr)
}

// calculateBackoff calculates the backoff duration for retries
func (c *Client) calculateBackoff(attempt int, resp *http.Response) time.Duration {
	// Check for Retry-After header
	if resp != nil {
		retryAfter := resp.Header.Get("Retry-After")
		if retryAfter != "" {
			// Try parsing as seconds
			if seconds, err := strconv.Atoi(retryAfter); err == nil {
				return time.Duration(seconds) * time.Second
			}
			// Try parsing as date
			if retryDate, err := time.Parse(time.RFC1123, retryAfter); err == nil {
				duration := time.Until(retryDate)
				if duration > 0 {
					return duration
				}
			}
		}
	}

	// Exponential backoff: 2^attempt seconds, capped at 8 seconds
	backoff := math.Min(math.Pow(2, float64(attempt)), 8)
	return time.Duration(backoff) * time.Second
}

// parseError parses an error response
func (c *Client) parseError(resp *http.Response) error {
	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return &APIError{
			Message: "Failed to read error response",
			Status:  resp.StatusCode,
		}
	}

	var errorBody map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &errorBody); err != nil {
		return &APIError{
			Message: string(bodyBytes),
			Status:  resp.StatusCode,
		}
	}

	apiErr := &APIError{
		Status: resp.StatusCode,
		Body:   errorBody,
	}

	if msg, ok := errorBody["message"].(string); ok {
		apiErr.Message = msg
	} else {
		apiErr.Message = "Request failed"
	}

	if code, ok := errorBody["code"].(string); ok {
		apiErr.Code = code
	}

	if details, ok := errorBody["details"]; ok {
		apiErr.Details = details
	}

	if requestID, ok := errorBody["requestId"].(string); ok {
		apiErr.RequestID = requestID
	} else if requestID := resp.Header.Get("X-Request-Id"); requestID != "" {
		apiErr.RequestID = requestID
	}

	return apiErr
}

// Get performs a GET request
func (c *Client) Get(ctx context.Context, path string, result interface{}) error {
	resp, err := c.doRequest(ctx, http.MethodGet, path, nil, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return c.parseError(resp)
	}

	if result != nil && resp.StatusCode != http.StatusNoContent {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return nil
}

// Post performs a POST request
func (c *Client) Post(ctx context.Context, path string, body interface{}, result interface{}, idempotencyKey string) error {
	headers := make(map[string]string)
	if idempotencyKey != "" {
		headers["Idempotency-Key"] = idempotencyKey
	}

	resp, err := c.doRequest(ctx, http.MethodPost, path, body, headers)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return c.parseError(resp)
	}

	if result != nil && resp.StatusCode != http.StatusNoContent {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return nil
}

// Patch performs a PATCH request
func (c *Client) Patch(ctx context.Context, path string, body interface{}, result interface{}) error {
	resp, err := c.doRequest(ctx, http.MethodPatch, path, body, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return c.parseError(resp)
	}

	if result != nil && resp.StatusCode != http.StatusNoContent {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return nil
}

// Put performs a PUT request
func (c *Client) Put(ctx context.Context, path string, body interface{}, result interface{}) error {
	resp, err := c.doRequest(ctx, http.MethodPut, path, body, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return c.parseError(resp)
	}

	if result != nil && resp.StatusCode != http.StatusNoContent {
		if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
			return fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return nil
}

// Delete performs a DELETE request
func (c *Client) Delete(ctx context.Context, path string) error {
	resp, err := c.doRequest(ctx, http.MethodDelete, path, nil, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return c.parseError(resp)
	}

	return nil
}

// PaginateCursor provides cursor-based pagination using a callback function
func (c *Client) PaginateCursor(ctx context.Context, path string, callback func(interface{}) error) error {
	cursor := ""
	hasMore := true

	for hasMore {
		fullPath := path
		if cursor != "" {
			if bytes.Contains([]byte(path), []byte("?")) {
				fullPath = fmt.Sprintf("%s&cursor=%s", path, cursor)
			} else {
				fullPath = fmt.Sprintf("%s?cursor=%s", path, cursor)
			}
		}

		var response CursorPaginatedResponse
		if err := c.Get(ctx, fullPath, &response); err != nil {
			return err
		}

		for _, item := range response.Items {
			if err := callback(item); err != nil {
				return err
			}
		}

		hasMore = response.HasMore
		if response.NextCursor != nil {
			cursor = *response.NextCursor
		} else {
			break
		}
	}

	return nil
}

// GetAllCursor fetches all pages and returns them as a slice
func (c *Client) GetAllCursor(ctx context.Context, path string) ([]interface{}, error) {
	var items []interface{}
	err := c.PaginateCursor(ctx, path, func(item interface{}) error {
		items = append(items, item)
		return nil
	})
	return items, err
}

