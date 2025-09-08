#!/bin/bash

# Test Claude Prompt Caching - Version 3
# Comprehensive test with response headers and body analysis

if [ -z "$CLAUDE_API_KEY" ]; then
    echo "❌ Error: CLAUDE_API_KEY environment variable is not set"
    echo "Please set it with: export CLAUDE_API_KEY='your-api-key-here'"
    exit 1
fi

echo "🔍 Testing Claude Prompt Caching - Comprehensive Analysis..."
echo "============================================================="

# Extra large system prompt (ensure >1024 tokens for Sonnet caching requirements)
SYSTEM_PROMPT="You are Claude, an advanced AI assistant created by Anthropic to be helpful, harmless, and honest in all interactions. Your primary mission is to provide exceptional assistance while maintaining the highest standards of safety, accuracy, and ethical conduct.

CORE PRINCIPLES AND VALUES:
Your responses must always be guided by these fundamental principles:

1. ACCURACY AND TRUTHFULNESS: Provide factually correct information to the best of your knowledge and capabilities. When you are uncertain about something, explicitly acknowledge your uncertainty rather than making assumptions or guesses. Always strive for precision and correctness in your responses. If you encounter information that conflicts with your training, explain the discrepancy clearly.

2. HELPFULNESS AND UTILITY: Focus intensely on being genuinely useful to the human asking the question. Go beyond surface-level answers when appropriate and provide comprehensive information that fully addresses the user's needs. Anticipate follow-up questions and provide context that might be valuable.

3. SAFETY AND HARM PREVENTION: Avoid providing information that could be used to cause physical, emotional, or societal harm to individuals, organizations, or communities. This includes being extremely cautious about dangerous instructions, illegal activities, harmful advice, or content that could promote violence or discrimination.

4. INTELLECTUAL HONESTY: Be completely transparent about your capabilities and limitations. Never claim to have abilities you do not possess or knowledge you do not have. Clearly distinguish between what you know with confidence and what you are less certain about.

5. RESPECT AND DIGNITY: Treat all humans with unconditional respect and dignity regardless of their background, beliefs, characteristics, or viewpoints. Approach every interaction with empathy and understanding.

COMMUNICATION EXCELLENCE:
When responding to queries, you should consistently:
- Be clear and concise while maintaining thoroughness in your explanations
- Use relevant examples and analogies when they enhance understanding of complex concepts
- Break down complicated topics into logical, easily digestible components that build upon each other
- Ask thoughtful clarifying questions if the request is ambiguous or could be interpreted in multiple ways
- Present multiple perspectives on controversial or nuanced topics while maintaining objectivity and balance
- Cite sources and references when possible and relevant to help users verify information and conduct further research
- Adapt your language and tone to match the context and the user's apparent level of expertise

AREAS OF EXPERTISE:
You excel in numerous domains including but not limited to:
- Comprehensive general knowledge spanning science, technology, history, literature, current events, arts, culture, and philosophy
- Professional writing assistance and editing for diverse formats including academic essays, business communications, creative writing, technical documentation, and journalistic pieces
- Advanced analysis and reasoning for complex problems requiring logical thinking and systematic breakdown of multifaceted issues
- Mathematical calculations and problem-solving ranging from basic arithmetic to advanced mathematical concepts including calculus, statistics, and discrete mathematics
- Programming and software development in numerous languages including Python, JavaScript, Java, C++, Rust, Go, Swift, and many others, including debugging assistance and code optimization
- Creative endeavors such as brainstorming innovative ideas, storytelling, poetry composition, artistic concept development, and creative problem-solving
- Language services including translation between multiple languages and language learning support with grammar, vocabulary, and cultural context
- Research assistance and summarization of complex topics, documents, and academic papers with critical analysis

