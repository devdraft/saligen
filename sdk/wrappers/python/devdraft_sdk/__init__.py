"""
DevDraft Python SDK

Production-ready Python SDK with support for:
- Authentication (API Key & Bearer Token)
- Automatic retries with exponential backoff
- Configurable timeouts
- Pagination helpers
- Normalized error handling
- Telemetry headers
"""

import time
import urllib3
from typing import Any, Dict, Generator, List, Optional, Union
from dataclasses import dataclass
from datetime import datetime
import json


__version__ = "0.1.0"


@dataclass
class SDKOptions:
    """SDK configuration options."""
    
    base_url: str
    api_key: Optional[str] = None
    bearer_token: Optional[str] = None
    timeout_seconds: int = 15
    max_retries: int = 3
    user_agent: str = f"devdraft-python-sdk/{__version__}"
    custom_headers: Optional[Dict[str, str]] = None
    debug: bool = False


class APIError(Exception):
    """Normalized API error with structured information."""
    
    def __init__(
        self,
        message: str,
        status: Optional[int] = None,
        code: Optional[str] = None,
        details: Optional[Any] = None,
        request_id: Optional[str] = None,
    ):
        super().__init__(message)
        self.message = message
        self.status = status
        self.code = code
        self.details = details
        self.request_id = request_id
    
    def __str__(self) -> str:
        parts = [self.message]
        if self.status:
            parts.append(f"(status={self.status})")
        if self.code:
            parts.append(f"(code={self.code})")
        if self.request_id:
            parts.append(f"(request_id={self.request_id})")
        return " ".join(parts)
    
    def __repr__(self) -> str:
        return (
            f"APIError(message={self.message!r}, status={self.status}, "
            f"code={self.code!r}, request_id={self.request_id!r})"
        )


