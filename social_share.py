#!/usr/bin/env python3
"""
Social Media Auto-Share for LeadHorizon Blogs
Shares new blog posts to Facebook, LinkedIn, and Instagram automatically
"""

import json
import os
import sys
import requests
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SITE_URL = "https://leadhorizon.co.in"

def load_config():
    """Load configuration from config.sh"""
    config = {}
    config_path = os.path.join(SCRIPT_DIR, 'config.sh')
    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value.strip('"').strip("'")
    return config

def get_category_hashtags(category):
    """Get relevant hashtags based on blog category"""
    base_tags = "#RealEstate #DigitalMarketing #LeadHorizon"
    category_tags = {
        "SEO & Website": "#SEO #WebsiteOptimization #GoogleRanking #LocalSEO",
        "Paid Ads": "#GoogleAds #FacebookAds #PPC #PayPerClick #AdCampaign",
        "Social Media": "#SocialMediaMarketing #Instagram #YouTube #ContentStrategy",
        "Lead Generation": "#LeadGeneration #CRM #SalesAutomation #ConversionOptimization",
        "Builder & Developer Tips": "#Builders #RealEstateDeveloper #RERA #Construction",
        "Market Trends": "#RealEstateMarket #PropertyInvestment #MarketAnalysis #DelhiNCR",
        "AI & Tech": "#PropTech #AIMarketing #Automation #RealEstateTech",
    }
    extra = category_tags.get(category, "#PropertyMarketing #RealEstateIndia")
    return f"{base_tags} {extra}"

# ==================== FACEBOOK ====================

def share_to_facebook(title, url, description, access_token, page_id, category=""):
    """Share post to Facebook Page"""
    if not access_token or not page_id:
        print("  ❌ Access token or Page ID not configured")
        return False

    hashtags = get_category_hashtags(category)

    message = f"""🏠 New Blog Post!

{title}

{description[:250]}

📖 Read the full article: {url}

{hashtags}"""

    post_data = {
        'message': message,
        'link': url,
        'access_token': access_token
    }

    try:
        response = requests.post(
            f"https://graph.facebook.com/v18.0/{page_id}/feed",
            data=post_data,
            timeout=30
        )
        result = response.json()
        if 'id' in result:
            print(f"  ✅ Posted! ID: {result['id']}")
            return True
        else:
            print(f"  ❌ Failed - {result.get('error', {}).get('message', 'Unknown error')}")
            return False
    except Exception as e:
        print(f"  ❌ Error - {str(e)}")
        return False

# ==================== LINKEDIN ====================

def share_to_linkedin(title, url, description, access_token, org_id=None, category=""):
    """Share post to LinkedIn (Company Page or Personal Profile)"""
    if not access_token:
        print("  ❌ Access token not configured")
        return False

    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json',
        'X-Restli-Protocol-Version': '2.0.0'
    }

    # Determine author URN
    if org_id:
        author = f"urn:li:organization:{org_id}"
        print(f"  📌 Posting as Organization: {org_id}")
    else:
        # Try userinfo endpoint first (OpenID Connect)
        author = None
        try:
            r = requests.get("https://api.linkedin.com/v2/userinfo",
                           headers={'Authorization': f'Bearer {access_token}'}, timeout=10)
            if r.status_code == 200:
                user_sub = r.json().get('sub')
                if user_sub:
                    author = f"urn:li:person:{user_sub}"
        except:
            pass

        # Fallback to v2/me
        if not author:
            try:
                r = requests.get("https://api.linkedin.com/v2/me", headers=headers, timeout=10)
                if r.status_code == 200:
                    user_id = r.json().get('id')
                    author = f"urn:li:person:{user_id}"
            except:
                pass

        if not author:
            print("  ❌ Failed to get LinkedIn profile")
            return False
        print(f"  📌 Posting as: {author}")

    hashtags = get_category_hashtags(category)

    post_data = {
        "author": author,
        "lifecycleState": "PUBLISHED",
        "specificContent": {
            "com.linkedin.ugc.ShareContent": {
                "shareCommentary": {
                    "text": f"📝 {title}\n\n{description[:250]}\n\n🔗 Read more: {url}\n\n{hashtags}"
                },
                "shareMediaCategory": "ARTICLE",
                "media": [{
                    "status": "READY",
                    "originalUrl": url,
                    "title": {"text": title},
                    "description": {"text": description[:200]}
                }]
            }
        },
        "visibility": {
            "com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"
        }
    }

    try:
        response = requests.post(
            "https://api.linkedin.com/v2/ugcPosts",
            headers=headers, json=post_data, timeout=30
        )
        if response.status_code in [200, 201]:
            print(f"  ✅ Posted successfully!")
            return True
        else:
            print(f"  ❌ Failed - {response.status_code} - {response.text[:200]}")
            return False
    except Exception as e:
        print(f"  ❌ Error - {str(e)}")
        return False

# ==================== INSTAGRAM ====================

