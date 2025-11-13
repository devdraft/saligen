package com.yourorg.yourapi;

import java.util.List;

/**
 * Cursor-based paginated response
 */
public class CursorPaginatedResponse<T> {
    private List<T> items;
    private String nextCursor;
    private boolean hasMore;
    
    public CursorPaginatedResponse() {
    }
    
    public CursorPaginatedResponse(List<T> items, String nextCursor, boolean hasMore) {
        this.items = items;
        this.nextCursor = nextCursor;
        this.hasMore = hasMore;
    }
    
    public List<T> getItems() {
        return items;
    }
    
    public void setItems(List<T> items) {
        this.items = items;
    }
    
    public String getNextCursor() {
        return nextCursor;
    }
    
    public void setNextCursor(String nextCursor) {
        this.nextCursor = nextCursor;
    }
    
    public boolean isHasMore() {
        return hasMore;
    }
    
    public void setHasMore(boolean hasMore) {
        this.hasMore = hasMore;
    }
}

