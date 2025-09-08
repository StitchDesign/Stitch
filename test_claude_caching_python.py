#!/usr/bin/env python3
"""
Test Claude Prompt Caching using the official Anthropic Python SDK

This script:
1. Fetches Pride and Prejudice from Project Gutenberg (large public domain text)
2. Makes two requests with the novel as a cached system prompt
3. Analyzes response headers for cache performance metrics
4. Determines if prompt caching is working for your account
"""

import os
import sys
import time
import json
import requests
from bs4 import BeautifulSoup
import anthropic

def fetch_book_content(url):
    """Fetch and clean text content from Project Gutenberg"""
    print(f"📚 Fetching book content from {url}")
    
    try:
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        # For plain text files from Gutenberg, we don't need BeautifulSoup
        if url.endswith('.txt'):
            content = response.text
        else:
            # For HTML, use BeautifulSoup to extract clean text
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Remove script and style elements
            for script in soup(["script", "style"]):
                script.decompose()
            
            # Get text
            content = soup.get_text()
        
        # Clean up the text
        lines = (line.strip() for line in content.splitlines())
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        clean_content = '\n'.join(chunk for chunk in chunks if chunk)
        
        print(f"✅ Successfully fetched {len(clean_content)} characters")
        return clean_content
        
    except requests.RequestException as e:
        print(f"❌ Failed to fetch book content: {e}")
        return None

def analyze_response_headers(response, request_num):
    """Analyze Claude API response headers for cache performance"""
    print(f"\n📊 Request #{request_num} Analysis:")
    print("=" * 40)
    
    # Access response metadata
    if hasattr(response, '_raw_response'):
        headers = response._raw_response.headers
    elif hasattr(response, 'headers'):
        headers = response.headers
    else:
        print("❌ Unable to access response headers")
        return False
    
    # Print ALL headers first
    print("🔍 ALL RESPONSE HEADERS:")
    for key, value in headers.items():
        print(f"   {key}: {value}")
    
    # Look for cache-related headers
    cache_headers_found = False
    cache_creation_tokens = None
    cache_read_tokens = None
    input_tokens = None
    output_tokens = None
    
    print(f"\n🔍 Analyzing cache-specific headers:")
    for key, value in headers.items():
        key_lower = key.lower()
        if 'anthropic-billing' in key_lower:
            print(f"   BILLING HEADER: {key}: {value}")
            cache_headers_found = True
            
            if 'cache-creation-input-tokens' in key_lower:
                cache_creation_tokens = int(value)
            elif 'cache-read-input-tokens' in key_lower:
                cache_read_tokens = int(value)
            elif 'input-tokens' in key_lower and 'cache' not in key_lower:
                input_tokens = int(value)
            elif 'output-tokens' in key_lower:
                output_tokens = int(value)
    
    if not cache_headers_found:
        print("   ❌ No cache-related billing headers found")
    
    # Analyze cache performance
    print(f"\n💾 Cache Performance:")
    if cache_creation_tokens is not None:
        print(f"   🆕 Cache created: {cache_creation_tokens} tokens")
    
    if cache_read_tokens is not None:
        print(f"   ⚡ Cache hit: {cache_read_tokens} tokens")
        if cache_creation_tokens and cache_read_tokens < cache_creation_tokens:
            savings = cache_creation_tokens - cache_read_tokens
            percent = (savings / cache_creation_tokens) * 100
            print(f"   💰 Token savings: {savings} tokens ({percent:.1f}%)")
    
    if input_tokens and output_tokens:
        total = input_tokens + output_tokens
        print(f"   🎯 Total usage: {input_tokens} input + {output_tokens} output = {total} tokens")
    
    if cache_creation_tokens is None and cache_read_tokens is None:
        print("   ❌ No cache activity detected")
    
    return cache_headers_found

