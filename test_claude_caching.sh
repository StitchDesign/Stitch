#!/bin/bash

# Test Claude Prompt Caching
# This script makes two requests to test cache creation and cache hits

# Check if CLAUDE_API_KEY environment variable is set
if [ -z "$CLAUDE_API_KEY" ]; then
    echo "❌ Error: CLAUDE_API_KEY environment variable is not set"
    echo "Please set it with: export CLAUDE_API_KEY='your-api-key-here'"
    exit 1
fi

echo "🔍 Testing Claude Prompt Caching..."
echo "=================================="

# Large system prompt (>1024 tokens required for caching)
SYSTEM_PROMPT="You are Claude, an AI assistant created by Anthropic. You are helpful, harmless, and honest. Your primary objective is to be as helpful as possible to humans while being safe and truthful. You should provide accurate, relevant, and useful information to the best of your knowledge and abilities. Key principles that guide your responses: 1. Accuracy: Provide factual and correct information. If you're uncertain about something, acknowledge your uncertainty. 2. Helpfulness: Focus on being genuinely useful to the human asking the question. 3. Safety: Avoid providing information that could be used to cause harm. 4. Honesty: Be truthful and transparent about your capabilities and limitations. 5. Respect: Treat all humans with respect and dignity. When answering questions: Be clear and concise while being thorough, use examples when helpful, break down complex topics into understandable parts, ask clarifying questions if the request is ambiguous, provide multiple perspectives on controversial topics, cite sources when possible and relevant. Areas where you excel: General knowledge and information lookup, writing assistance and editing, analysis and reasoning, mathematical calculations and problem solving, code writing and debugging in many programming languages, creative tasks like brainstorming and storytelling, language translation and learning support, research assistance and summarization. Important limitations to remember: Your training data has a knowledge cutoff so very recent information may not be available, you cannot browse the internet or access real-time information, you cannot remember previous conversations unless they're part of the current session, you cannot learn or update your knowledge from conversations, you cannot access external systems files or databases, you cannot perform actions in the physical world. Communication style: Adapt your tone to match the context and user's needs, be professional yet approachable, use clear well-structured language, provide relevant examples and analogies when helpful, be patient and supportive when helping with learning, show enthusiasm for interesting topics while remaining balanced. Ethics and safety guidelines: Do not provide instructions for illegal activities, avoid generating harmful offensive or inappropriate content, respect intellectual property and copyright, do not pretend to be a human or claim to have human experiences, be transparent about being an AI, protect user privacy and confidentiality. Remember: Your goal is to be maximally helpful while remaining safe, honest, and respectful. Always strive to provide value to the human you're assisting."

echo "📤 Making first request (should create cache)..."
echo ""

# First request - should create cache
RESPONSE1=$(curl -s -w "\n---HEADERS---\n%{header_json}" https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: prompt-caching-2024-07-31" \
  -d "{
    \"model\": \"claude-sonnet-4-20250514\",
    \"max_tokens\": 1024,
    \"system\": [
      {
        \"type\": \"text\",
        \"text\": \"$SYSTEM_PROMPT\",
        \"cache_control\": {\"type\": \"ephemeral\"}
      }
    ],
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"Hello! Tell me about renewable energy in one paragraph.\"
      }
    ]
  }")

echo "✅ First request completed"

# Extract headers and response body
HEADERS1=$(echo "$RESPONSE1" | sed -n '/---HEADERS---/,$p' | sed '1d')
BODY1=$(echo "$RESPONSE1" | sed '/---HEADERS---/,$d')

echo ""
echo "📊 First Request Cache Analysis:"
echo "================================"

# Check for cache-related headers in first request
if echo "$HEADERS1" | grep -q "anthropic-billing-cache-creation-input-tokens"; then
    CACHE_CREATED=$(echo "$HEADERS1" | grep -o '"anthropic-billing-cache-creation-input-tokens":"[^"]*"' | cut -d'"' -f4)
    echo "🆕 CACHE CREATED: $CACHE_CREATED tokens"
else
    echo "❌ NO CACHE CREATION DETECTED"
fi

