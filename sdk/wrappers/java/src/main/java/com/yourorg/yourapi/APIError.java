package com.yourorg.yourapi;

/**
 * Normalized API error with structured information
 */
public class APIError extends Exception {
    private final String message;
    private final Integer status;
    private final String code;
    private final Object details;
    private final String requestId;
    
    public APIError(String message, Integer status, String code, Object details, String requestId) {
        super(buildMessage(message, status, code, requestId));
        this.message = message;
        this.status = status;
        this.code = code;
        this.details = details;
        this.requestId = requestId;
    }
    
    private static String buildMessage(String message, Integer status, String code, String requestId) {
        StringBuilder sb = new StringBuilder(message);
        if (status != null) {
            sb.append(" (status=").append(status).append(")");
        }
        if (code != null) {
            sb.append(" (code=").append(code).append(")");
        }
        if (requestId != null) {
            sb.append(" (request_id=").append(requestId).append(")");
        }
        return sb.toString();
    }
    
    @Override
    public String getMessage() {
        return message;
    }
    
    public Integer getStatus() {
        return status;
    }
    
    public String getCode() {
        return code;
    }
    
    public Object getDetails() {
        return details;
    }
    
    public String getRequestId() {
        return requestId;
    }
}

