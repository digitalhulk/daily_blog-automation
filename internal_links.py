#!/usr/bin/env python3
"""
Internal Linking Engine for LeadHorizon Blog
Adds 'Related Articles' section to new blog and updates old blogs with links to new one
"""

import json
import os
import sys
import subprocess
import re
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SITE_URL = "https://leadhorizon.co.in"

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

def get_blog_list_from_server(config):
    """Get list of existing blog files from server"""
    ssh_host = config.get('SSH_HOST', '')
    ssh_port = config.get('SSH_PORT', '22')
    ssh_user = config.get('SSH_USER', '')
    ssh_pass = config.get('SSH_PASS', '')
    remote_path = config.get('REMOTE_PATH', '')

    cmd = f'sshpass -p "{ssh_pass}" ssh -o StrictHostKeyChecking=no -p {ssh_port} "{ssh_user}@{ssh_host}" "ls -1t {remote_path}/blog/*.html 2>/dev/null | head -20"'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)

    if result.returncode == 0:
        files = [f.strip() for f in result.stdout.strip().split('\n') if f.strip()]
        return files
    return []

def get_blog_title_from_server(config, filepath):
    """Extract title from a remote blog file"""
    ssh_host = config.get('SSH_HOST', '')
    ssh_port = config.get('SSH_PORT', '22')
    ssh_user = config.get('SSH_USER', '')
    ssh_pass = config.get('SSH_PASS', '')

    cmd = f'sshpass -p "{ssh_pass}" ssh -o StrictHostKeyChecking=no -p {ssh_port} "{ssh_user}@{ssh_host}" "grep -o \'<title>[^<]*</title>\' {filepath} | head -1"'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

    if result.returncode == 0 and result.stdout.strip():
        title = result.stdout.strip()
        title = re.sub(r'</?title>', '', title)
        # Remove site name suffix
        title = re.split(r'\s*[|–-]\s*LeadHorizon', title)[0].strip()
        return title
    return None

def inject_related_articles_into_new_blog(blog_file, related_blogs):
    """Add Related Articles section to the new blog post before </body>"""
    if not related_blogs or not os.path.exists(blog_file):
        return False

    with open(blog_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if related articles already exist
    if 'related-articles' in content:
        print("  ⏭️ Related articles section already exists")
        return True

    # Build related articles HTML
    cards = ""
    for blog in related_blogs[:3]:
        filename = os.path.basename(blog['path'])
        title = blog['title']
        cards += f'''
                <a href="{filename}" class="related-card">
                    <span class="related-icon"><i class="fas fa-newspaper"></i></span>
                    <span class="related-title">{title}</span>
                    <span class="related-arrow"><i class="fas fa-arrow-right"></i></span>
                </a>'''

    related_html = f'''
    <!-- Related Articles -->
    <div class="related-articles" style="max-width:800px;margin:40px auto;padding:0 20px;">
        <h2 style="font-family:'Montserrat',sans-serif;font-size:1.6rem;color:#800000;margin-bottom:20px;padding-bottom:10px;border-bottom:2px solid #d4af37;">Related Articles</h2>
        <div style="display:flex;flex-direction:column;gap:12px;">
            {cards}
        </div>
    </div>
    <style>
    .related-card {{
        display:flex;align-items:center;gap:15px;padding:15px 20px;background:#f9f5f0;
        border-radius:8px;text-decoration:none;color:#1a1a1a;transition:all 0.3s;
        border-left:3px solid #d4af37;
    }}
    .related-card:hover {{background:#800000;color:#fff;border-left-color:#d4af37;transform:translateX(5px);}}
    .related-card:hover .related-icon,.related-card:hover .related-arrow {{color:#d4af37;}}
    .related-icon {{color:#800000;font-size:1.2rem;flex-shrink:0;}}
    .related-title {{flex:1;font-family:'Poppins',sans-serif;font-size:0.95rem;font-weight:500;}}
    .related-arrow {{color:#800000;flex-shrink:0;}}
    </style>
'''

    # Insert before </body>
    content = content.replace('</body>', f'{related_html}\n</body>')

    with open(blog_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"  ✅ Added {len(related_blogs[:3])} related articles to new blog")
    return True

def add_backlink_to_old_blog(config, old_blog_path, new_title, new_filename):
    """Add a link to the new blog in an older blog's Related Articles section"""
    ssh_host = config.get('SSH_HOST', '')
    ssh_port = config.get('SSH_PORT', '22')
    ssh_user = config.get('SSH_USER', '')
    ssh_pass = config.get('SSH_PASS', '')

    # Check if old blog already links to new blog
    check_cmd = f'sshpass -p "{ssh_pass}" ssh -o StrictHostKeyChecking=no -p {ssh_port} "{ssh_user}@{ssh_host}" "grep -c \'{new_filename}\' {old_blog_path} 2>/dev/null || echo 0"'
    result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True, timeout=10)

    if result.stdout.strip() != '0':
        return False  # Already linked

    # Add a simple "You might also like" link before </body> if no related section exists
    backlink_html = f'<div style="max-width:800px;margin:20px auto;padding:10px 20px;"><p style="font-family:Poppins,sans-serif;font-size:0.9rem;color:#666;">📖 Also read: <a href="{new_filename}" style="color:#800000;font-weight:500;">{new_title}</a></p></div>'

    escaped_html = backlink_html.replace("'", "'\\''").replace('"', '\\"')

    cmd = f'sshpass -p "{ssh_pass}" ssh -o StrictHostKeyChecking=no -p {ssh_port} "{ssh_user}@{ssh_host}" "sed -i \\"/<\\/body>/i {escaped_html}\\" {old_blog_path}"'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

    return result.returncode == 0

