#!/usr/bin/env python3
"""
RSS Feed Generator for LeadHorizon Blog
Generates RSS 2.0 feed from blog posts and deploys to server
"""

import json
import os
import sys
import subprocess
from datetime import datetime, timezone
import xml.etree.ElementTree as ET
from email.utils import formatdate
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SITE_URL = "https://leadhorizon.co.in"
SITE_NAME = "LeadHorizon"
SITE_DESC = "Real Estate Digital Marketing Insights - SEO, PPC, Social Media & Lead Generation tips for builders and developers in India."

def load_config():
    config = {}
    config_path = os.path.join(SCRIPT_DIR, 'config.sh')
    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value.strip('"').strip("'")
    return config

def get_existing_feed():
    """Try to download existing RSS feed from server"""
    config = load_config()
    ssh_host = config.get('SSH_HOST', '')
    ssh_port = config.get('SSH_PORT', '22')
    ssh_user = config.get('SSH_USER', '')
    ssh_pass = config.get('SSH_PASS', '')
    remote_path = config.get('REMOTE_PATH', '')

    local_feed = os.path.join(SCRIPT_DIR, 'output', 'rss_existing.xml')

    cmd = f'sshpass -p "{ssh_pass}" scp -o StrictHostKeyChecking=no -P {ssh_port} "{ssh_user}@{ssh_host}:{remote_path}/rss.xml" "{local_feed}" 2>/dev/null'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    if result.returncode == 0 and os.path.exists(local_feed):
        try:
            tree = ET.parse(local_feed)
            return tree
        except:
            pass
    return None

def create_rss_feed(blog_data, existing_tree=None):
    """Create or update RSS 2.0 feed"""

    existing_items = []
    if existing_tree:
        root = existing_tree.getroot()
        channel = root.find('channel')
        if channel is not None:
            existing_items = channel.findall('item')

    # Build RSS
    rss = ET.Element('rss', version='2.0')
    rss.set('xmlns:atom', 'http://www.w3.org/2005/Atom')
    rss.set('xmlns:content', 'http://purl.org/rss/1.0/modules/content/')

    channel = ET.SubElement(rss, 'channel')

    # Channel metadata
    ET.SubElement(channel, 'title').text = f"{SITE_NAME} Blog"
    ET.SubElement(channel, 'link').text = f"{SITE_URL}/blog.html"
    ET.SubElement(channel, 'description').text = SITE_DESC
    ET.SubElement(channel, 'language').text = 'en-in'
    ET.SubElement(channel, 'copyright').text = f"Copyright {datetime.now().year} {SITE_NAME}"
    ET.SubElement(channel, 'managingEditor').text = 'info@leadhorizon.co.in (LeadHorizon)'
    ET.SubElement(channel, 'webMaster').text = 'info@leadhorizon.co.in (LeadHorizon)'
    ET.SubElement(channel, 'lastBuildDate').text = formatdate(timeval=time.time(), localtime=False, usegmt=True)
    ET.SubElement(channel, 'generator').text = 'LeadHorizon Blog Automation'
    ET.SubElement(channel, 'ttl').text = '60'

    # Atom self-link
    atom_link = ET.SubElement(channel, 'atom:link')
    atom_link.set('href', f'{SITE_URL}/rss.xml')
    atom_link.set('rel', 'self')
    atom_link.set('type', 'application/rss+xml')

    # Image
    image = ET.SubElement(channel, 'image')
    ET.SubElement(image, 'url').text = f'{SITE_URL}/og-image.jpg'
    ET.SubElement(image, 'title').text = f'{SITE_NAME} Blog'
    ET.SubElement(image, 'link').text = f'{SITE_URL}/blog.html'

    # Add new blog post as first item
    blog_url = blog_data.get('url', '')
    blog_title = blog_data.get('title', 'New Blog Post')
    blog_slug = blog_data.get('slug', '')
    blog_category = blog_data.get('category', 'Market Trends')

    # Check if this URL already exists
    existing_urls = set()
    for item in existing_items:
        link = item.find('link')
        if link is not None:
            existing_urls.add(link.text)

    if blog_url not in existing_urls:
        item = ET.SubElement(channel, 'item')
        ET.SubElement(item, 'title').text = blog_title
        ET.SubElement(item, 'link').text = blog_url
        ET.SubElement(item, 'guid', isPermaLink='true').text = blog_url
        ET.SubElement(item, 'pubDate').text = formatdate(timeval=time.time(), localtime=False, usegmt=True)
        ET.SubElement(item, 'category').text = blog_category
        ET.SubElement(item, 'description').text = f"Expert insights on {blog_title.lower()} - strategies and tips for real estate professionals by LeadHorizon."
        ET.SubElement(item, 'author').text = 'info@leadhorizon.co.in (LeadHorizon)'

        if blog_slug:
            enclosure = ET.SubElement(item, 'enclosure')
            enclosure.set('url', f'{SITE_URL}/images/{blog_slug}.jpg')
            enclosure.set('type', 'image/jpeg')
            enclosure.set('length', '50000')

    # Re-add existing items (max 50 total)
    count = 1
    for old_item in existing_items:
        if count >= 50:
            break
        old_link = old_item.find('link')
        if old_link is not None and old_link.text == blog_url:
            continue
        channel.append(old_item)
        count += 1

    return rss

