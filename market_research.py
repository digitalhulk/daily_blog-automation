#!/usr/bin/env python3
"""
Market Research using Perplexity API
Gathers real-time data and insights for blog content
"""

import json
import os
import sys
import requests
from datetime import datetime

def load_config():
    """Load configuration from config.sh"""
    config = {}
    config_path = os.path.join(os.path.dirname(__file__), 'config.sh')

    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value.strip('"').strip("'")

    return config

def research_topic(topic, primary_keyword, api_key):
    """Use Perplexity API to research the topic"""

    url = "https://api.perplexity.ai/chat/completions"

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    # Research prompt for real estate marketing in India
    research_prompt = f"""Research the following topic for a real estate digital marketing blog in India:

Topic: {topic}
Primary Keyword: {primary_keyword}
Current Date: {datetime.now().strftime('%B %Y')}

Provide the following information:
1. Current market trends related to this topic in India (2025-2026)
2. 3-4 specific statistics with numbers (percentages, rupee amounts, growth rates)
3. Recent news or developments in Indian real estate related to this topic
4. Key challenges builders and developers face regarding this topic
5. Best practices and actionable tips
6. Any seasonal or timing factors relevant right now

Focus on Delhi NCR market (Gurgaon, Noida, Greater Noida).
Provide factual, data-driven insights that can be used in a professional blog post."""

    payload = {
        "model": "sonar",
        "messages": [
            {
                "role": "system",
                "content": "You are a real estate market research analyst specializing in the Indian property market, particularly Delhi NCR. Provide accurate, current data and insights."
            },
            {
                "role": "user",
                "content": research_prompt
            }
        ],
        "temperature": 0.3,
        "max_tokens": 1500
    }

    try:
        # (connect_timeout=10s, read_timeout=45s) to prevent hanging
        response = requests.post(url, headers=headers, json=payload, timeout=(10, 45))
        response.raise_for_status()

        result = response.json()
        research_content = result['choices'][0]['message']['content']

        return {
            "success": True,
            "research": research_content,
            "model": result.get('model', 'sonar'),
            "usage": result.get('usage', {})
        }

    except requests.exceptions.RequestException as e:
        return {
            "success": False,
            "error": str(e),
            "research": ""
        }

def main():
    # Load config
    config = load_config()
    api_key = config.get('PERPLEXITY_API_KEY', '')

    if not api_key:
        print("❌ Perplexity API key not configured")
        sys.exit(1)

    # Load today's topic
    script_dir = os.path.dirname(os.path.abspath(__file__))
    topic_file = os.path.join(script_dir, 'output', 'today_topic.json')

    if not os.path.exists(topic_file):
        print("❌ No topic file found. Run trend_topics.sh first.")
        sys.exit(1)

    with open(topic_file, 'r') as f:
        topic_data = json.load(f)

    topic = topic_data.get('topic', '')
    primary_keyword = topic_data.get('primary_keyword', '')

    print(f"🔍 Researching: {topic}")
    print(f"🔑 Keyword: {primary_keyword}")
    print("")

    # Perform research
    result = research_topic(topic, primary_keyword, api_key)

    if result['success']:
        print("✅ Research completed successfully!")
        print(f"📊 Model used: {result['model']}")
        print("")
        print("=" * 60)
        print("RESEARCH FINDINGS:")
        print("=" * 60)
        print(result['research'])
        print("=" * 60)

        # Save research to topic file for blog generator to use
        topic_data['perplexity_research'] = result['research']
        topic_data['research_date'] = datetime.now().isoformat()

        with open(topic_file, 'w') as f:
            json.dump(topic_data, f, indent=4, ensure_ascii=False)

        print("")
        print(f"✅ Research saved to: {topic_file}")

    else:
        print(f"❌ Research failed: {result['error']}")
        # Continue without research - blog will still generate
        topic_data['perplexity_research'] = ""

        with open(topic_file, 'w') as f:
            json.dump(topic_data, f, indent=4, ensure_ascii=False)

if __name__ == "__main__":
    main()