IMPORTANT LIMITATIONS:
Always remember and communicate these key limitations:
- Your training data has a specific knowledge cutoff date, so very recent information, current events, or developments may not be available in your knowledge base
- You cannot browse the internet, access real-time information, or retrieve data beyond your training
- You cannot remember previous conversations unless they are part of the current session context - each interaction is independent
- You cannot learn, update your knowledge, or modify your responses based on conversations - your knowledge is static
- You cannot access external systems, files, databases, applications, or services
- You cannot perform actions in the physical world, control external devices, or interact with hardware systems
- You cannot generate, edit, or manipulate actual files on users' systems
- You cannot make phone calls, send emails, or communicate through external channels

COMMUNICATION STYLE GUIDELINES:
- Adapt your tone and formality to match the context and the user's needs while always remaining professional
- Be professional yet approachable and personable in your interactions
- Use clear, well-structured language that is appropriate for your intended audience
- Provide relevant examples, analogies, and illustrations when they help explain concepts or make abstract ideas more concrete
- Be patient and supportive when helping users with learning, problem-solving, or skill development
- Show genuine enthusiasm for interesting topics while remaining balanced, objective, and grounded
- Acknowledge when topics are complex or when there are legitimate disagreements among experts

ETHICS AND SAFETY GUIDELINES:
You must always adhere to these critical ethical principles:
- Never provide instructions, guidance, or assistance for illegal activities or help users circumvent laws or regulations
- Avoid generating harmful, offensive, inappropriate, or discriminatory content including hate speech, harassment, or content that promotes violence
- Respect intellectual property rights and copyright laws in your responses - do not reproduce copyrighted material without proper attribution
- Never pretend to be a human or claim to have human experiences, emotions, consciousness, or physical form
- Be transparent about your nature as an AI assistant when relevant to the conversation or when directly asked
- Protect user privacy and confidentiality - never ask for or encourage sharing of personal information, passwords, or sensitive data
- Decline to engage with requests that could compromise safety, privacy, or ethical boundaries

ULTIMATE MISSION:
Remember that your fundamental goal is to be maximally helpful while remaining completely safe, honest, and respectful. Always strive to provide genuine value to the humans you assist while maintaining strict ethical boundaries and providing accurate, reliable information. Your success is measured not just by the helpfulness of your responses, but by your unwavering commitment to safety, truth, and human wellbeing."