def deploy_rss(rss_element):
    """Deploy RSS feed to server"""
    config = load_config()

    # Write locally
    output_file = os.path.join(SCRIPT_DIR, 'output', 'rss.xml')

    tree = ET.ElementTree(rss_element)
    ET.indent(tree, space='    ')

    with open(output_file, 'wb') as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
        tree.write(f, encoding='unicode' if sys.version_info >= (3, 8) else None, xml_declaration=False)

    # Fix: write properly with declaration
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        ET.indent(tree, space='    ')
        tree.write(f, encoding='unicode', xml_declaration=False)

    # Upload to server
    ssh_host = config.get('SSH_HOST', '')
    ssh_port = config.get('SSH_PORT', '22')
    ssh_user = config.get('SSH_USER', '')
    ssh_pass = config.get('SSH_PASS', '')
    remote_path = config.get('REMOTE_PATH', '')

    cmd = f'sshpass -p "{ssh_pass}" scp -o StrictHostKeyChecking=no -P {ssh_port} "{output_file}" "{ssh_user}@{ssh_host}:{remote_path}/rss.xml"'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    if result.returncode == 0:
        print(f"✅ RSS feed deployed: {SITE_URL}/rss.xml")
        return True
    else:
        print(f"⚠️ RSS deploy failed: {result.stderr}")
        return False

def main():
    print("📡 RSS Feed Generator")
    print("=" * 50)

    # Load blog data
    blog_file = os.path.join(SCRIPT_DIR, 'output', 'latest_blog.json')
    if not os.path.exists(blog_file):
        print("❌ No blog metadata found.")
        sys.exit(1)

    with open(blog_file, 'r') as f:
        blog_data = json.load(f)

    print(f"📄 Adding: {blog_data.get('title', 'Unknown')}")
    print(f"🔗 URL: {blog_data.get('url', '')}")
    print("")

    # Get existing feed
    print("📥 Fetching existing RSS feed...")
    existing = get_existing_feed()
    if existing:
        print("✅ Existing feed found, will append")
    else:
        print("📝 No existing feed, creating fresh")
    print("")

    # Generate RSS
    print("🔧 Generating RSS feed...")
    rss = create_rss_feed(blog_data, existing)

    # Deploy
    print("📤 Deploying RSS feed...")
    deploy_rss(rss)

    print("")
    print("✅ RSS feed updated!")
    print(f"🔗 Feed URL: {SITE_URL}/rss.xml")

if __name__ == "__main__":
    main()
