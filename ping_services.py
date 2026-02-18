#!/usr/bin/env python3
"""
Ping Services - Notify blog directories and search engines about new content
Pings Pingomatic, Google, Bing, and other blog aggregators
"""

import json
import os
import sys
import urllib.request
import urllib.parse
from datetime import datetime
import xml.etree.ElementTree as ET

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SITE_URL = "https://leadhorizon.co.in"
SITE_NAME = "LeadHorizon"
BLOG_URL = f"{SITE_URL}/blog.html"
RSS_URL = f"{SITE_URL}/rss.xml"
SITEMAP_URL = f"{SITE_URL}/sitemap.xml"

def ping_rpc(service_name, rpc_url, blog_name, blog_url, blog_rss=""):
    """Send XML-RPC ping to a blog directory service"""

    xml_body = f"""<?xml version="1.0"?>
<methodCall>
  <methodName>weblogUpdates.ping</methodName>
  <params>
    <param><value>{blog_name}</value></param>
    <param><value>{blog_url}</value></param>
  </params>
</methodCall>"""

    try:
        req = urllib.request.Request(
            rpc_url,
            data=xml_body.encode('utf-8'),
            headers={
                'Content-Type': 'text/xml',
                'User-Agent': 'LeadHorizon Blog Automation/1.0'
            }
        )
        response = urllib.request.urlopen(req, timeout=15)
        result = response.read().decode('utf-8')

        if 'flerror' in result and '<boolean>0</boolean>' in result:
            print(f"  ✅ {service_name}: Pinged successfully")
            return True
        elif 'flerror' in result and '<boolean>1</boolean>' in result:
            print(f"  ⚠️ {service_name}: Ping accepted with warning")
            return True
        else:
            print(f"  ✅ {service_name}: Response received")
            return True
    except Exception as e:
        print(f"  ⚠️ {service_name}: {str(e)[:60]}")
        return False

def ping_http(service_name, url):
    """Simple HTTP GET ping"""
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'LeadHorizon Blog Automation/1.0'})
        response = urllib.request.urlopen(req, timeout=15)
        if response.status in [200, 301, 302]:
            print(f"  ✅ {service_name}: Pinged (HTTP {response.status})")
            return True
        else:
            print(f"  ⚠️ {service_name}: HTTP {response.status}")
            return False
    except Exception as e:
        print(f"  ⚠️ {service_name}: {str(e)[:60]}")
        return False

def main():
    print("🔔 Blog Ping Services")
    print("=" * 50)

    # Load blog data
    blog_file = os.path.join(SCRIPT_DIR, 'output', 'latest_blog.json')
    if not os.path.exists(blog_file):
        print("❌ No blog metadata found.")
        sys.exit(1)

    with open(blog_file, 'r') as f:
        blog_data = json.load(f)

    blog_url = blog_data.get('url', '')
    blog_title = blog_data.get('title', 'New Post')
    print(f"📄 Blog: {blog_title}")
    print(f"🔗 URL: {blog_url}")
    print("")

    success_count = 0
    total_count = 0

    # --- XML-RPC Pings ---
    print("📡 XML-RPC Pings:")
    rpc_services = [
        ("Pingomatic", "https://rpc.pingomatic.com/"),
        ("Weblogs.com", "http://rpc.weblogs.com/RPC2"),
        ("Google Blogs", "http://blogsearch.google.com/ping/RPC2"),
        ("Blog People", "http://www.blogpeople.net/ping/"),
    ]

    for name, url in rpc_services:
        total_count += 1
        if ping_rpc(name, url, SITE_NAME, BLOG_URL):
            success_count += 1

    print("")

    # --- HTTP GET Pings ---
    print("🌐 HTTP Pings:")
    encoded_sitemap = urllib.parse.quote(SITEMAP_URL)
    encoded_rss = urllib.parse.quote(RSS_URL)
    encoded_blog = urllib.parse.quote(BLOG_URL)

    http_pings = [
        ("Google Sitemap", f"https://www.google.com/ping?sitemap={encoded_sitemap}"),
        ("Bing Sitemap", f"https://www.bing.com/ping?sitemap={encoded_sitemap}"),
        ("Google Blog Update", f"https://www.google.com/ping?sitemap={encoded_rss}"),
    ]

    for name, url in http_pings:
        total_count += 1
        if ping_http(name, url):
            success_count += 1

    print("")
    print(f"📊 Results: {success_count}/{total_count} services pinged successfully")

    # Log
    log_file = os.path.join(SCRIPT_DIR, 'ping_log.txt')
    with open(log_file, 'a') as f:
        f.write(f"{datetime.now().isoformat()} | {blog_url} | {success_count}/{total_count} pings\n")

    print("✅ Ping services complete!")

if __name__ == "__main__":
    main()