def main():
    print("🔗 Internal Linking Engine")
    print("=" * 50)

    config = load_config()

    # Load new blog data
    blog_file_json = os.path.join(SCRIPT_DIR, 'output', 'latest_blog.json')
    if not os.path.exists(blog_file_json):
        print("❌ No blog metadata found.")
        sys.exit(1)

    with open(blog_file_json, 'r') as f:
        blog_data = json.load(f)

    new_title = blog_data.get('title', '')
    new_filename = blog_data.get('filename', '')
    new_slug = blog_data.get('slug', '')
    local_html = os.path.join(SCRIPT_DIR, 'output', new_filename)

    print(f"📄 New Blog: {new_title}")
    print(f"📁 File: {new_filename}")
    print("")

    # Get existing blogs from server
    print("📥 Fetching existing blogs from server...")
    remote_blogs = get_blog_list_from_server(config)
    remote_path = config.get('REMOTE_PATH', '')

    if not remote_blogs:
        print("  ⚠️ No existing blogs found on server")
        print("✅ Internal linking complete (first blog)")
        return

    # Filter out the current blog
    related_blogs = []
    for blog_path in remote_blogs:
        fname = os.path.basename(blog_path)
        if fname == new_filename:
            continue

        title = get_blog_title_from_server(config, blog_path)
        if title:
            related_blogs.append({
                'path': blog_path,
                'filename': fname,
                'title': title
            })

        if len(related_blogs) >= 5:
            break

    print(f"  📚 Found {len(related_blogs)} existing blogs")
    print("")

    # 1. Add related articles to new blog (local file before deploy)
    print("📝 Adding related articles to new blog...")
    if os.path.exists(local_html):
        inject_related_articles_into_new_blog(local_html, related_blogs)
    else:
        print(f"  ⚠️ Local HTML not found: {local_html}")
    print("")

    # 2. Add backlinks in recent old blogs pointing to new blog
    print("🔙 Adding backlinks in older blogs...")
    backlink_count = 0
    for blog in related_blogs[:3]:
        if add_backlink_to_old_blog(config, blog['path'], new_title, new_filename):
            print(f"  ✅ Backlink added in: {blog['filename']}")
            backlink_count += 1

    if backlink_count == 0:
        print("  ℹ️ No new backlinks needed (already linked or no blogs)")
    print("")

    # Log
    log_file = os.path.join(SCRIPT_DIR, 'internal_links_log.txt')
    with open(log_file, 'a') as f:
        f.write(f"{datetime.now().isoformat()} | {new_filename} | related:{len(related_blogs[:3])} | backlinks:{backlink_count}\n")

    print("✅ Internal linking complete!")

if __name__ == "__main__":
    main()