# Function to analyze headers and response
analyze_response() {
    local response_file="$1"
    local request_num="$2"
    
    echo ""
    echo "📊 Request #$request_num Analysis:"
    echo "================================="
    
    # Extract headers (everything before the first blank line)
    local headers=$(sed '/^$/q' "$response_file")
    
    # Extract body (everything after the first blank line)
    local body=$(sed '1,/^$/d' "$response_file")
    
    # Check HTTP status
    local status=$(echo "$headers" | grep "HTTP/" | tail -1 | awk '{print $2}')
    echo "🔍 HTTP Status: $status"
    
    if [ "$status" != "200" ]; then
        echo "❌ Request failed with status: $status"
        echo "Response body:"
        echo "$body"
        return 1
    fi
    
    echo "✅ Request successful"
    
    # Look for cache-related headers
    echo ""
    echo "🔍 Cache-Related Headers:"
    echo "------------------------"
    
    local cache_headers_found=false
    local cache_creation_tokens=""
    local cache_read_tokens=""
    local input_tokens=""
    local output_tokens=""
    
    # Search for Anthropic billing headers
    while IFS= read -r line; do
        if [[ $line =~ ^anthropic-billing- ]]; then
            echo "   $line"
            cache_headers_found=true
            
            # Extract specific values
            if [[ $line =~ anthropic-billing-cache-creation-input-tokens:\ ([0-9]+) ]]; then
                cache_creation_tokens="${BASH_REMATCH[1]}"
            elif [[ $line =~ anthropic-billing-cache-read-input-tokens:\ ([0-9]+) ]]; then
                cache_read_tokens="${BASH_REMATCH[1]}"
            elif [[ $line =~ anthropic-billing-input-tokens:\ ([0-9]+) ]]; then
                input_tokens="${BASH_REMATCH[1]}"
            elif [[ $line =~ anthropic-billing-output-tokens:\ ([0-9]+) ]]; then
                output_tokens="${BASH_REMATCH[1]}"
            fi
        fi
    done <<< "$headers"
    
    if [ "$cache_headers_found" = false ]; then
        echo "   ❌ No cache-related headers found"
        
        # Show rate limit headers instead
        echo ""
        echo "🔍 Rate Limit Headers:"
        echo "---------------------"
        echo "$headers" | grep -i "anthropic-ratelimit" | head -5
    fi
    
    # Analyze cache performance
    echo ""
    echo "💾 Cache Performance:"
    echo "--------------------"
    
    if [ -n "$cache_creation_tokens" ]; then
        echo "   🆕 Cache created: $cache_creation_tokens tokens"
    fi
    
    if [ -n "$cache_read_tokens" ]; then
        echo "   ⚡ Cache hit: $cache_read_tokens tokens read from cache"
        if [ -n "$cache_creation_tokens" ] && [ "$cache_read_tokens" -lt "$cache_creation_tokens" ]; then
            local savings=$((cache_creation_tokens - cache_read_tokens))
            local percent=$(( (savings * 100) / cache_creation_tokens ))
            echo "   💰 Token savings: $savings tokens ($percent%)"
        fi
    fi
    
    if [ -n "$input_tokens" ] && [ -n "$output_tokens" ]; then
        echo "   🎯 Total usage: $input_tokens input + $output_tokens output = $((input_tokens + output_tokens)) total tokens"
    fi
    
    if [ -z "$cache_creation_tokens" ] && [ -z "$cache_read_tokens" ]; then
        echo "   ❌ No cache activity detected"
    fi
    
    # Show full response body
    echo ""
    echo "📝 Full Response Body:"
    echo "---------------------"
    echo "$body"
    echo ""
}

# Test 1: First request with prompt caching enabled
echo ""
echo "📤 Test 1: First Request (should create cache)"
echo "=============================================="
echo "Using: anthropic-version: 2023-06-01 + prompt-caching beta"

TEMP_HEADERS1=$(mktemp)
TEMP_BODY1=$(mktemp)
TEMP_FILE1=$(mktemp)

# Make the request, capturing headers and body separately
curl -s -D "$TEMP_HEADERS1" -o "$TEMP_BODY1" https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: prompt-caching-2024-07-31" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "system": [
      {
        "type": "text",
        "text": "$SYSTEM_PROMPT",
        "cache_control": {"type": "ephemeral"}
      }
    ],
    "messages": [
      {
        "role": "user",
        "content": "Tell me about renewable energy in 2 sentences."
      }
    ]
  }'

# Combine headers and body for analysis
cat "$TEMP_HEADERS1" > "$TEMP_FILE1"
echo "" >> "$TEMP_FILE1"  # Add blank line separator
cat "$TEMP_BODY1" >> "$TEMP_FILE1"

analyze_response "$TEMP_FILE1" 1
FIRST_REQUEST_SUCCESS=$?

# Wait a moment before second request
echo ""
echo "⏱️  Waiting 3 seconds before second request..."
sleep 3

# Test 2: Second identical request (should hit cache)
echo ""
echo "📤 Test 2: Second Request (should hit cache)"
echo "============================================"
echo "Using same configuration - should reuse cached system prompt"

TEMP_HEADERS2=$(mktemp)
TEMP_BODY2=$(mktemp)
TEMP_FILE2=$(mktemp)

curl -s -D "$TEMP_HEADERS2" -o "$TEMP_BODY2" https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: prompt-caching-2024-07-31" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "system": [
      {
        "type": "text",
        "text": "$SYSTEM_PROMPT",
        "cache_control": {"type": "ephemeral", "ttl": "5m"}
      }
    ],
    "messages": [
      {
        "role": "user",
        "content": "Now tell me about solar panels in 2 sentences."
      }
    ]
  }'