def main():
    print("🔍 Testing Claude Prompt Caching with Python SDK")
    print("=" * 55)
    
    # Check for API key
    api_key = os.getenv('CLAUDE_API_KEY')
    if not api_key:
        print("❌ Error: CLAUDE_API_KEY environment variable is not set")
        print("Please set it with: export CLAUDE_API_KEY='your-api-key-here'")
        sys.exit(1)
    
    # Initialize Anthropic client
    client = anthropic.Anthropic(api_key=api_key)
    
    # Fetch Pride and Prejudice from Project Gutenberg
    book_url = "https://www.gutenberg.org/cache/epub/1342/pg1342.txt"
    book_content = fetch_book_content(book_url)
    
    if not book_content:
        print("❌ Failed to fetch book content. Exiting.")
        sys.exit(1)
    
    # Use only the first fourth of the book
    book_quarter = book_content[:len(book_content)//4]
    print(f"📏 Using first fourth of book: {len(book_quarter)} characters")
    
    # Estimate token count (rough approximation)
    estimated_tokens = len(book_quarter) // 3  # Very rough estimate
    print(f"📏 Estimated tokens in first fourth: ~{estimated_tokens:,}")
    
    if estimated_tokens < 1024:
        print("⚠️  Warning: Book content may be too small for caching (need >1024 tokens)")
    
    # Prepare system message with cache control
    system_messages = [
        {
            "type": "text",
            "text": "You are a literary analysis AI assistant."
        },
        {
            "type": "text", 
            "text": f"Here is the first fourth of Pride and Prejudice by Jane Austen:\n\n{book_quarter}",
            "cache_control": {"type": "ephemeral"}
        }
    ]
    
    print(f"\n📤 Making first request (should create cache)...")
    start_time = time.time()
    
    try:
        response1 = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system_messages,
            messages=[
                {
                    "role": "user",
                    "content": "What are the main themes in this novel? Give me 3 key themes."
                }
            ]
        )
        
        duration1 = time.time() - start_time
        print(f"✅ First request completed in {duration1:.2f} seconds")
        
        # Print complete response data
        print(f"\n📄 COMPLETE FIRST RESPONSE:")
        print("=" * 60)
        print("Raw response object:")
        print(f"  Model: {response1.model}")
        print(f"  Role: {response1.role}")
        print(f"  Stop reason: {response1.stop_reason}")
        print(f"  Stop sequence: {response1.stop_sequence}")
        print(f"  Usage: {response1.usage}")
        print(f"  Content type: {type(response1.content)}")
        print(f"  Content length: {len(response1.content)}")
        
        print(f"\nFull response content:")
        for i, content_block in enumerate(response1.content):
            print(f"  Block {i}: {content_block}")
        
        print(f"\nJSON representation:")
        try:
            print(json.dumps(response1.model_dump(), indent=2))
        except Exception as e:
            print(f"Could not serialize to JSON: {e}")
        
        # Analyze first response
        cache_detected_1 = analyze_response_headers(response1, 1)
        
    except Exception as e:
        print(f"❌ First request failed: {e}")
        sys.exit(1)
    
    # Wait before second request
    print(f"\n⏱️  Waiting 3 seconds before second request...")
    time.sleep(3)
    
    print(f"\n📤 Making second request (should hit cache)...")
    start_time = time.time()
    
    try:
        response2 = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=system_messages,  # Same system messages - should hit cache
            messages=[
                {
                    "role": "user",
                    "content": "Who are the main characters and what are their relationships?"
                }
            ]
        )
        
        duration2 = time.time() - start_time
        print(f"✅ Second request completed in {duration2:.2f} seconds")
        
        # Print complete response data
        print(f"\n📄 COMPLETE SECOND RESPONSE:")
        print("=" * 60)
        print("Raw response object:")
        print(f"  Model: {response2.model}")
        print(f"  Role: {response2.role}")
        print(f"  Stop reason: {response2.stop_reason}")
        print(f"  Stop sequence: {response2.stop_sequence}")
        print(f"  Usage: {response2.usage}")
        print(f"  Content type: {type(response2.content)}")
        print(f"  Content length: {len(response2.content)}")
        
        print(f"\nFull response content:")
        for i, content_block in enumerate(response2.content):
            print(f"  Block {i}: {content_block}")
        
        print(f"\nJSON representation:")
        try:
            print(json.dumps(response2.model_dump(), indent=2))
        except Exception as e:
            print(f"Could not serialize to JSON: {e}")
        
        # Analyze second response
        cache_detected_2 = analyze_response_headers(response2, 2)
        
    except Exception as e:
        print(f"❌ Second request failed: {e}")
        sys.exit(1)
    
    # Final analysis
    print(f"\n🎯 Final Analysis:")
    print("=" * 20)
    print(f"Request 1 duration: {duration1:.2f}s")
    print(f"Request 2 duration: {duration2:.2f}s")
    
    if duration2 < duration1 * 0.8:  # Significant speed improvement
        print("⚡ Request 2 was significantly faster - possible cache hit!")
    
    if cache_detected_1 or cache_detected_2:
        print("✅ Cache headers detected - prompt caching appears to be working!")
    else:
        print("❌ No cache headers detected")
        print("   → Prompt caching may not be available for your account/region")
        print("   → Try contacting Anthropic support about prompt caching access")
    
    print(f"\n📋 Book content stats:")
    print(f"   Characters: {len(book_content):,}")
    print(f"   Lines: {book_content.count(chr(10)):,}")
    print(f"   Estimated tokens: ~{estimated_tokens:,}")

if __name__ == "__main__":
    main()
