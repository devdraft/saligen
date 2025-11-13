use std::collections::HashMap;
use std::error::Error as StdError;
use std::fmt;
use std::time::Duration;
use serde::{Deserialize, Serialize};
use serde_json::Value;

const VERSION: &str = "0.1.0";
const DEFAULT_TIMEOUT_SECS: u64 = 15;
const DEFAULT_MAX_RETRIES: u32 = 3;

/// SDK configuration options
#[derive(Debug, Clone)]
pub struct ClientOptions {
    /// Base URL for the API (required)
    pub base_url: String,
    /// API key for authentication (optional)
    pub api_key: Option<String>,
    /// Bearer token for authentication (optional)
    pub bearer_token: Option<String>,
    /// Request timeout in seconds (default: 15)
    pub timeout_secs: Option<u64>,
    /// Maximum number of retry attempts (default: 3)
    pub max_retries: Option<u32>,
    /// Custom user agent (optional)
    pub user_agent: Option<String>,
    /// Additional custom headers (optional)
    pub custom_headers: Option<HashMap<String, String>>,
    /// Enable debug logging (default: false)
    pub debug: bool,
}

impl ClientOptions {
    pub fn new(base_url: impl Into<String>) -> Self {
        Self {
            base_url: base_url.into(),
            api_key: None,
            bearer_token: None,
            timeout_secs: None,
            max_retries: None,
            user_agent: None,
            custom_headers: None,
            debug: false,
        }
    }

    pub fn with_api_key(mut self, api_key: impl Into<String>) -> Self {
        self.api_key = Some(api_key.into());
        self
    }

    pub fn with_bearer_token(mut self, token: impl Into<String>) -> Self {
        self.bearer_token = Some(token.into());
        self
    }

    pub fn with_timeout(mut self, secs: u64) -> Self {
        self.timeout_secs = Some(secs);
        self
    }

    pub fn with_max_retries(mut self, retries: u32) -> Self {
        self.max_retries = Some(retries);
        self
    }

    pub fn with_debug(mut self, debug: bool) -> Self {
        self.debug = debug;
        self
    }
}

/// API error with structured information
#[derive(Debug, Clone)]
pub struct APIError {
    pub message: String,
    pub status: Option<u16>,
    pub code: Option<String>,
    pub details: Option<Value>,
    pub request_id: Option<String>,
}

impl fmt::Display for APIError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut parts = vec![self.message.clone()];
        
        if let Some(status) = self.status {
            parts.push(format!("(status={})", status));
        }
        if let Some(code) = &self.code {
            parts.push(format!("(code={})", code));
        }
        if let Some(request_id) = &self.request_id {
            parts.push(format!("(request_id={})", request_id));
        }
        
        write!(f, "{}", parts.join(" "))
    }
}

impl StdError for APIError {}

/// Cursor-based paginated response
#[derive(Debug, Deserialize, Serialize)]
pub struct CursorPaginatedResponse<T> {
    pub items: Vec<T>,
    #[serde(rename = "nextCursor")]
    pub next_cursor: Option<String>,
    #[serde(rename = "hasMore")]
    pub has_more: bool,
}

/// Page-based paginated response
#[derive(Debug, Deserialize, Serialize)]
pub struct PagePaginatedResponse<T> {
    pub items: Vec<T>,
    pub page: u32,
    #[serde(rename = "perPage")]
    pub per_page: u32,
    #[serde(rename = "totalPages")]
    pub total_pages: u32,
    #[serde(rename = "totalItems")]
    pub total_items: u32,
}

/// Main SDK client
pub struct Client {
    base_url: String,
    http_client: reqwest::Client,
    max_retries: u32,
    debug: bool,
}

