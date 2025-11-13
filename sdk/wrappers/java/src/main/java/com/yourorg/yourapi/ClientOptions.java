package com.yourorg.yourapi;

import java.util.HashMap;
import java.util.Map;

/**
 * Configuration options for the YourAPI client
 */
public class ClientOptions {
    private final String baseUrl;
    private final String apiKey;
    private final String bearerToken;
    private final int timeoutSeconds;
    private final int maxRetries;
    private final String userAgent;
    private final Map<String, String> customHeaders;
    private final boolean debug;
    
    private ClientOptions(Builder builder) {
        this.baseUrl = builder.baseUrl;
        this.apiKey = builder.apiKey;
        this.bearerToken = builder.bearerToken;
        this.timeoutSeconds = builder.timeoutSeconds;
        this.maxRetries = builder.maxRetries;
        this.userAgent = builder.userAgent;
        this.customHeaders = builder.customHeaders;
        this.debug = builder.debug;
    }
    
    public String getBaseUrl() {
        return baseUrl;
    }
    
    public String getApiKey() {
        return apiKey;
    }
    
    public String getBearerToken() {
        return bearerToken;
    }
    
    public int getTimeoutSeconds() {
        return timeoutSeconds;
    }
    
    public int getMaxRetries() {
        return maxRetries;
    }
    
    public String getUserAgent() {
        return userAgent;
    }
    
    public Map<String, String> getCustomHeaders() {
        return customHeaders;
    }
    
    public boolean isDebug() {
        return debug;
    }
    
    /**
     * Builder for ClientOptions
     */
    public static class Builder {
        private final String baseUrl;
        private String apiKey;
        private String bearerToken;
        private int timeoutSeconds = 15;
        private int maxRetries = 3;
        private String userAgent = "yourapi-java-sdk/0.1.0";
        private Map<String, String> customHeaders = new HashMap<>();
        private boolean debug = false;
        
        public Builder(String baseUrl) {
            if (baseUrl == null || baseUrl.isEmpty()) {
                throw new IllegalArgumentException("baseUrl is required");
            }
            this.baseUrl = baseUrl;
        }
        
        public Builder apiKey(String apiKey) {
            this.apiKey = apiKey;
            return this;
        }
        
        public Builder bearerToken(String bearerToken) {
            this.bearerToken = bearerToken;
            return this;
        }
        
        public Builder timeoutSeconds(int timeoutSeconds) {
            this.timeoutSeconds = timeoutSeconds;
            return this;
        }
        
        public Builder maxRetries(int maxRetries) {
            this.maxRetries = maxRetries;
            return this;
        }
        
        public Builder userAgent(String userAgent) {
            this.userAgent = userAgent;
            return this;
        }
        
        public Builder addCustomHeader(String key, String value) {
            this.customHeaders.put(key, value);
            return this;
        }
        
        public Builder customHeaders(Map<String, String> customHeaders) {
            this.customHeaders = new HashMap<>(customHeaders);
            return this;
        }
        
        public Builder debug(boolean debug) {
            this.debug = debug;
            return this;
        }
        
        public ClientOptions build() {
            return new ClientOptions(this);
        }
    }
}