def share_to_instagram(title, url, slug, fb_token, category=""):
    """Share post to Instagram Business Account via Graph API"""
    if not fb_token:
        print("  ❌ Facebook token not configured (needed for Instagram)")
        return False

    # Instagram Business Account ID (linked to Facebook page)
    IG_ACCOUNT_ID = "17841478032746697"

    # Image URL (use the social image uploaded to server)
    image_url = f"{SITE_URL}/images/{slug}.jpg"
    hashtags = get_category_hashtags(category)

    caption = f"""🏠 {title}

Expert insights on real estate digital marketing.

📖 Read more at leadhorizon.co.in (link in bio)

{hashtags} #India #Property"""

    try:
        # Step 1: Create media container
        print("  📤 Creating media container...")
        container_response = requests.post(
            f"https://graph.facebook.com/v18.0/{IG_ACCOUNT_ID}/media",
            data={
                'image_url': image_url,
                'caption': caption,
                'access_token': fb_token
            },
            timeout=30
        )
        container_data = container_response.json()

        if 'id' not in container_data:
            error = container_data.get('error', {}).get('message', 'Unknown')
            print(f"  ❌ Container failed: {error}")
            return False

        container_id = container_data['id']
        print(f"  📦 Container created: {container_id}")

        # Step 2: Publish the container
        print("  📱 Publishing to Instagram...")
        publish_response = requests.post(
            f"https://graph.facebook.com/v18.0/{IG_ACCOUNT_ID}/media_publish",
            data={
                'creation_id': container_id,
                'access_token': fb_token
            },
            timeout=30
        )
        publish_data = publish_response.json()

        if 'id' in publish_data:
            print(f"  ✅ Posted! Media ID: {publish_data['id']}")
            return True
        else:
            error = publish_data.get('error', {}).get('message', 'Unknown')
            print(f"  ❌ Publish failed: {error}")
            return False

    except Exception as e:
        print(f"  ❌ Error - {str(e)}")
        return False

# ==================== MAIN ====================

def main():
    print("🚀 Social Media Auto-Share")
    print("=" * 60)

    config = load_config()

    # Load blog metadata
    blog_file = os.path.join(SCRIPT_DIR, 'output', 'latest_blog.json')
    if not os.path.exists(blog_file):
        print("❌ No blog metadata found. Run generate_blog.sh first.")
        sys.exit(1)

    with open(blog_file, 'r') as f:
        blog_data = json.load(f)

    title = blog_data.get('title', 'New Blog Post')
    url = blog_data.get('url', '')
    slug = blog_data.get('slug', '')

    # Load topic data for description & category
    topic_file = os.path.join(SCRIPT_DIR, 'output', 'today_topic.json')
    description = "Expert insights on real estate digital marketing for builders and developers."
    category = "Market Trends"
    if os.path.exists(topic_file):
        with open(topic_file, 'r') as f:
            topic_data = json.load(f)
            description = topic_data.get('market_analysis', description)[:300]
            category = topic_data.get('category', category)

    print(f"📄 Title: {title}")
    print(f"🔗 URL: {url}")
    print(f"📂 Category: {category}")
    print("")

    results = {}

    # 1. Facebook
    print("📘 Facebook Page:")
    fb_token = config.get('FACEBOOK_PAGE_ACCESS_TOKEN', '')
    fb_page_id = config.get('FACEBOOK_PAGE_ID', '')
    if fb_token and fb_page_id:
        results['facebook'] = share_to_facebook(title, url, description, fb_token, fb_page_id, category)
    else:
        print("  ⏭️ Skipped (not configured)")
        results['facebook'] = None
    print("")

    # 2. LinkedIn
    print("💼 LinkedIn:")
    li_token = config.get('LINKEDIN_ACCESS_TOKEN', '')
    li_org_id = config.get('LINKEDIN_ORG_ID', '')
    if li_token:
        results['linkedin'] = share_to_linkedin(title, url, description, li_token, li_org_id or None, category)
    else:
        print("  ⏭️ Skipped (not configured)")
        results['linkedin'] = None
    print("")

    # 3. Instagram
    print("📸 Instagram:")
    if fb_token:
        results['instagram'] = share_to_instagram(title, url, slug, fb_token, category)
    else:
        print("  ⏭️ Skipped (Facebook token needed for IG API)")
        results['instagram'] = None
    print("")

    # Summary
    print("=" * 60)
    print("📊 Share Summary:")
    for platform, status in results.items():
        icon = "✅" if status == True else "❌" if status == False else "⏭️"
        print(f"  {icon} {platform.capitalize()}")

    # Log
    log_file = os.path.join(SCRIPT_DIR, 'social_share_log.txt')
    platforms_shared = [k for k, v in results.items() if v == True]
    with open(log_file, 'a') as f:
        f.write(f"{datetime.now().isoformat()} | {title} | {', '.join(platforms_shared) or 'none'} | {url}\n")

    print("")
    print("✅ Social sharing complete!")

if __name__ == "__main__":
    main()