impl Client {
    /// Create a new YourAPI client
    pub fn new(options: ClientOptions) -> Result<Self, Box<dyn StdError>> {
        let timeout = Duration::from_secs(options.timeout_secs.unwrap_or(DEFAULT_TIMEOUT_SECS));
        let max_retries = options.max_retries.unwrap_or(DEFAULT_MAX_RETRIES);
        let user_agent = options.user_agent.unwrap_or_else(|| format!("yourapi-rust-sdk/{}", VERSION));

        // Build default headers
        let mut headers = reqwest::header::HeaderMap::new();
        headers.insert(
            reqwest::header::USER_AGENT,
            reqwest::header::HeaderValue::from_str(&user_agent)?,
        );
        headers.insert(
            "X-SDK-Language",
            reqwest::header::HeaderValue::from_static("rust"),
        );
        headers.insert(
            "X-SDK-Version",
            reqwest::header::HeaderValue::from_str(VERSION)?,
        );

        // Add auth headers
        if let Some(bearer_token) = options.bearer_token {
            headers.insert(
                reqwest::header::AUTHORIZATION,
                reqwest::header::HeaderValue::from_str(&format!("Bearer {}", bearer_token))?,
            );
        } else if let Some(api_key) = options.api_key {
            headers.insert(
                "X-API-Key",
                reqwest::header::HeaderValue::from_str(&api_key)?,
            );
        }

        // Add custom headers
        if let Some(custom) = options.custom_headers {
            for (key, value) in custom {
                headers.insert(
                    reqwest::header::HeaderName::from_bytes(key.as_bytes())?,
                    reqwest::header::HeaderValue::from_str(&value)?,
                );
            }
        }

        let http_client = reqwest::Client::builder()
            .timeout(timeout)
            .default_headers(headers)
            .build()?;

        Ok(Self {
            base_url: options.base_url.trim_end_matches('/').to_string(),
            http_client,
            max_retries,
            debug: options.debug,
        })
    }

    fn log_debug(&self, message: &str) {
        if self.debug {
            eprintln!("[YourAPI] {}", message);
        }
    }

    fn calculate_backoff(&self, attempt: u32, retry_after: Option<u64>) -> Duration {
        if let Some(seconds) = retry_after {
            return Duration::from_secs(seconds);
        }
        
        // Exponential backoff: 2^attempt, capped at 8 seconds
        let backoff_secs = 2u64.pow(attempt).min(8);
        Duration::from_secs(backoff_secs)
    }

    async fn parse_error(&self, response: reqwest::Response) -> APIError {
        let status = response.status().as_u16();
        let request_id = response
            .headers()
            .get("x-request-id")
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string());

