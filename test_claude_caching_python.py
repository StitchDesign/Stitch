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

def analyze_response_for_cache(response, request_num):
    """Analyze Claude API response body and metadata for cache performance"""
    print(f"\n📊 Request #{request_num} Analysis:")
    print("=" * 40)
    
    cache_detected = False
    
    # Check usage object in response for cache information
    if hasattr(response, 'usage') and response.usage:
        print("🔍 USAGE OBJECT:")
        usage = response.usage
        print(f"   Raw usage: {usage}")
        
        # Check if usage has cache-related fields
        usage_dict = usage.model_dump() if hasattr(usage, 'model_dump') else usage.__dict__
        print(f"   Usage fields: {list(usage_dict.keys())}")
        
        for key, value in usage_dict.items():
            if 'cache' in key.lower():
                print(f"   🎯 CACHE FIELD: {key} = {value}")
                cache_detected = True
            else:
                print(f"   {key} = {value}")
    
    # Look for cache info in other response fields
    print(f"\n🔍 CHECKING ALL RESPONSE ATTRIBUTES FOR CACHE INFO:")
    for attr in dir(response):
        if not attr.startswith('_') and 'cache' in attr.lower():
            try:
                value = getattr(response, attr)
                print(f"   CACHE ATTRIBUTE: {attr} = {value}")
                cache_detected = True
            except:
                print(f"   CACHE ATTRIBUTE: {attr} (could not access)")
    
    # Look through the complete response dump for cache-related fields
    print(f"\n🔍 SEARCHING RESPONSE DUMP FOR CACHE TERMS:")
    try:
        response_dict = response.model_dump()
        response_str = json.dumps(response_dict, indent=2).lower()
        
        cache_terms = ['cache', 'cached', 'caching']
        for term in cache_terms:
            if term in response_str:
                print(f"   📍 Found '{term}' in response")
                cache_detected = True
        
        # Look for specific cache fields in nested objects
        def search_dict(obj, path=""):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    current_path = f"{path}.{key}" if path else key
                    if 'cache' in key.lower():
                        print(f"   🎯 CACHE KEY: {current_path} = {value}")
                        cache_detected = True
                    search_dict(value, current_path)
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    search_dict(item, f"{path}[{i}]")
        
        search_dict(response_dict)
        
    except Exception as e:
        print(f"   Could not search response dump: {e}")
    
    if not cache_detected:
        print("   ❌ No cache-related information found in response body")
    
    return cache_detected

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
    
    # Use only the first tenth of the book
    book_tenth = book_content[:len(book_content)//10]
    print(f"📏 Using first tenth of book: {len(book_tenth)} characters")
    
    # Estimate token count (rough approximation)
    estimated_tokens = len(book_tenth) // 3  # Very rough estimate
    print(f"📏 Estimated tokens in first tenth: ~{estimated_tokens:,}")
    
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
            "text": f"Here is the first tenth of Pride and Prejudice by Jane Austen:\n\n{book_tenth}",
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
        
        # Analyze first response for cache info
        cache_detected_1 = analyze_response_for_cache(response1, 1)
        
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
        
        # Analyze second response for cache info
        cache_detected_2 = analyze_response_for_cache(response2, 2)
        
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
        print("✅ Cache information detected in response - prompt caching appears to be working!")
    else:
        print("❌ No cache information detected in response body")
        print("   → Prompt caching may not be available for your account/region")
        print("   → Try contacting Anthropic support about prompt caching access")
    
    print(f"\n📋 Book content stats:")
    print(f"   Characters: {len(book_content):,}")
    print(f"   Lines: {book_content.count(chr(10)):,}")
    print(f"   Estimated tokens: ~{estimated_tokens:,}")

if __name__ == "__main__":
    main()
