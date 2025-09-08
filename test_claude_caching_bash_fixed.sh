#!/bin/bash

# Test Claude Prompt Caching - Fixed Version
# Uses first tenth of Pride and Prejudice and parses JSON response body for cache data

if [ -z "$CLAUDE_API_KEY" ]; then
    echo "❌ Error: CLAUDE_API_KEY environment variable is not set"
    echo "Please set it with: export CLAUDE_API_KEY='your-api-key-here'"
    exit 1
fi

# Check for jq (required for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required for JSON parsing but not installed"
    echo "Please install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

echo "🔍 Testing Claude Prompt Caching with JSON Response Parsing..."
echo "=============================================================="

# Fetch Pride and Prejudice from Project Gutenberg
echo "📚 Fetching Pride and Prejudice from Project Gutenberg..."
BOOK_URL="https://www.gutenberg.org/cache/epub/1342/pg1342.txt"
BOOK_CONTENT=$(curl -s "$BOOK_URL")

if [ -z "$BOOK_CONTENT" ]; then
    echo "❌ Failed to fetch book content"
    exit 1
fi

# Use only the first tenth of the book
BOOK_LENGTH=${#BOOK_CONTENT}
TENTH_LENGTH=$((BOOK_LENGTH / 10))
BOOK_TENTH="${BOOK_CONTENT:0:$TENTH_LENGTH}"

# Escape the book content for JSON (replace newlines and quotes)
BOOK_TENTH_ESCAPED=$(echo "$BOOK_TENTH" | jq -Rs .)

echo "📏 Book stats:"
echo "   Total characters: $(echo "$BOOK_CONTENT" | wc -c)"
echo "   Using first tenth: $(echo "$BOOK_TENTH" | wc -c) characters"
echo "   Estimated tokens: ~$((${#BOOK_TENTH} / 3))"

# Function to analyze JSON response for cache data
analyze_cache_response() {
    local response="$1"
    local request_num="$2"
    
    echo ""
    echo "📊 Request #$request_num Analysis:"
    echo "================================="
    
    # Check if response is valid JSON
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo "❌ Invalid JSON response"
        echo "Raw response:"
        echo "$response"
        return 1
    fi
    
    # Extract usage information
    echo "🔍 Usage Information:"
    echo "$response" | jq -r '.usage' | while IFS= read -r line; do
        echo "   $line"
    done
    
    # Extract cache-specific metrics
    cache_read=$(echo "$response" | jq -r '.usage.cache_read_input_tokens // 0')
    cache_creation=$(echo "$response" | jq -r '.usage.cache_creation_input_tokens // 0')
    input_tokens=$(echo "$response" | jq -r '.usage.input_tokens // 0')
    output_tokens=$(echo "$response" | jq -r '.usage.output_tokens // 0')
    
    echo ""
    echo "💾 Cache Performance:"
    if [ "$cache_creation" != "0" ]; then
        echo "   🆕 Cache created: $cache_creation tokens"
    fi
    
    if [ "$cache_read" != "0" ]; then
        echo "   ⚡ Cache hit: $cache_read tokens read from cache"
        if [ "$cache_creation" != "0" ] && [ "$cache_read" -lt "$cache_creation" ]; then
            savings=$((cache_creation - cache_read))
            percent=$(( (savings * 100) / cache_creation ))
            echo "   💰 Token savings: $savings tokens ($percent%)"
        fi
    fi
    
    if [ "$input_tokens" != "0" ] && [ "$output_tokens" != "0" ]; then
        total=$((input_tokens + output_tokens))
        echo "   🎯 Total usage: $input_tokens input + $output_tokens output = $total tokens"
    fi
    
    if [ "$cache_creation" = "0" ] && [ "$cache_read" = "0" ]; then
        echo "   ❌ No cache activity detected"
    fi
    
    # Show full response for debugging
    echo ""
    echo "📄 Full JSON Response:"
    echo "$response" | jq .
}

# Test 1: First request (should create cache)
echo ""
echo "📤 Making first request (should create cache)..."
echo "================================================"

start_time=$(date +%s)

# Build JSON payload using jq to properly escape the book content
REQUEST_PAYLOAD=$(jq -n \
  --arg model "claude-sonnet-4-20250514" \
  --arg book_content "Here is the first tenth of Pride and Prejudice by Jane Austen:\n\n$BOOK_TENTH" \
  --arg user_message "What are the main themes in this novel? Give me 3 key themes." \
  '{
    "model": $model,
    "max_tokens": 1024,
    "system": [
      {
        "type": "text",
        "text": "You are a literary analysis AI assistant."
      },
      {
        "type": "text",
        "text": $book_content,
        "cache_control": {"type": "ephemeral", "ttl": "1h"}
      }
    ],
    "messages": [
      {
        "role": "user",
        "content": $user_message
      }
    ]
  }')

RESPONSE1=$(curl -s https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: prompt-caching-2024-07-31" \
  -d "$REQUEST_PAYLOAD")

end_time=$(date +%s)
duration1=$((end_time - start_time))

echo "✅ First request completed in ${duration1}s"

analyze_cache_response "$RESPONSE1" 1
FIRST_SUCCESS=$?

# Wait before second request
echo ""
echo "⏱️  Waiting 3 seconds before second request..."
sleep 3

# Test 2: Second request (should hit cache)
echo ""
echo "📤 Making second request (should hit cache)..."
echo "=============================================="

start_time=$(date +%s)

# Build second JSON payload
REQUEST_PAYLOAD2=$(jq -n \
  --arg model "claude-sonnet-4-20250514" \
  --arg book_content "Here is the first tenth of Pride and Prejudice by Jane Austen:\n\n$BOOK_TENTH" \
  --arg user_message "Who are the main characters and what are their relationships?" \
  '{
    "model": $model,
    "max_tokens": 1024,
    "system": [
      {
        "type": "text",
        "text": "You are a literary analysis AI assistant."
      },
      {
        "type": "text",
        "text": $book_content,
        "cache_control": {"type": "ephemeral", "ttl": "1h"}
      }
    ],
    "messages": [
      {
        "role": "user",
        "content": $user_message
      }
    ]
  }')

RESPONSE2=$(curl -s https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: prompt-caching-2024-07-31" \
  -d "$REQUEST_PAYLOAD2")

end_time=$(date +%s)
duration2=$((end_time - start_time))

echo "✅ Second request completed in ${duration2}s"

analyze_cache_response "$RESPONSE2" 2
SECOND_SUCCESS=$?

# Final analysis
echo ""
echo "🎯 Final Analysis:"
echo "=================="
echo "Request 1 duration: ${duration1}s"
echo "Request 2 duration: ${duration2}s"

if [ $duration2 -lt $((duration1 * 80 / 100)) ]; then
    echo "⚡ Request 2 was significantly faster - possible cache hit!"
fi

if [ $FIRST_SUCCESS -eq 0 ] && [ $SECOND_SUCCESS -eq 0 ]; then
    echo "✅ Both requests completed successfully"
    
    # Check for cache activity in responses
    cache1=$(echo "$RESPONSE1" | jq -r '.usage.cache_creation_input_tokens // 0')
    cache2=$(echo "$RESPONSE2" | jq -r '.usage.cache_read_input_tokens // 0')
    
    if [ "$cache1" != "0" ] || [ "$cache2" != "0" ]; then
        echo "✅ Cache activity detected - prompt caching is working!"
    else
        echo "❌ No cache activity detected"
        echo "   → Prompt caching may not be available for your account/region"
    fi
else
    echo "❌ Some requests failed - check error messages above"
fi

echo ""
echo "🏁 Testing complete!"