        match response.json::<Value>().await {
            Ok(body) => {
                let message = body["message"]
                    .as_str()
                    .unwrap_or("Request failed")
                    .to_string();
                let code = body["code"].as_str().map(|s| s.to_string());
                let details = body.get("details").cloned();
                let req_id = body["requestId"]
                    .as_str()
                    .map(|s| s.to_string())
                    .or(request_id);

                APIError {
                    message,
                    status: Some(status),
                    code,
                    details,
                    request_id: req_id,
                }
            }
            Err(_) => APIError {
                message: format!("Request failed with status {}", status),
                status: Some(status),
                code: None,
                details: None,
                request_id,
            },
        }
    }

    async fn do_request(
        &self,
        method: reqwest::Method,
        path: &str,
        body: Option<Value>,
        headers: Option<HashMap<String, String>>,
    ) -> Result<Option<Value>, APIError> {
        let url = format!("{}{}", self.base_url, path);
        
        for attempt in 0..=self.max_retries {
            self.log_debug(&format!(
                "{} {} (attempt {}/{})",
                method,
                url,
                attempt + 1,
                self.max_retries + 1
            ));

            let mut request = self.http_client.request(method.clone(), &url);

            if let Some(ref body_data) = body {
                request = request.json(body_data);
            }

            if let Some(ref extra_headers) = headers {
                for (key, value) in extra_headers {
                    request = request.header(key, value);
                }
            }

            match request.send().await {
                Ok(response) => {
                    let status = response.status();
                    self.log_debug(&format!("Response: {}", status.as_u16()));

                    // Success
                    if status.is_success() {
                        if status.as_u16() == 204 {
                            return Ok(None);
                        }
                        match response.json::<Value>().await {
                            Ok(data) => return Ok(Some(data)),
                            Err(e) => {
                                return Err(APIError {
                                    message: format!("Failed to parse response: {}", e),
                                    status: Some(status.as_u16()),
                                    code: Some("PARSE_ERROR".to_string()),
                                    details: None,
                                    request_id: None,
                                });
                            }
                        }
                    }

                    // Check for retryable errors
                    let retryable_statuses = vec![429, 500, 502, 503, 504];
                    if retryable_statuses.contains(&status.as_u16()) && attempt < self.max_retries {
                        let retry_after = response
                            .headers()
                            .get("retry-after")
                            .and_then(|v| v.to_str().ok())
                            .and_then(|s| s.parse::<u64>().ok());

                        let backoff = self.calculate_backoff(attempt, retry_after);
                        self.log_debug(&format!("Retrying after {:?}", backoff));
                        tokio::time::sleep(backoff).await;
                        continue;
                    }

                    // Non-retryable error
                    return Err(self.parse_error(response).await);
                }
                Err(e) => {
                    if attempt < self.max_retries {
                        let backoff = self.calculate_backoff(attempt, None);
                        self.log_debug(&format!("Request error, retrying after {:?}: {}", backoff, e));
                        tokio::time::sleep(backoff).await;
                        continue;
                    }
                    return Err(APIError {
                        message: format!("Request failed: {}", e),
                        status: None,
                        code: Some("REQUEST_ERROR".to_string()),
                        details: None,
                        request_id: None,
                    });
                }
            }
        }

        Err(APIError {
            message: "Max retries exceeded".to_string(),
            status: None,
            code: Some("MAX_RETRIES_EXCEEDED".to_string()),
            details: None,
            request_id: None,
        })
    }

    /// Make a GET request
    pub async fn get(&self, path: &str) -> Result<Option<Value>, APIError> {
        self.do_request(reqwest::Method::GET, path, None, None).await
    }

    /// Make a POST request
    pub async fn post(
        &self,
        path: &str,
        data: Value,
        idempotency_key: Option<String>,
    ) -> Result<Option<Value>, APIError> {
        let mut headers = HashMap::new();
        if let Some(key) = idempotency_key {
            headers.insert("Idempotency-Key".to_string(), key);
        }
        
        let headers_opt = if headers.is_empty() { None } else { Some(headers) };
        self.do_request(reqwest::Method::POST, path, Some(data), headers_opt).await
    }

    /// Make a PATCH request
    pub async fn patch(&self, path: &str, data: Value) -> Result<Option<Value>, APIError> {
        self.do_request(reqwest::Method::PATCH, path, Some(data), None).await
    }

    /// Make a PUT request
    pub async fn put(&self, path: &str, data: Value) -> Result<Option<Value>, APIError> {
        self.do_request(reqwest::Method::PUT, path, Some(data), None).await
    }

    /// Make a DELETE request
    pub async fn delete(&self, path: &str) -> Result<Option<Value>, APIError> {
        self.do_request(reqwest::Method::DELETE, path, None, None).await
    }

    /// Paginate through cursor-based API results
    pub async fn paginate_cursor<T: for<'de> Deserialize<'de>>(
        &self,
        path: &str,
    ) -> Result<Vec<T>, APIError> {
        let mut all_items = Vec::new();
        let mut cursor: Option<String> = None;
        let mut has_more = true;

        while has_more {
            let current_path = if let Some(ref c) = cursor {
                if path.contains('?') {
                    format!("{}&cursor={}", path, c)
                } else {
                    format!("{}?cursor={}", path, c)
                }
            } else {
                path.to_string()
            };

            match self.get(&current_path).await? {
                Some(data) => {
                    let response: CursorPaginatedResponse<T> = serde_json::from_value(data)
                        .map_err(|e| APIError {
                            message: format!("Failed to parse paginated response: {}", e),
                            status: None,
                            code: Some("PARSE_ERROR".to_string()),
                            details: None,
                            request_id: None,
                        })?;

                    all_items.extend(response.items);
                    cursor = response.next_cursor;
                    has_more = response.has_more && cursor.is_some();
                }
                None => break,
            }
        }

        Ok(all_items)
    }
}