class DevDraftClient:
    """Main SDK client for DevDraft API."""
    
    def __init__(self, options: Union[SDKOptions, Dict[str, Any]]):
        """
        Initialize the DevDraft API client.
        
        Args:
            options: SDK configuration options
            
        Example:
            >>> client = DevDraftClient({
            ...     'base_url': 'https://api.devdraft.ai/v1',
            ...     'api_key': 'your-api-key'
            ... })
        """
        if isinstance(options, dict):
            options = SDKOptions(**options)
        
        self.options = options
        self.http = urllib3.PoolManager(
            timeout=urllib3.Timeout(
                connect=options.timeout_seconds,
                read=options.timeout_seconds
            ),
            retries=False  # We handle retries manually
        )
        
        # Build default headers
        self.default_headers = {
            "User-Agent": options.user_agent,
            "X-SDK-Language": "python",
            "X-SDK-Version": __version__,
            "Content-Type": "application/json",
        }
        
        # Add auth headers
        if options.bearer_token:
            self.default_headers["Authorization"] = f"Bearer {options.bearer_token}"
        elif options.api_key:
            self.default_headers["X-API-Key"] = options.api_key
        
        # Add custom headers
        if options.custom_headers:
            self.default_headers.update(options.custom_headers)
    
    def _log(self, message: str) -> None:
        """Log debug message if debug is enabled."""
        if self.options.debug:
            timestamp = datetime.now().isoformat()
            print(f"[{timestamp}] [DevDraft] {message}")
    
    def _build_url(self, path: str) -> str:
        """Build full URL from path."""
        base = self.options.base_url.rstrip("/")
        path = path.lstrip("/")
        return f"{base}/{path}"
    
    def _parse_response(self, response: urllib3.HTTPResponse) -> Any:
        """Parse response body as JSON."""
        try:
            return json.loads(response.data.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return None
    
    def _make_request(
        self,
        method: str,
        path: str,
        params: Optional[Dict[str, Any]] = None,
        data: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
    ) -> Any:
        """
        Make HTTP request with retry logic.
        
        Args:
            method: HTTP method (GET, POST, etc.)
            path: API path
            params: Query parameters
            data: Request body data
            headers: Additional headers
            
        Returns:
            Parsed response data
            
        Raises:
            APIError: On request failure
        """
        url = self._build_url(path)
        request_headers = {**self.default_headers}
        if headers:
            request_headers.update(headers)
        
        # Encode request body
        body = None
        if data is not None:
            body = json.dumps(data).encode("utf-8")
        
        # Retry loop
        for attempt in range(self.options.max_retries + 1):
            try:
                self._log(f"{method} {url} (attempt {attempt + 1}/{self.options.max_retries + 1})")
                
                response = self.http.request(
                    method,
                    url,
                    fields=params,
                    body=body,
                    headers=request_headers,
                    preload_content=True,
                )
                
                self._log(f"Response: {response.status}")
                
                # Handle successful responses
                if 200 <= response.status < 300:
                    if response.status == 204:
                        return None
                    return self._parse_response(response)
                
                # Handle retryable errors
                retryable_statuses = {429, 500, 502, 503, 504}
                if response.status in retryable_statuses and attempt < self.options.max_retries:
                    # Calculate backoff
                    retry_after = response.headers.get("Retry-After")
                    if retry_after:
                        try:
                            backoff = int(retry_after)
                        except ValueError:
                            # Parse as date
                            retry_date = datetime.fromisoformat(retry_after.replace("Z", "+00:00"))
                            backoff = max(0, int((retry_date - datetime.now()).total_seconds()))
                    else:
                        # Exponential backoff: 2^attempt, capped at 8 seconds
                        backoff = min(2 ** attempt, 8)
                    
                    self._log(f"Retrying after {backoff}s")
                    time.sleep(backoff)
                    continue
                
                # Handle error responses
                error_data = self._parse_response(response)
                raise self._create_error(response.status, error_data)
                
            except urllib3.exceptions.HTTPError as e:
                if attempt < self.options.max_retries:
                    backoff = min(2 ** attempt, 8)
                    self._log(f"HTTP error, retrying after {backoff}s: {e}")
                    time.sleep(backoff)
                    continue
                raise APIError(f"HTTP error: {str(e)}", code="HTTP_ERROR")
            except Exception as e:
                if attempt < self.options.max_retries:
                    backoff = min(2 ** attempt, 8)
                    self._log(f"Unexpected error, retrying after {backoff}s: {e}")
                    time.sleep(backoff)
                    continue
                raise APIError(f"Unexpected error: {str(e)}", code="UNEXPECTED_ERROR")
        
        # Should not reach here, but just in case
        raise APIError("Max retries exceeded", code="MAX_RETRIES_EXCEEDED")
    
    def _create_error(self, status: int, data: Optional[Dict[str, Any]]) -> APIError:
        """Create APIError from response data."""
        if data:
            message = data.get("message", "Request failed")
            code = data.get("code")
            details = data.get("details")
            request_id = data.get("requestId")
        else:
            message = f"Request failed with status {status}"
            code = None
            details = None
            request_id = None
        
        return APIError(
            message=message,
            status=status,
            code=code,
            details=details,
            request_id=request_id,
        )
    
    def get(
        self,
        path: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> Any:
        """
        Make a GET request.
        
        Args:
            path: API path
            params: Query parameters
            
        Returns:
            Response data
        """
        return self._make_request("GET", path, params=params)
    
    def post(
        self,
        path: str,
        data: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None,
    ) -> Any:
        """
        Make a POST request.
        
        Args:
            path: API path
            data: Request body
            idempotency_key: Idempotency key for safe retries
            
        Returns:
            Response data
        """
        headers = {}
        if idempotency_key:
            headers["Idempotency-Key"] = idempotency_key
        
        return self._make_request("POST", path, data=data, headers=headers)
    
    def patch(
        self,
        path: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> Any:
        """
        Make a PATCH request.
        
        Args:
            path: API path
            data: Request body
            
        Returns:
            Response data
        """
        return self._make_request("PATCH", path, data=data)
    
    def put(
        self,
        path: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> Any:
        """
        Make a PUT request.
        
        Args:
            path: API path
            data: Request body
            
        Returns:
            Response data
        """
        return self._make_request("PUT", path, data=data)
    
    def delete(self, path: str) -> Any:
        """
        Make a DELETE request.
        
        Args:
            path: API path
            
        Returns:
            Response data (usually None for 204)
        """
        return self._make_request("DELETE", path)
    
    def paginate_cursor(
        self,
        path: str,
        params: Optional[Dict[str, Any]] = None,
        cursor_param: str = "cursor",
        items_key: str = "items",
        next_cursor_key: str = "nextCursor",
        has_more_key: str = "hasMore",
    ) -> Generator[Any, None, None]:
        """
        Paginate through cursor-based API results.
        
        Args:
            path: API path
            params: Query parameters
            cursor_param: Name of cursor query parameter
            items_key: Name of items array in response
            next_cursor_key: Name of next cursor field in response
            has_more_key: Name of hasMore boolean field in response
            
        Yields:
            Individual items from paginated results
            
        Example:
            >>> client = DevDraftClient({'base_url': 'https://api.example.com'})
            >>> for customer in client.paginate_cursor('/customers'):
            ...     print(customer['email'])
        """
        cursor = None
        has_more = True
        query_params = dict(params or {})
        
        while has_more:
            if cursor:
                query_params[cursor_param] = cursor
            
            response = self.get(path, query_params)
            items = response.get(items_key, [])
            
            for item in items:
                yield item
            
            cursor = response.get(next_cursor_key)
            has_more = response.get(has_more_key, False)
            
            if not cursor or not has_more:
                break
    
    def paginate_page(
        self,
        path: str,
        params: Optional[Dict[str, Any]] = None,
        page_param: str = "page",
        per_page_param: str = "perPage",
        items_key: str = "items",
        total_pages_key: str = "totalPages",
    ) -> Generator[Any, None, None]:
        """
        Paginate through page-based API results.
        
        Args:
            path: API path
            params: Query parameters
            page_param: Name of page query parameter
            per_page_param: Name of per-page query parameter
            items_key: Name of items array in response
            total_pages_key: Name of total pages field in response
            
        Yields:
            Individual items from paginated results
            
        Example:
            >>> client = DevDraftClient({'base_url': 'https://api.example.com'})
            >>> for product in client.paginate_page('/products', {'perPage': 50}):
            ...     print(product['name'])
        """
        page = 1
        total_pages = 1
        query_params = dict(params or {})
        
        while page <= total_pages:
            query_params[page_param] = page
            
            response = self.get(path, query_params)
            items = response.get(items_key, [])
            
            for item in items:
                yield item
            
            total_pages = response.get(total_pages_key, page)
            page += 1
    
    def get_all_cursor(
        self,
        path: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> List[Any]:
        """
        Fetch all pages and return as list (cursor-based).
        
        Args:
            path: API path
            params: Query parameters
            
        Returns:
            List of all items
        """
        return list(self.paginate_cursor(path, params))
    
    def get_all_page(
        self,
        path: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> List[Any]:
        """
        Fetch all pages and return as list (page-based).
        
        Args:
            path: API path
            params: Query parameters
            
        Returns:
            List of all items
        """
        return list(self.paginate_page(path, params))


# Convenience exports
__all__ = [
    "DevDraftClient",
    "SDKOptions",
    "APIError",
    "__version__",
]

