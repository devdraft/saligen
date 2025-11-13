import axios, { AxiosError, AxiosInstance } from "axios";

/**
 * SDK configuration options
 */
export interface SDKOptions {
  /** Base URL for the API */
  baseUrl: string;
  /** API key for authentication */
  apiKey?: string;
  /** Bearer token for authentication */
  bearerToken?: string;
  /** Request timeout in milliseconds (default: 15000) */
  timeoutMs?: number;
  /** Maximum number of retry attempts (default: 3) */
  maxRetries?: number;
  /** Custom User-Agent string */
  userAgent?: string;
  /** Additional headers to include in all requests */
  customHeaders?: Record<string, string>;
  /** Enable debug logging (default: false) */
  debug?: boolean;
}

/**
 * Paginated response with cursor-based pagination
 */
export interface CursorPaginatedResponse<T> {
  items: T[];
  nextCursor?: string | null;
  hasMore: boolean;
}

/**
 * Paginated response with page-based pagination
 */
export interface PagePaginatedResponse<T> {
  items: T[];
  page: number;
  perPage: number;
  totalPages: number;
  totalItems: number;
}

/**
 * Normalized error structure
 */
export class APIError extends Error {
  public readonly status?: number;
  public readonly code?: string;
  public readonly details?: any;
  public readonly requestId?: string;

  constructor(
    message: string,
    status?: number,
    code?: string,
    details?: any,
    requestId?: string
  ) {
    super(message);
    this.name = "APIError";
    this.status = status;
    this.code = code;
    this.details = details;
    this.requestId = requestId;

    // Maintains proper stack trace for where our error was thrown (only available on V8)
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, APIError);
    }
  }
}

/**
 * Sleep utility for retry backoff
 */
const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Generate auth headers based on SDK options
 */
function getAuthHeaders(opts: SDKOptions): Record<string, string> {
  const headers: Record<string, string> = {};

  if (opts.bearerToken) {
    headers["Authorization"] = `Bearer ${opts.bearerToken}`;
  } else if (opts.apiKey) {
    headers["X-API-Key"] = opts.apiKey;
  }

  return headers;
}

/**
 * Main SDK client class
 */
export class YourAPIClient {
  private readonly axiosInstance: AxiosInstance;
  private readonly opts: Required<
    Omit<SDKOptions, "apiKey" | "bearerToken" | "customHeaders">
  >;

  constructor(options: SDKOptions) {
    const {
      baseUrl,
      timeoutMs = 15000,
      maxRetries = 3,
      userAgent = "yourapi-typescript-sdk/0.1.0",
      debug = false,
      customHeaders = {},
    } = options;

    this.opts = {
      baseUrl,
      timeoutMs,
      maxRetries,
      userAgent,
      debug,
    };

    // Create axios instance with defaults
    this.axiosInstance = axios.create({
      baseURL: baseUrl,
      timeout: timeoutMs,
      headers: {
        "User-Agent": userAgent,
        "X-SDK-Language": "typescript",
        "X-SDK-Version": "0.1.0",
        ...getAuthHeaders(options),
        ...customHeaders,
      },
    });

    // Add retry interceptor
    this.setupRetryInterceptor();

    // Add logging interceptor if debug is enabled
    if (debug) {
      this.setupDebugInterceptors();
    }
  }

  /**
   * Setup retry interceptor with exponential backoff
   */
  private setupRetryInterceptor(): void {
    this.axiosInstance.interceptors.response.use(
      undefined,
      async (error: AxiosError) => {
        const config: any = error.config || {};
        
        // Initialize retry count
        config.__retryCount = config.__retryCount || 0;

        const status = error.response?.status ?? 0;
        const retryableStatuses = [429, 500, 502, 503, 504];
        const shouldRetry =
          retryableStatuses.includes(status) &&
          config.__retryCount < this.opts.maxRetries;

        if (!shouldRetry) {
          throw error;
        }

        config.__retryCount++;

        // Check for Retry-After header
        const retryAfter = error.response?.headers?.["retry-after"];
        let backoffMs: number;

        if (retryAfter) {
          // Retry-After can be in seconds or a date
          const retryAfterNum = Number(retryAfter);
          if (!isNaN(retryAfterNum)) {
            backoffMs = retryAfterNum * 1000;
          } else {
            // Parse as date
            const retryDate = new Date(retryAfter);
            backoffMs = Math.max(0, retryDate.getTime() - Date.now());
          }
        } else {
          // Exponential backoff: 2^attempt * 1000, capped at 8000ms
          backoffMs = Math.min(1000 * Math.pow(2, config.__retryCount - 1), 8000);
        }

        if (this.opts.debug) {
          console.log(
            `[YourAPI] Retrying request (attempt ${config.__retryCount}/${this.opts.maxRetries}) after ${backoffMs}ms`
          );
        }

        await sleep(backoffMs);
        return this.axiosInstance(config);
      }
    );
  }

  /**
   * Setup debug logging interceptors
   */
  private setupDebugInterceptors(): void {
    this.axiosInstance.interceptors.request.use((config) => {
      console.log(`[YourAPI] Request: ${config.method?.toUpperCase()} ${config.url}`);
      return config;
    });

    this.axiosInstance.interceptors.response.use(
      (response) => {
        console.log(
          `[YourAPI] Response: ${response.status} ${response.config.url}`
        );
        return response;
      },
      (error) => {
        console.error(
          `[YourAPI] Error: ${error.response?.status || "NO_STATUS"} ${
            error.config?.url || "NO_URL"
          }`
        );
        return Promise.reject(error);
      }
    );
  }