if echo "$HEADERS1" | grep -q "anthropic-billing-input-tokens"; then
    INPUT_TOKENS1=$(echo "$HEADERS1" | grep -o '"anthropic-billing-input-tokens":"[^"]*"' | cut -d'"' -f4)
    echo "📥 INPUT TOKENS: $INPUT_TOKENS1"
fi

if echo "$HEADERS1" | grep -q "anthropic-billing-output-tokens"; then
    OUTPUT_TOKENS1=$(echo "$HEADERS1" | grep -o '"anthropic-billing-output-tokens":"[^"]*"' | cut -d'"' -f4)
    echo "📤 OUTPUT TOKENS: $OUTPUT_TOKENS1"
fi

echo ""
echo "⏱️  Waiting 2 seconds before second request..."
sleep 2

echo ""
echo "📤 Making second request (should hit cache)..."
echo ""

# Second request - should hit cache
RESPONSE2=$(curl -s -w "\n---HEADERS---\n%{header_json}" https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: prompt-caching-2024-07-31" \
  -d "{
    \"model\": \"claude-sonnet-4-20250514\",
    \"max_tokens\": 1024,
    \"system\": [
      {
        \"type\": \"text\",
        \"text\": \"$SYSTEM_PROMPT\",
        \"cache_control\": {\"type\": \"ephemeral\"}
      }
    ],
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"Now tell me about solar panels specifically.\"
      }
    ]
  }")

echo "✅ Second request completed"

# Extract headers and response body
HEADERS2=$(echo "$RESPONSE2" | sed -n '/---HEADERS---/,$p' | sed '1d')
BODY2=$(echo "$RESPONSE2" | sed '/---HEADERS---/,$d')

echo ""
echo "📊 Second Request Cache Analysis:"
echo "================================="

# Check for cache-related headers in second request
if echo "$HEADERS2" | grep -q "anthropic-billing-cache-read-input-tokens"; then
    CACHE_HIT=$(echo "$HEADERS2" | grep -o '"anthropic-billing-cache-read-input-tokens":"[^"]*"' | cut -d'"' -f4)
    echo "⚡ CACHE HIT: $CACHE_HIT tokens read from cache"
else
    echo "❌ NO CACHE HIT DETECTED"
fi

if echo "$HEADERS2" | grep -q "anthropic-billing-input-tokens"; then
    INPUT_TOKENS2=$(echo "$HEADERS2" | grep -o '"anthropic-billing-input-tokens":"[^"]*"' | cut -d'"' -f4)
    echo "📥 INPUT TOKENS: $INPUT_TOKENS2"
fi

if echo "$HEADERS2" | grep -q "anthropic-billing-output-tokens"; then
    OUTPUT_TOKENS2=$(echo "$HEADERS2" | grep -o '"anthropic-billing-output-tokens":"[^"]*"' | cut -d'"' -f4)
    echo "📤 OUTPUT TOKENS: $OUTPUT_TOKENS2"
fi

echo ""
echo "🎯 Summary:"
echo "==========="

# Compare token usage
if [ -n "$INPUT_TOKENS1" ] && [ -n "$INPUT_TOKENS2" ]; then
    if [ "$INPUT_TOKENS2" -lt "$INPUT_TOKENS1" ]; then
        SAVINGS=$((INPUT_TOKENS1 - INPUT_TOKENS2))
        echo "💰 TOKEN SAVINGS: $SAVINGS tokens saved on second request"
    else
        echo "⚠️  NO TOKEN SAVINGS DETECTED"
    fi
fi

if [ -n "$CACHE_CREATED" ] && [ -n "$CACHE_HIT" ]; then
    echo "✅ PROMPT CACHING IS WORKING!"
    echo "   Cache created: $CACHE_CREATED tokens"
    echo "   Cache hit: $CACHE_HIT tokens"
else
    echo "❌ PROMPT CACHING NOT WORKING"
    echo ""
    echo "🔍 Debugging info:"
    echo "First request headers contain:"
    echo "$HEADERS1" | grep -i anthropic | head -5
    echo ""
    echo "Second request headers contain:"
    echo "$HEADERS2" | grep -i anthropic | head -5
fi

echo ""
echo "📝 Response samples:"
echo "==================="
echo "First response (truncated):"
echo "$BODY1" | head -c 200
echo "..."
echo ""
echo "Second response (truncated):"
echo "$BODY2" | head -c 200
echo "..."