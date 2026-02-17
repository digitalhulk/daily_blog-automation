#!/usr/bin/env python3
"""
Social Media Auto-Share for LeadHorizon Blogs
Shares new blog posts to LinkedIn and Facebook automatically
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

def share_to_linkedin(title, url, description, access_token, org_id=None):
    """Share post to LinkedIn Company Page or Personal Profile"""

    if not access_token:
        print("❌ LinkedIn: Access token not configured")
        return False

    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json',
        'X-Restli-Protocol-Version': '2.0.0'
    }

    # Get user/org URN
    if org_id:
        author = f"urn:li:organization:{org_id}"
    else:
        # Get personal profile URN
        me_url = "https://api.linkedin.com/v2/me"
        me_response = requests.get(me_url, headers=headers)
        if me_response.status_code != 200:
            print(f"❌ LinkedIn: Failed to get profile - {me_response.text}")
            return False
        user_id = me_response.json().get('id')
        author = f"urn:li:person:{user_id}"

    # Create post
    post_url = "https://api.linkedin.com/v2/ugcPosts"

    post_data = {
        "author": author,
        "lifecycleState": "PUBLISHED",
        "specificContent": {
            "com.linkedin.ugc.ShareContent": {
                "shareCommentary": {
                    "text": f"📝 New Blog Post!\n\n{title}\n\n{description}\n\n🔗 Read more: {url}\n\n#RealEstateMarketing #DigitalMarketing #LeadGeneration #DelhiNCR #RealEstate"
                },
                "shareMediaCategory": "ARTICLE",
                "media": [
                    {
                        "status": "READY",
                        "originalUrl": url,
                        "title": {
                            "text": title
                        },
                        "description": {
                            "text": description[:200]
                        }
                    }
                ]
            }
        },
        "visibility": {
            "com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"
        }
    }

    try:
        response = requests.post(post_url, headers=headers, json=post_data)
        if response.status_code in [200, 201]:
            print(f"✅ LinkedIn: Posted successfully!")
            return True
        else:
            print(f"❌ LinkedIn: Failed - {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ LinkedIn: Error - {str(e)}")
        return False

def share_to_facebook(title, url, description, access_token, page_id):
    """Share post to Facebook Page"""

    if not access_token or not page_id:
        print("❌ Facebook: Access token or Page ID not configured")
        return False

    post_url = f"https://graph.facebook.com/v18.0/{page_id}/feed"

    message = f"""📝 New Blog Post!

{title}

{description}

🔗 Read the full article: {url}

#RealEstateMarketing #DigitalMarketing #LeadGeneration #DelhiNCR #RealEstate #LeadHorizon"""

    post_data = {
        'message': message,
        'link': url,
        'access_token': access_token
    }

    try:
        response = requests.post(post_url, data=post_data)
        result = response.json()

        if 'id' in result:
            print(f"✅ Facebook: Posted successfully! Post ID: {result['id']}")
            return True
        else:
            print(f"❌ Facebook: Failed - {result.get('error', {}).get('message', 'Unknown error')}")
            return False
    except Exception as e:
        print(f"❌ Facebook: Error - {str(e)}")
        return False

def main():
    print("🚀 Social Media Auto-Share")
    print("=" * 50)

    # Load config
    config = load_config()

    # Load blog metadata
    script_dir = os.path.dirname(os.path.abspath(__file__))
    blog_file = os.path.join(script_dir, 'output', 'latest_blog.json')

    if not os.path.exists(blog_file):
        print("❌ No blog metadata found. Run generate_blog.sh first.")
        sys.exit(1)

    with open(blog_file, 'r') as f:
        blog_data = json.load(f)

    title = blog_data.get('title', 'New Blog Post')
    url = blog_data.get('url', '')

    # Load topic data for description
    topic_file = os.path.join(script_dir, 'output', 'today_topic.json')
    description = "Check out our latest insights on real estate digital marketing."
    if os.path.exists(topic_file):
        with open(topic_file, 'r') as f:
            topic_data = json.load(f)
            description = topic_data.get('market_analysis', description)[:300]

    print(f"📄 Title: {title}")
    print(f"🔗 URL: {url}")
    print("")

    # Share to LinkedIn
    print("📘 Sharing to LinkedIn...")
    linkedin_token = config.get('LINKEDIN_ACCESS_TOKEN', '')
    linkedin_org_id = config.get('LINKEDIN_ORG_ID', '')

    if linkedin_token:
        share_to_linkedin(title, url, description, linkedin_token, linkedin_org_id if linkedin_org_id else None)
    else:
        print("⏭️ LinkedIn: Skipped (no access token)")

    print("")

    # Share to Facebook
    print("📘 Sharing to Facebook...")
    fb_token = config.get('FACEBOOK_PAGE_ACCESS_TOKEN', '')
    fb_page_id = config.get('FACEBOOK_PAGE_ID', '')

    if fb_token and fb_page_id:
        share_to_facebook(title, url, description, fb_token, fb_page_id)
    else:
        print("⏭️ Facebook: Skipped (no access token or page ID)")

    print("")
    print("=" * 50)
    print("✅ Social sharing complete!")

    # Log the share
    log_file = os.path.join(script_dir, 'social_share_log.txt')
    with open(log_file, 'a') as f:
        f.write(f"{datetime.now().isoformat()} | {title} | {url}\n")

if __name__ == "__main__":
    main()
