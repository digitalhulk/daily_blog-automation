#!/usr/bin/env python3
"""
Google Indexing API Script
Submits URLs to Google for faster indexing

Setup required:
1. Create a project in Google Cloud Console
2. Enable Indexing API
3. Create a service account and download JSON key
4. Add service account email as owner in Google Search Console
5. Set GOOGLE_SERVICE_ACCOUNT_JSON in config.sh
"""

import json
import os
import sys
from datetime import datetime

# Try to import google auth libraries
try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    GOOGLE_LIBS_AVAILABLE = True
except ImportError:
    GOOGLE_LIBS_AVAILABLE = False
    print("⚠️ Google libraries not installed. Run: pip3 install google-auth google-api-python-client")

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

def submit_url_to_google(url, service_account_file):
    """Submit URL to Google Indexing API"""

    if not GOOGLE_LIBS_AVAILABLE:
        print("❌ Cannot submit - Google libraries not installed")
        return False

    if not service_account_file or not os.path.exists(service_account_file):
        print("❌ Service account JSON not configured")
        print("📋 To enable Google indexing:")
        print("   1. Go to Google Cloud Console")
        print("   2. Create a project and enable Indexing API")
        print("   3. Create service account, download JSON key")
        print("   4. Add service account email to Search Console as owner")
        print("   5. Set path in config.sh: GOOGLE_SERVICE_ACCOUNT_JSON=\"/path/to/key.json\"")
        return False

    try:
        SCOPES = ["https://www.googleapis.com/auth/indexing"]
        credentials = service_account.Credentials.from_service_account_file(
            service_account_file, scopes=SCOPES
        )

        service = build('indexing', 'v3', credentials=credentials)

        body = {
            'url': url,
            'type': 'URL_UPDATED'
        }

        response = service.urlNotifications().publish(body=body).execute()
        print(f"✅ Submitted to Google: {url}")
        print(f"   Response: {response}")
        return True

    except Exception as e:
        print(f"❌ Google submission failed: {str(e)}")
        return False

def ping_search_engines(url, sitemap_url):
    """Ping search engines about sitemap update (fallback method)"""
    import urllib.request
    import urllib.parse

    ping_urls = [
        f"https://www.google.com/ping?sitemap={urllib.parse.quote(sitemap_url)}",
        f"https://www.bing.com/ping?sitemap={urllib.parse.quote(sitemap_url)}",
    ]

    print("🔔 Pinging search engines...")

    for ping_url in ping_urls:
        try:
            req = urllib.request.Request(ping_url, headers={'User-Agent': 'Mozilla/5.0'})
            response = urllib.request.urlopen(req, timeout=10)
            print(f"✅ Pinged: {ping_url.split('?')[0]}")
        except Exception as e:
            print(f"⚠️ Ping failed: {ping_url.split('?')[0]} - {str(e)}")

def main():
    config = load_config()

    # Load latest blog info
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, 'output')
    latest_blog_file = os.path.join(output_dir, 'latest_blog.json')

    if not os.path.exists(latest_blog_file):
        print("❌ No blog metadata found. Run generate_blog.sh first.")
        sys.exit(1)

    with open(latest_blog_file, 'r') as f:
        blog_data = json.load(f)

    blog_url = blog_data['url']
    site_url = config.get('SITE_URL', 'https://leadhorizon.co.in')
    sitemap_url = f"{site_url}/sitemap.xml"

    print(f"📄 Blog URL: {blog_url}")
    print(f"🗺️ Sitemap: {sitemap_url}")
    print("")

    # Try Google Indexing API
    service_account_json = config.get('GOOGLE_SERVICE_ACCOUNT_JSON', '')
    if service_account_json:
        service_account_json = os.path.expanduser(service_account_json)

    submit_url_to_google(blog_url, service_account_json)

    # Always ping search engines (free, no setup required)
    ping_search_engines(blog_url, sitemap_url)

    # Log submission
    log_file = os.path.join(os.path.dirname(__file__), 'indexing_log.txt')
    with open(log_file, 'a') as f:
        f.write(f"{datetime.now().isoformat()} | {blog_url}\n")

    print("")
    print("✅ Indexing requests complete!")

if __name__ == "__main__":
    main()