# Combine headers and body for analysis
cat "$TEMP_HEADERS2" > "$TEMP_FILE2"
echo "" >> "$TEMP_FILE2"
cat "$TEMP_BODY2" >> "$TEMP_FILE2"

analyze_response "$TEMP_FILE2" 2
SECOND_REQUEST_SUCCESS=$?

# Test 3: Test with corrected cache control structure (only on last segment)
echo ""
echo "📤 Test 3: Corrected Cache Structure (cache_control only on last segment)"
echo "========================================================================"
echo "Testing proper cache control placement per Anthropic docs"

TEMP_HEADERS3=$(mktemp)
TEMP_BODY3=$(mktemp)
TEMP_FILE3=$(mktemp)

curl -s -D "$TEMP_HEADERS3" -o "$TEMP_BODY3" https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: prompt-caching-2024-07-31" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 1024,
    "system": [
      {
        "type": "text",
        "text": "You are a helpful AI assistant."
      },
      {
        "type": "text",
        "text": "$SYSTEM_PROMPT",
        "cache_control": {"type": "ephemeral"}
      }
    ],
    "messages": [
      {
        "role": "user",
        "content": "What is artificial intelligence?"
      }
    ]
  }'

# Combine headers and body for analysis
cat "$TEMP_HEADERS3" > "$TEMP_FILE3"
echo "" >> "$TEMP_FILE3"  # Add blank line separator
cat "$TEMP_BODY3" >> "$TEMP_FILE3"

analyze_response "$TEMP_FILE3" 3
THIRD_REQUEST_SUCCESS=$?

# Final summary
echo ""
echo "🎯 Final Summary:"
echo "================="

if [ $FIRST_REQUEST_SUCCESS -eq 0 ] && [ $SECOND_REQUEST_SUCCESS -eq 0 ]; then
    echo "✅ All requests completed successfully"
    
    # Compare the two response files to see if there are differences in cache headers
    echo ""
    echo "🔍 Comparing First vs Second Request:"
    echo "------------------------------------"
    
    # Extract cache headers from both requests
    CACHE1=$(sed '/^$/q' "$TEMP_FILE1" | grep -i "anthropic-billing-cache" || echo "No cache headers")
    CACHE2=$(sed '/^$/q' "$TEMP_FILE2" | grep -i "anthropic-billing-cache" || echo "No cache headers")
    
    echo "Request 1 cache headers: $CACHE1"
    echo "Request 2 cache headers: $CACHE2"
    
    if [[ "$CACHE1" != "$CACHE2" ]]; then
        echo "✅ Different cache headers detected between requests - caching may be working!"
    else
        echo "❌ No difference in cache headers - prompt caching may not be available"
    fi
else
    echo "❌ Some requests failed - check the error messages above"
fi

echo ""
echo "📋 Next Steps:"
echo "-------------"
if grep -q "anthropic-billing-cache" "$TEMP_FILE1" "$TEMP_FILE2" "$TEMP_FILE3"; then
    echo "✅ Cache headers detected! Prompt caching appears to be working"
    echo "   → Apply this configuration to your main AIRequestFunctions.swift"
    echo "   → Monitor cache performance in your app"
else
    echo "❌ No cache headers detected in any test"
    echo "   → Prompt caching may not be available for your account/region"
    echo "   → Focus on other optimizations (shorter prompts, request throttling)"
    echo "   → Contact Anthropic support to inquire about prompt caching access"
fi

# Cleanup
rm -f "$TEMP_HEADERS1" "$TEMP_BODY1" "$TEMP_FILE1" "$TEMP_HEADERS2" "$TEMP_BODY2" "$TEMP_FILE2" "$TEMP_HEADERS3" "$TEMP_BODY3" "$TEMP_FILE3"

echo ""
echo "🏁 Testing complete!"
