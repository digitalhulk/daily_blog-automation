#!/usr/bin/env python3
"""
IndexNow - Instant Indexing for Bing, Yandex, Seznam, Naver
Submits new blog URLs for immediate crawling (free, no API key registration needed)
"""

import json
import os
import sys
import requests
import uuid
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INDEXNOW_KEY = "a1b2c3d4e5f6g7h8i9j0leadhorizon2026"
SITE_URL = "https://leadhorizon.co.in"

def load_blog_data():
    """Load latest blog metadata"""
    blog_file = os.path.join(SCRIPT_DIR, 'output', 'latest_blog.json')
    if not os.path.exists(blog_file):
        print("❌ No blog metadata found.")
        return None
    with open(blog_file, 'r') as f:
        return json.load(f)

def submit_indexnow(url):
    """Submit URL to IndexNow API (reaches Bing, Yandex, Seznam, Naver)"""

    endpoints = [
        "https://api.indexnow.org/indexnow",
        "https://www.bing.com/indexnow",
        "https://yandex.com/indexnow",
    ]

    payload = {
        "host": "leadhorizon.co.in",
        "key": INDEXNOW_KEY,
        "keyLocation": f"{SITE_URL}/{INDEXNOW_KEY}.txt",
        "urlList": [
            url,
            f"{SITE_URL}/sitemap.xml",
            f"{SITE_URL}/blog.html"
        ]
    }

    headers = {
        "Content-Type": "application/json; charset=utf-8"
    }

    success_count = 0

    for endpoint in endpoints:
        try:
            response = requests.post(endpoint, json=payload, headers=headers, timeout=15)
            if response.status_code in [200, 202]:
                engine = endpoint.split("//")[1].split("/")[0].split(".")[0]
                if engine == "api":
                    engine = "IndexNow (all engines)"
                print(f"✅ {engine}: Submitted successfully (HTTP {response.status_code})")
                success_count += 1
            else:
                engine = endpoint.split("//")[1].split("/")[0]
                print(f"⚠️ {engine}: HTTP {response.status_code} - {response.text[:100]}")
        except Exception as e:
            engine = endpoint.split("//")[1].split("/")[0]
            print(f"⚠️ {engine}: Error - {str(e)}")

    return success_count > 0

def deploy_key_file():
    """Deploy IndexNow key verification file to server"""
    import subprocess

    config = {}
    config_path = os.path.join(SCRIPT_DIR, 'config.sh')
    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value.strip('"').strip("'")

    # Create key file locally
    key_file = os.path.join(SCRIPT_DIR, 'output', f'{INDEXNOW_KEY}.txt')
    with open(key_file, 'w') as f:
        f.write(INDEXNOW_KEY)

    # Upload to server root
    ssh_host = config.get('SSH_HOST', '')
    ssh_port = config.get('SSH_PORT', '22')
    ssh_user = config.get('SSH_USER', '')
    ssh_pass = config.get('SSH_PASS', '')
    remote_path = config.get('REMOTE_PATH', '')

    if ssh_host and ssh_user:
        cmd = f'sshpass -p "{ssh_pass}" scp -o StrictHostKeyChecking=no -P {ssh_port} "{key_file}" "{ssh_user}@{ssh_host}:{remote_path}/{INDEXNOW_KEY}.txt"'
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ IndexNow key file deployed to server")
            return True
        else:
            print(f"⚠️ Key file upload failed: {result.stderr}")
            return False
    return False

def main():
    print("🚀 IndexNow - Instant Indexing")
    print("=" * 50)

    blog_data = load_blog_data()
    if not blog_data:
        sys.exit(1)

    blog_url = blog_data.get('url', '')
    print(f"📄 URL: {blog_url}")
    print("")

    # Deploy key file (only needed once, but safe to repeat)
    print("🔑 Deploying verification key...")
    deploy_key_file()
    print("")

    # Submit to IndexNow
    print("📡 Submitting to search engines...")
    submit_indexnow(blog_url)

    # Log
    log_file = os.path.join(SCRIPT_DIR, 'indexnow_log.txt')
    with open(log_file, 'a') as f:
        f.write(f"{datetime.now().isoformat()} | {blog_url}\n")

    print("")
    print("✅ IndexNow submission complete!")

if __name__ == "__main__":
    main()