  /**
   * Normalize axios errors into APIError
   */
  private normalizeError(error: any): APIError {
    if (error.response) {
      // Server responded with error
      const status = error.response.status;
      const data = error.response.data;
      const message = data?.message || error.message || "Request failed";
      const code = data?.code;
      const details = data?.details;
      const requestId = data?.requestId || error.response.headers?.["x-request-id"];

      return new APIError(message, status, code, details, requestId);
    } else if (error.request) {
      // Request made but no response
      return new APIError(
        "No response received from server",
        undefined,
        "NO_RESPONSE"
      );
    } else {
      // Error setting up request
      return new APIError(error.message || "Request failed", undefined, "REQUEST_ERROR");
    }
  }

  /**
   * Make a GET request
   */
  async get<T>(path: string, params?: Record<string, any>): Promise<T> {
    try {
      const response = await this.axiosInstance.get<T>(path, { params });
      return response.data;
    } catch (error) {
      throw this.normalizeError(error);
    }
  }

  /**
   * Make a POST request
   */
  async post<T>(
    path: string,
    data?: any,
    idempotencyKey?: string
  ): Promise<T> {
    try {
      const headers: Record<string, string> = {};
      if (idempotencyKey) {
        headers["Idempotency-Key"] = idempotencyKey;
      }

      const response = await this.axiosInstance.post<T>(path, data, { headers });
      return response.data;
    } catch (error) {
      throw this.normalizeError(error);
    }
  }

  /**
   * Make a PATCH request
   */
  async patch<T>(path: string, data?: any): Promise<T> {
    try {
      const response = await this.axiosInstance.patch<T>(path, data);
      return response.data;
    } catch (error) {
      throw this.normalizeError(error);
    }
  }

  /**
   * Make a PUT request
   */
  async put<T>(path: string, data?: any): Promise<T> {
    try {
      const response = await this.axiosInstance.put<T>(path, data);
      return response.data;
    } catch (error) {
      throw this.normalizeError(error);
    }
  }

  /**
   * Make a DELETE request
   */
  async delete<T = void>(path: string): Promise<T> {
    try {
      const response = await this.axiosInstance.delete<T>(path);
      return response.data;
    } catch (error) {
      throw this.normalizeError(error);
    }
  }

  /**
   * Async generator for cursor-based pagination
   * 
   * @example
   * ```typescript
   * const client = new YourAPIClient({ baseUrl: 'https://api.example.com' });
   * 
   * for await (const customer of client.paginateCursor('/customers')) {
   *   console.log(customer);
   * }
   * ```
   */
  async *paginateCursor<T>(
    path: string,
    params?: Record<string, any>,
    cursorParam: string = "cursor",
    itemsKey: string = "items",
    nextCursorKey: string = "nextCursor",
    hasMoreKey: string = "hasMore"
  ): AsyncGenerator<T, void, undefined> {
    let cursor: string | undefined;
    let hasMore = true;

    while (hasMore) {
      const queryParams = { ...params };
      if (cursor) {
        queryParams[cursorParam] = cursor;
      }

      const response = await this.get<any>(path, queryParams);
      const items = response[itemsKey] || [];

      for (const item of items) {
        yield item as T;
      }

      cursor = response[nextCursorKey];
      hasMore = response[hasMoreKey] ?? false;

      if (!cursor || !hasMore) {
        break;
      }
    }
  }

  /**
   * Async generator for page-based pagination
   * 
   * @example
   * ```typescript
   * const client = new YourAPIClient({ baseUrl: 'https://api.example.com' });
   * 
   * for await (const product of client.paginatePage('/products')) {
   *   console.log(product);
   * }
   * ```
   */
  async *paginatePage<T>(
    path: string,
    params?: Record<string, any>,
    pageParam: string = "page",
    perPageParam: string = "perPage",
    itemsKey: string = "items",
    totalPagesKey: string = "totalPages"
  ): AsyncGenerator<T, void, undefined> {
    let page = 1;
    let totalPages = 1;

    while (page <= totalPages) {
      const queryParams = {
        ...params,
        [pageParam]: page,
      };

      if (params?.[perPageParam]) {
        queryParams[perPageParam] = params[perPageParam];
      }

      const response = await this.get<any>(path, queryParams);
      const items = response[itemsKey] || [];

      for (const item of items) {
        yield item as T;
      }

      totalPages = response[totalPagesKey] || page;
      page++;
    }
  }

  /**
   * Fetch all pages and return as array (cursor-based)
   */
  async getAllCursor<T>(
    path: string,
    params?: Record<string, any>
  ): Promise<T[]> {
    const items: T[] = [];
    for await (const item of this.paginateCursor<T>(path, params)) {
      items.push(item);
    }
    return items;
  }

  /**
   * Fetch all pages and return as array (page-based)
   */
  async getAllPage<T>(
    path: string,
    params?: Record<string, any>
  ): Promise<T[]> {
    const items: T[] = [];
    for await (const item of this.paginatePage<T>(path, params)) {
      items.push(item);
    }
    return items;
  }

  /**
   * Get the underlying Axios instance for advanced usage
   */
  getAxiosInstance(): AxiosInstance {
    return this.axiosInstance;
  }
}

// Re-export types for convenience
export type { AxiosInstance };

