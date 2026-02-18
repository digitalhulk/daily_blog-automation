#!/usr/bin/env python3
"""
Auto Social Image Generator for LeadHorizon Blog
Creates branded 1200x630 OG images for social sharing using Pillow
"""

import json
import os
import sys
import textwrap
from datetime import datetime

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    PILLOW_AVAILABLE = True
except ImportError:
    PILLOW_AVAILABLE = False
    print("⚠️ Pillow not installed. Run: pip3 install Pillow")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Brand Colors
COLOR_PRIMARY = (128, 0, 0)        # Maroon
COLOR_GOLD = (212, 175, 55)        # Gold
COLOR_DARK = (26, 26, 26)          # Dark
COLOR_WHITE = (255, 255, 255)
COLOR_LIGHT_BG = (245, 240, 235)   # Light warm

# Category Colors
CATEGORY_COLORS = {
    "SEO & Website": (0, 128, 128),
    "Paid Ads": (220, 53, 69),
    "Social Media": (111, 66, 193),
    "Lead Generation": (40, 167, 69),
    "Builder & Developer Tips": (255, 140, 0),
    "Market Trends": (0, 123, 255),
    "AI & Tech": (102, 16, 242),
}

def get_font(size, bold=False):
    """Get best available font"""
    font_paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
    ]

    for fp in font_paths:
        try:
            return ImageFont.truetype(fp, size)
        except (OSError, IOError):
            continue

    return ImageFont.load_default()

def create_social_image(title, category, slug, output_dir):
    """Create a branded 1200x630 social sharing image"""

    if not PILLOW_AVAILABLE:
        print("❌ Cannot generate image - Pillow not installed")
        return None

    W, H = 1200, 630

    # Create base image with gradient background
    img = Image.new('RGB', (W, H), COLOR_DARK)
    draw = ImageDraw.Draw(img)

    # Draw gradient background (dark to darker)
    for y in range(H):
        r = int(26 + (10 * y / H))
        g = int(10 + (5 * y / H))
        b = int(10 + (5 * y / H))
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # Draw decorative elements

    # Top gold accent bar
    draw.rectangle([(0, 0), (W, 6)], fill=COLOR_GOLD)

    # Left maroon accent bar
    draw.rectangle([(0, 0), (8, H)], fill=COLOR_PRIMARY)

    # Bottom gradient bar
    for x in range(W):
        progress = x / W
        r = int(128 * (1 - progress) + 212 * progress)
        g = int(0 * (1 - progress) + 175 * progress)
        b = int(0 * (1 - progress) + 55 * progress)
        draw.line([(x, H - 6), (x, H)], fill=(r, g, b))

    # Decorative circles (subtle)
    for cx, cy, cr in [(1050, 100, 120), (1100, 500, 80), (100, 550, 60)]:
        for i in range(cr, 0, -1):
            alpha = int(15 * (1 - i / cr))
            draw.ellipse(
                [(cx - i, cy - i), (cx + i, cy + i)],
                outline=(128, 0, 0, alpha) if cx > 500 else (212, 175, 55, alpha)
            )

    # Category badge
    cat_color = CATEGORY_COLORS.get(category, COLOR_GOLD)
    font_cat = get_font(22, bold=True)
    cat_text = category.upper()
    cat_bbox = draw.textbbox((0, 0), cat_text, font=font_cat)
    cat_w = cat_bbox[2] - cat_bbox[0] + 30
    cat_h = cat_bbox[3] - cat_bbox[1] + 16

    cat_x, cat_y = 60, 50
    # Badge background
    draw.rounded_rectangle(
        [(cat_x, cat_y), (cat_x + cat_w, cat_y + cat_h)],
        radius=6,
        fill=cat_color
    )
    draw.text((cat_x + 15, cat_y + 6), cat_text, fill=COLOR_WHITE, font=font_cat)

    # Title text (word-wrapped)
    font_title = get_font(52, bold=True)
    title_y = cat_y + cat_h + 35

    # Word wrap title
    max_chars = 28
    lines = textwrap.wrap(title, width=max_chars)
    if len(lines) > 3:
        lines = lines[:3]
        lines[-1] = lines[-1][:max_chars - 3] + "..."

    for i, line in enumerate(lines):
        y_pos = title_y + (i * 68)
        # Text shadow
        draw.text((62, y_pos + 2), line, fill=(0, 0, 0), font=font_title)
        draw.text((60, y_pos), line, fill=COLOR_WHITE, font=font_title)

    # Divider line
    divider_y = title_y + len(lines) * 68 + 20
    draw.line([(60, divider_y), (300, divider_y)], fill=COLOR_GOLD, width=3)

    # LeadHorizon branding
    font_brand = get_font(32, bold=True)
    font_sub = get_font(18)

    brand_y = divider_y + 25
    draw.text((60, brand_y), "Lead", fill=COLOR_WHITE, font=font_brand)
    lead_bbox = draw.textbbox((60, brand_y), "Lead", font=font_brand)
    draw.text((lead_bbox[2], brand_y), "Horizon", fill=COLOR_GOLD, font=font_brand)

    # Subtitle
    draw.text((60, brand_y + 45), "Real Estate Digital Marketing Agency", fill=(180, 180, 180), font=font_sub)

    # Website URL
    font_url = get_font(16)
    draw.text((60, H - 40), "leadhorizon.co.in", fill=COLOR_GOLD, font=font_url)

    # Date
    date_text = datetime.now().strftime("%B %d, %Y")
    date_bbox = draw.textbbox((0, 0), date_text, font=font_url)
    draw.text((W - date_bbox[2] + date_bbox[0] - 40, H - 40), date_text, fill=(150, 150, 150), font=font_url)

    # Save
    output_path = os.path.join(output_dir, f"{slug}.jpg")
    img.save(output_path, "JPEG", quality=90, optimize=True)

    print(f"✅ Social image generated: {output_path}")
    return output_path

def main():
    print("🎨 Social Image Generator")
    print("=" * 50)

    # Load blog data
    blog_file = os.path.join(SCRIPT_DIR, 'output', 'latest_blog.json')
    topic_file = os.path.join(SCRIPT_DIR, 'output', 'today_topic.json')

    if not os.path.exists(blog_file):
        print("❌ No blog metadata found.")
        sys.exit(1)

    with open(blog_file, 'r') as f:
        blog_data = json.load(f)

    category = "Market Trends"
    if os.path.exists(topic_file):
        with open(topic_file, 'r') as f:
            topic_data = json.load(f)
            category = topic_data.get('category', category)

    title = blog_data.get('title', 'New Blog Post')
    slug = blog_data.get('slug', 'blog-post')
    output_dir = os.path.join(SCRIPT_DIR, 'output')

    print(f"📄 Title: {title}")
    print(f"📂 Category: {category}")
    print("")

    image_path = create_social_image(title, category, slug, output_dir)

    if image_path:
        print("")
        print(f"✅ Image saved: {image_path}")
        print(f"📐 Size: 1200x630 (OG standard)")
    else:
        print("❌ Image generation failed")

if __name__ == "__main__":
    main()
