#!/bin/bash
# Blog Content Generator using Ollama
# Generates SEO-optimized blog content for LeadHorizon

source "$(dirname "$0")/config.sh"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get random topic from topics file (skip comments and empty lines)
get_random_topic() {
    # Use gshuf on macOS, shuf on Linux
    if command -v gshuf &> /dev/null; then
        grep -v "^#" "$TOPICS_FILE" | grep -v "^$" | gshuf -n 1
    else
        grep -v "^#" "$TOPICS_FILE" | grep -v "^$" | shuf -n 1
    fi
}

# Generate slug from title
generate_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Get current date info
TODAY=$(date +%Y-%m-%d)
TODAY_DISPLAY=$(date +"%B %d, %Y")
YEAR=$(date +%Y)

# Check for trend-based topic first
TREND_TOPIC_FILE="$OUTPUT_DIR/today_topic.json"
if [ -f "$TREND_TOPIC_FILE" ]; then
    echo "📈 Using trend-based topic..."
    TOPIC=$(python3 -c "import json; d=json.load(open('$TREND_TOPIC_FILE')); print(d.get('topic',''))")
    PRIMARY_KEYWORD=$(python3 -c "import json; d=json.load(open('$TREND_TOPIC_FILE')); print(d.get('primary_keyword',''))")
    SECONDARY_KEYWORDS=$(python3 -c "import json; d=json.load(open('$TREND_TOPIC_FILE')); print(d.get('secondary_keywords',''))")
    MARKET_ANALYSIS=$(python3 -c "import json; d=json.load(open('$TREND_TOPIC_FILE')); print(d.get('market_analysis',''))")
    CATEGORY=$(python3 -c "import json; d=json.load(open('$TREND_TOPIC_FILE')); print(d.get('category','Real Estate'))")
    # Get Perplexity research if available
    PERPLEXITY_RESEARCH=$(python3 -c "import json; d=json.load(open('$TREND_TOPIC_FILE')); print(d.get('perplexity_research',''))" 2>/dev/null || echo "")
    if [ -n "$PERPLEXITY_RESEARCH" ]; then
        echo "🔬 Using Perplexity research data..."
    fi
else
    echo "📝 Using random topic from list..."
    TOPIC_LINE=$(get_random_topic)
    TOPIC=$(echo "$TOPIC_LINE" | cut -d'|' -f1)
    PRIMARY_KEYWORD=$(echo "$TOPIC_LINE" | cut -d'|' -f2)
    SECONDARY_KEYWORDS=$(echo "$TOPIC_LINE" | cut -d'|' -f3)
    MARKET_ANALYSIS=""
    PERPLEXITY_RESEARCH=""

    # Auto-detect category from topic keywords
    TOPIC_LOWER=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]')
    KW_LOWER=$(echo "$PRIMARY_KEYWORD" | tr '[:upper:]' '[:lower:]')
    CMB="$TOPIC_LOWER $KW_LOWER"
    if echo "$CMB" | grep -qiE "builder|developer|construction|rera|project launch|referral.*builder"; then
        CATEGORY="Builder & Developer Tips"
    elif echo "$CMB" | grep -qiE "seo|ranking|google my business|gmb|local seo|website|landing page|voice search"; then
        CATEGORY="SEO & Website"
    elif echo "$CMB" | grep -qiE "google ads|facebook ads|ppc|retarget|remarketing|ad budget|ad campaign|paid"; then
        CATEGORY="Paid Ads"
    elif echo "$CMB" | grep -qiE "instagram|youtube|linkedin|social media|reels|shorts|influencer|whatsapp"; then
        CATEGORY="Social Media"
    elif echo "$CMB" | grep -qiE "lead gen|lead nurtur|lead scor|crm|email marketing|chatbot|conversion|follow.up"; then
        CATEGORY="Lead Generation"
    elif echo "$CMB" | grep -qiE "ai |artificial intelligence|automation|chatgpt|machine learning|virtual tour|3d|proptech"; then
        CATEGORY="AI & Tech"
    else
        CATEGORY="Market Trends"
    fi
fi

echo "📝 Generating blog for: $TOPIC"
echo "🔑 Primary Keyword: $PRIMARY_KEYWORD"

# Generate slug
SLUG=$(generate_slug "$TOPIC")
FILENAME="${SLUG}.html"

echo "📄 Filename: $FILENAME"

# Prompt for Ollama
PROMPT="You are an expert SEO content writer for LeadHorizon, a real estate digital marketing agency in Delhi NCR, India.

Write a comprehensive, SEO-optimized blog article about: \"$TOPIC\"

Primary keyword: $PRIMARY_KEYWORD
Secondary keywords: $SECONDARY_KEYWORDS

Requirements:
1. Write 1500-2000 words
2. Use the primary keyword naturally 5-7 times throughout the article
3. Include H2 and H3 headings with keywords
4. Write engaging introduction with hook
5. Include actionable tips and real examples
6. Add statistics and data where relevant (use realistic numbers)
7. Write for builders and real estate developers in India
8. Include a call-to-action for LeadHorizon services
9. Use simple, professional language
10. Focus on providing genuine value

Output format:
<title>SEO Title (under 60 characters)</title>
<meta_description>Meta description (under 160 characters)</meta_description>
<content>
Your full HTML content here with proper h2, h3, p, ul, li tags
</content>"

# Generate content with Ollama API (cleaner output than CLI)
echo "🤖 Generating content with Ollama..."

# Build market context for prompt
MARKET_CONTEXT=""
if [ -n "$MARKET_ANALYSIS" ]; then
    MARKET_CONTEXT="Market Context: $MARKET_ANALYSIS"
fi

# Build research context from Perplexity
RESEARCH_CONTEXT=""
if [ -n "$PERPLEXITY_RESEARCH" ]; then
    RESEARCH_CONTEXT="$PERPLEXITY_RESEARCH"
fi

# Create JSON payload using Python for proper escaping
PAYLOAD_FILE="/tmp/ollama_payload_$$.json"
TODAY_DATE=$(date '+%B %d, %Y')

# Save research to temp file for Python to read
echo "$PERPLEXITY_RESEARCH" > /tmp/perplexity_research_$$.txt

python3 << PYPAYLOAD
import json

# Read Perplexity research from temp file
try:
    with open('/tmp/perplexity_research_$$.txt', 'r') as f:
        perplexity_research = f.read().strip()
except:
    perplexity_research = ""

research_section = ""
if perplexity_research:
    research_section = f"""

=== REAL-TIME MARKET RESEARCH (from Perplexity AI) ===
Use this research data to make your article factual and current:

{perplexity_research}

=== END RESEARCH ===

IMPORTANT: Incorporate the above statistics, trends, and facts into your article. Cite specific numbers and data points from the research.
"""

prompt = f"""You are an expert SEO content writer for LeadHorizon, a real estate digital marketing agency in Delhi NCR, India. Today's date is $TODAY_DATE.

Write a LONG, comprehensive, SEO-optimized blog article about: "$TOPIC"

Primary keyword: $PRIMARY_KEYWORD
Secondary keywords: $SECONDARY_KEYWORDS

$MARKET_CONTEXT
{research_section}

CRITICAL LENGTH REQUIREMENT:
- You MUST write AT LEAST 1500 words
- Each H2 section must have 200-300 words minimum
- Include 6 detailed H2 sections
- This is a LONG-FORM article, not a short post

STRICT REQUIREMENTS:
1. Write MINIMUM 1500-2000 words (CRITICAL - do not stop early)
2. Use the primary keyword naturally 6-8 times throughout
3. Structure with exactly 6 H2 sections, each with 2-3 H3 subsections
4. NEVER use H1 tag (the page already has H1 in hero section)
5. Every list must have MINIMUM 5 bullet points
6. Each section must have at least 200 words with detailed explanations
7. Include 4-5 statistics with specific numbers (percentages, rupee amounts)
8. Add real examples from Delhi NCR market (Gurgaon, Noida, Greater Noida)
9. Write for builders and real estate developers in India
10. End with strong call-to-action paragraph for LeadHorizon

HTML FORMATTING RULES:
- Use ONLY these HTML tags: <h2>, <h3>, <p>, <ul>, <li>, <strong>, <em>
- NO markdown syntax (no **, no *, no ###)
- NO <h1> tags
- Wrap every paragraph in <p> tags
- Use <ul><li> for all bullet lists

OUTPUT FORMAT (follow exactly):
<title>SEO Title under 60 chars</title>
<meta_description>Compelling description under 155 chars</meta_description>
<content>
<h2>First Section Heading</h2>
<p>Long detailed paragraph here...</p>
<h3>Subsection</h3>
<p>More content...</p>
<ul>
<li>Point one</li>
<li>Point two</li>
<li>Point three</li>
<li>Point four</li>
<li>Point five</li>
</ul>
</content>"""

payload = {
    "model": "$OLLAMA_MODEL",
    "prompt": prompt,
    "stream": False,
    "options": {
        "num_predict": 4096,
        "temperature": 0.7
    }
}

with open("$PAYLOAD_FILE", "w") as f:
    json.dump(payload, f)

print("Payload created")
PYPAYLOAD

# Call Ollama API (max 5 min timeout to prevent hanging)
echo "📡 Calling Ollama API..."
API_RESPONSE=$(curl -s --max-time 300 http://localhost:11434/api/generate -d @"$PAYLOAD_FILE" 2>/dev/null)
RESPONSE=$(echo "$API_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response',''))" 2>/dev/null)

# Debug: Show response length
echo "📊 Response length: ${#RESPONSE} characters"

# Cleanup
rm -f "$PAYLOAD_FILE"

# Extract parts from response using Python for reliability
# Save response to temp file first
RESPONSE_FILE="/tmp/ollama_response_$$.txt"
echo "$RESPONSE" > "$RESPONSE_FILE"

# Extract using Python
EXTRACTION_RESULT=$(python3 - "$RESPONSE_FILE" << 'PYEXTRACT'
import re
import sys

# Read response from file passed as argument
response_file = sys.argv[1]
with open(response_file, "r") as f:
    response = f.read()

# Extract title
title_match = re.search(r'<title>(.*?)</title>', response, re.DOTALL | re.IGNORECASE)
title = title_match.group(1).strip() if title_match else ""

# Extract meta description
meta_match = re.search(r'<meta_description>(.*?)</meta_description>', response, re.DOTALL | re.IGNORECASE)
meta = meta_match.group(1).strip() if meta_match else ""

# Extract content - get everything between <content> tags
content_match = re.search(r'<content>(.*?)</content>', response, re.DOTALL | re.IGNORECASE)
if content_match:
    content = content_match.group(1).strip()
else:
    # If no content tags, use the whole response but clean it up
    content = response
    # Remove the title and meta tags from content
    content = re.sub(r'<title>.*?</title>', '', content, flags=re.DOTALL | re.IGNORECASE)
    content = re.sub(r'<meta_description>.*?</meta_description>', '', content, flags=re.DOTALL | re.IGNORECASE)
    content = content.strip()

# CLEANUP: Remove any remaining <content> tags
content = re.sub(r'</?content>', '', content, flags=re.IGNORECASE)

# CLEANUP: Remove any H1 tags (page already has H1 in hero)
content = re.sub(r'<h1[^>]*>.*?</h1>', '', content, flags=re.DOTALL | re.IGNORECASE)

# Convert markdown headings to HTML
content = re.sub(r'^### (.+)$', r'<h3>\1</h3>', content, flags=re.MULTILINE)
content = re.sub(r'^## (.+)$', r'<h2>\1</h2>', content, flags=re.MULTILINE)

# Convert markdown bold/italic to HTML
content = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', content)
content = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', r'<em>\1</em>', content)

# Convert markdown bullet lists to HTML
lines = content.split('\n')
new_lines = []
in_list = False
for line in lines:
    stripped = line.strip()
    # Check for bullet point (*, -, or numbered)
    bullet_match = re.match(r'^[\*\-]\s+(.+)$', stripped)
    num_match = re.match(r'^\d+\.\s+(.+)$', stripped)

    if bullet_match:
        if not in_list:
            new_lines.append('<ul>')
            in_list = True
        new_lines.append(f'<li>{bullet_match.group(1)}</li>')
    elif num_match:
        if not in_list:
            new_lines.append('<ol>')
            in_list = 'ol'
        new_lines.append(f'<li>{num_match.group(1)}</li>')
    else:
        if in_list:
            if in_list == 'ol':
                new_lines.append('</ol>')
            else:
                new_lines.append('</ul>')
            in_list = False
        new_lines.append(line)

if in_list:
    new_lines.append('</ul>' if in_list != 'ol' else '</ol>')

content = '\n'.join(new_lines)

# Wrap standalone text paragraphs in <p> tags
# Split by double newlines and wrap if not already tagged
paragraphs = re.split(r'\n\s*\n', content)
wrapped = []
for p in paragraphs:
    p = p.strip()
    if not p:
        continue
    # Check if already has HTML tags
    if re.match(r'^<(h[2-6]|p|ul|ol|li|div|blockquote)', p):
        wrapped.append(p)
    elif p.startswith('<'):
        wrapped.append(p)
    else:
        # Wrap in <p> if it's plain text
        wrapped.append(f'<p>{p}</p>')

content = '\n\n'.join(wrapped)

# Clean up any double tags or empty paragraphs
content = re.sub(r'<p>\s*</p>', '', content)
content = re.sub(r'<p>\s*<(h[2-6]|ul|ol)', r'<\1', content)
content = re.sub(r'</(h[2-6]|ul|ol)>\s*</p>', r'</\1>', content)

print("---TITLE_START---")
print(title)
print("---TITLE_END---")
print("---META_START---")
print(meta)
print("---META_END---")
print("---CONTENT_START---")
print(content)
print("---CONTENT_END---")
PYEXTRACT
)

# Parse the extraction result
SEO_TITLE=$(echo "$EXTRACTION_RESULT" | sed -n '/---TITLE_START---/,/---TITLE_END---/p' | grep -v "^---" | head -1)
META_DESC=$(echo "$EXTRACTION_RESULT" | sed -n '/---META_START---/,/---META_END---/p' | grep -v "^---" | head -1)
CONTENT=$(echo "$EXTRACTION_RESULT" | sed -n '/---CONTENT_START---/,/---CONTENT_END---/p' | grep -v "^---")

# Cleanup temp file
rm -f "$RESPONSE_FILE"

# Fallback if extraction fails
if [ -z "$SEO_TITLE" ]; then
    SEO_TITLE="$TOPIC | LeadHorizon"
fi

if [ -z "$META_DESC" ]; then
    META_DESC="Learn about $TOPIC. Expert insights from LeadHorizon, Delhi NCR's leading real estate digital marketing agency."
fi

if [ -z "$CONTENT" ]; then
    echo "❌ Content generation failed. Using fallback content."
    CONTENT="<p>Content generation error. Please regenerate.</p>"
fi

# Calculate read time (avg 200 words per minute)
WORD_COUNT=$(echo "$CONTENT" | wc -w | xargs)
READ_TIME=$((WORD_COUNT / 200))
if [ $READ_TIME -lt 1 ]; then READ_TIME=1; fi

echo "📊 Word count: $WORD_COUNT, Read time: $READ_TIME min"

# Generate tags from secondary keywords + category
TAGS_HTML=""
IFS=',' read -ra TAG_ARRAY <<< "$SECONDARY_KEYWORDS"
for tag in "${TAG_ARRAY[@]}"; do
    tag=$(echo "$tag" | xargs) # trim whitespace
    if [ -n "$tag" ]; then
        TAGS_HTML="${TAGS_HTML}<span class=\"blog-tag\">${tag}</span>"
    fi
done
# Add category as first tag
TAGS_HTML="<span class=\"blog-tag blog-tag-primary\">${CATEGORY}</span>${TAGS_HTML}"

# Download unique featured image from Unsplash
echo "🖼️ Downloading unique featured image..."
FEATURED_IMAGE="${SLUG}.jpg"
IMAGE_PATH="$OUTPUT_DIR/${FEATURED_IMAGE}"

# Implement Dynamic Image Selection using Unsplash Source API
echo "🖼️ Downloading dynamic featured image for: $PRIMARY_KEYWORD"

# URL encode the keyword for the API
ENCODED_KEYWORD=$(echo "$PRIMARY_KEYWORD" | sed 's/ /%20/g')
IMAGE_URL="https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=1200&h=630&fit=crop" # Default fallback

# Try to get a relevant image from Unsplash Source (redirects to actual image)
# We use a trick to get the redirected URL or download directly
# Since source.unsplash.com is deprecated, we use the search API pattern or high-quality collection

# Alternative: Use a specific collection of Real Estate images but randomize
# or use a reliable search endpoint if available without API key (difficult now with Unsplash changes)

# STRATEGY: Use a large list of specific high-quality images mapped to categories, 
# OR use the 'source.unsplash.com/1200x630/?real+estate' pattern which might still work for some,
# BUT for stability, let's use a bigger, categorized list.

# BETTER STRATEGY: 
# 1. Try to find a relevant image using a keyword search pattern (if supported publicly)
# 2. Fallback to a large, diverse set of pre-defined images.

# Let's try the source API pattern first, as it's the most dynamic.
# Note: source.unsplash.com is officially deprecated but often still works or redirects.
# If it fails, we fall back to the list.

DYNAMIC_URL="https://source.unsplash.com/1200x630/?real-estate,${ENCODED_KEYWORD}"

echo "Trying dynamic URL: $DYNAMIC_URL"
curl -sL "$DYNAMIC_URL" -o "$IMAGE_PATH" 2>/dev/null

# Verify download
FILE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null || echo "0")

if [ "$FILE_SIZE" -lt 10000 ]; then
    echo "⚠️ Dynamic image failed (size: ${FILE_SIZE}), using curated list..."
    
    # Extended list of high-quality real estate images
    REAL_ESTATE_IMAGES=(
        "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=1200&h=630&fit=crop" # Modern Building
        "https://images.unsplash.com/photo-1582407947304-fd86f028f716?w=1200&h=630&fit=crop" # Luxury Home
        "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1200&h=630&fit=crop" # Villa
        "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200&h=630&fit=crop" # Modern Interface
        "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200&h=630&fit=crop" # Apartment
        "https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=1200&h=630&fit=crop" # House
        "https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1200&h=630&fit=crop" # Interior
        "https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=1200&h=630&fit=crop" # Kitchen
        "https://images.unsplash.com/photo-1600573472550-8090b5e0745e?w=1200&h=630&fit=crop" # Living Room
        "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1200&h=630&fit=crop" # Mansion
        "https://images.unsplash.com/photo-1599809275311-2cd01545d71a?w=1200&h=630&fit=crop" # Blue Skyscraper
        "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1200&h=630&fit=crop" # Glass Building
        "https://images.unsplash.com/photo-1448630360428-65456885c650?w=1200&h=630&fit=crop" # Cozy Home
        "https://images.unsplash.com/photo-1502005229766-52835791e889?w=1200&h=630&fit=crop" # Tree House
        "https://images.unsplash.com/photo-1494526585095-c41746248156?w=1200&h=630&fit=crop" # Suburban
    )
    
    # Select random from list
    SELECTED_IMAGE=${REAL_ESTATE_IMAGES[$RANDOM % ${#REAL_ESTATE_IMAGES[@]}]}
    curl -sL "$SELECTED_IMAGE" -o "$IMAGE_PATH" 2>/dev/null
    
    FILE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -lt 10000 ]; then
        echo "❌ Fallback image download failed"
        # Ultimate fallback - copy a local asset if available or just touch for now (not ideal but prevents crash)
    else
        echo "✅ Curated image downloaded (${FILE_SIZE} bytes)"
    fi
else
    echo "✅ Dynamic image downloaded (${FILE_SIZE} bytes)"
fi

# Create SEO-optimized ALT tag
ALT_TAG="${SEO_TITLE} - ${PRIMARY_KEYWORD} Guide for Real Estate Developers | LeadHorizon Delhi NCR"
echo "✅ Featured image: $FEATURED_IMAGE"

# Create the HTML file
cat > "$OUTPUT_DIR/$FILENAME" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Meta Pixel Code -->
    <script>
    !function(f,b,e,v,n,t,s)
    {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
    n.callMethod.apply(n,arguments):n.queue.push(arguments)};
    if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
    n.queue=[];t=b.createElement(e);t.async=!0;
    t.src=v;s=b.getElementsByTagName(e)[0];
    s.parentNode.insertBefore(t,s)}(window, document,'script',
    'https://connect.facebook.net/en_US/fbevents.js');
    fbq('init', '1757208528507004');
    fbq('track', 'PageView');
    </script>
    <noscript><img height="1" width="1" style="display:none"
    src="https://www.facebook.com/tr?id=1757208528507004&ev=PageView&noscript=1"
    /></noscript>
    <!-- End Meta Pixel Code -->
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${SEO_TITLE} | LeadHorizon</title>
    <meta name="description" content="${META_DESC}">
    <meta name="keywords" content="${PRIMARY_KEYWORD}, ${SECONDARY_KEYWORDS}">
    <link rel="canonical" href="${SITE_URL}/blog/${FILENAME}">
    <link rel="icon" type="image/svg+xml" href="../favicon.svg">

    <meta property="og:type" content="article">
    <meta property="og:title" content="${SEO_TITLE}">
    <meta property="og:description" content="${META_DESC}">
    <meta property="og:url" content="${SITE_URL}/blog/${FILENAME}">
    <meta property="og:image" content="${SITE_URL}/images/${SLUG}.jpg">
    <meta property="article:published_time" content="${TODAY}T10:00:00+05:30">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@700;800&family=Poppins:wght@400;500;600&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="../style.css?v=11">

    <style>
        /* Reading Progress Bar */
        .reading-progress{position:fixed;top:0;left:0;width:0;height:3px;background:linear-gradient(90deg,var(--gold),var(--primary));z-index:9999;transition:width .1s}

        /* Hero */
        .blog-article-hero{background:linear-gradient(135deg,var(--primary) 0%,var(--primary-dark) 100%);padding:150px 0 80px;color:var(--white)}.blog-article-hero .badge{background:var(--gold);color:var(--dark)}.blog-article-hero h1{font-family:'Montserrat',sans-serif;font-size:2.8rem;margin:20px 0;line-height:1.3}.blog-meta-info{display:flex;gap:25px;margin-top:25px;font-size:.95rem;opacity:.9}.blog-meta-info i{margin-right:8px}

        /* Tags */
        .blog-tags{display:flex;flex-wrap:wrap;gap:8px;margin-top:20px}.blog-tag{display:inline-block;padding:5px 14px;border-radius:20px;font-size:.8rem;font-weight:500;background:rgba(255,255,255,.15);color:var(--white);border:1px solid rgba(255,255,255,.25)}.blog-tag-primary{background:var(--gold);color:var(--dark);border-color:var(--gold);font-weight:600}

        /* Featured Image */
        .featured-image{width:100%;max-width:800px;margin:0 auto -40px;padding:0 20px;position:relative;z-index:10}.featured-image img{width:100%;height:400px;object-fit:cover;border-radius:15px;box-shadow:0 10px 40px rgba(0,0,0,0.2)}

        /* Social Share Bar */
        .social-share-bar{display:flex;align-items:center;gap:12px;padding:20px 0;margin:30px 0;border-top:1px solid #eee;border-bottom:1px solid #eee}.social-share-bar span{font-size:.9rem;font-weight:600;color:var(--dark)}.share-btn{display:inline-flex;align-items:center;justify-content:center;width:40px;height:40px;border-radius:50%;border:none;cursor:pointer;font-size:1rem;color:#fff;transition:transform .2s,opacity .2s}.share-btn:hover{transform:scale(1.1);opacity:.9}.share-btn.whatsapp{background:#25D366}.share-btn.facebook{background:#1877F2}.share-btn.linkedin{background:#0A66C2}.share-btn.twitter{background:#1DA1F2}.share-btn.copy-link{background:var(--dark);font-size:.85rem}

        /* Table of Contents */
        .toc-container{background:linear-gradient(135deg,#f8f9fa,#fff);border:1px solid #e9ecef;border-left:4px solid var(--primary);border-radius:0 12px 12px 0;padding:25px 30px;margin:0 0 40px}.toc-container h4{font-family:'Montserrat',sans-serif;font-size:1.1rem;color:var(--dark);margin-bottom:15px;display:flex;align-items:center;gap:8px}.toc-container h4 i{color:var(--primary)}.toc-container ol{margin:0;padding-left:20px;counter-reset:toc}.toc-container li{margin-bottom:10px;line-height:1.6}.toc-container a{color:var(--text-light);text-decoration:none;font-size:.95rem;transition:color .2s}.toc-container a:hover{color:var(--primary)}

        /* Article Content */
        .article-content{padding:80px 0;max-width:800px;margin:0 auto}.article-content h2{font-family:'Montserrat',sans-serif;font-size:1.8rem;color:var(--dark);margin:50px 0 20px}.article-content h3{font-size:1.3rem;color:var(--dark);margin:35px 0 15px}.article-content p{color:var(--text-light);font-size:1.05rem;line-height:1.9;margin-bottom:20px}.article-content ul,.article-content ol{color:var(--text-light);margin:20px 0 20px 25px;line-height:2}.article-content a{color:var(--primary);text-decoration:underline}

        /* Key Takeaway & Stats */
        .key-takeaway{background:linear-gradient(135deg,rgba(128,0,0,.1) 0%,rgba(128,0,0,.05) 100%);border-left:4px solid var(--primary);padding:25px 30px;margin:30px 0;border-radius:0 10px 10px 0}.key-takeaway h4{color:var(--primary);margin-bottom:10px}.key-takeaway p{margin:0;color:var(--text)}.stat-box{background:var(--dark);color:var(--white);padding:30px;border-radius:15px;text-align:center;margin:30px 0}.stat-box .number{font-family:'Montserrat',sans-serif;font-size:3rem;color:var(--gold)}

        /* CTA, Author, Related */
        .article-cta{background:linear-gradient(135deg,#800000 0%,#4a0000 100%);color:var(--white);padding:50px;border-radius:15px;text-align:center;margin:50px 0}.article-cta h3{color:var(--white);margin-bottom:15px}.article-cta p{color:rgba(255,255,255,.9);margin-bottom:25px}.author-box{display:flex;gap:20px;padding:30px;background:#f8f9fa;border-radius:15px;margin:50px 0}.author-avatar{width:80px;height:80px;background:linear-gradient(135deg,#800000 0%,#4a0000 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;color:var(--white);font-size:1.5rem;font-weight:700}.related-posts{background:#f8f9fa;padding:40px;border-radius:15px;margin:40px 0}.related-posts h3{margin-bottom:20px;color:var(--dark)}.related-posts ul{list-style:none;margin:0;padding:0}.related-posts li{margin-bottom:15px}.related-posts a{color:var(--primary);font-weight:500;text-decoration:none;display:flex;align-items:center;gap:10px}.related-posts a:hover{text-decoration:underline}.related-posts i{color:#d4af37}

        @media(max-width:768px){.blog-article-hero h1{font-size:1.8rem}.blog-meta-info{flex-wrap:wrap}.author-box{flex-direction:column;text-align:center}.featured-image img{height:250px}.social-share-bar{flex-wrap:wrap}.toc-container{padding:20px}}
    </style>

    <script type="application/ld+json">
    {"@context":"https://schema.org","@type":"Article","headline":"${SEO_TITLE}","description":"${META_DESC}","image":"${SITE_URL}/images/${SLUG}.jpg","author":{"@type":"Organization","name":"LeadHorizon"},"publisher":{"@type":"Organization","name":"LeadHorizon","logo":{"@type":"ImageObject","url":"${SITE_URL}/logo.png"}},"datePublished":"${TODAY}","dateModified":"${TODAY}","mainEntityOfPage":{"@type":"WebPage","@id":"${SITE_URL}/blog/${FILENAME}"}}
    </script>
</head>
<body>
    <header>
        <div class="container header-inner">
            <a href="../index.html" class="logo">Lead<span>Horizon</span></a>
            <button class="mobile-toggle" aria-label="Menu"><i class="fas fa-bars"></i></button>
            <nav><ul><li><a href="../index.html">Home</a></li><li><a href="../blog.html">Blog</a></li><li><a href="../contact.html">Contact</a></li><li><a href="#" class="btn btn-gradient open-contact-form">Get Started</a></li></ul></nav>
        </div>
    </header>

    <!-- Reading Progress Bar -->
    <div class="reading-progress" id="readingProgress"></div>

    <section class="blog-article-hero">
        <div class="container">
            <span class="badge">${CATEGORY}</span>
            <h1>${SEO_TITLE}</h1>
            <div class="blog-meta-info">
                <span><i class="fas fa-calendar"></i> ${TODAY_DISPLAY}</span>
                <span><i class="fas fa-clock"></i> ${READ_TIME} min read</span>
            </div>
            <div class="blog-tags">${TAGS_HTML}</div>
        </div>
    </section>

    <div class="featured-image">
        <img src="../images/${SLUG}.jpg" alt="${ALT_TAG}" loading="lazy">
    </div>

    <article class="article-content container">

        <!-- Social Share Bar -->
        <div class="social-share-bar">
            <span><i class="fas fa-share-alt"></i> Share:</span>
            <button class="share-btn whatsapp" onclick="window.open('https://wa.me/?text='+encodeURIComponent(document.title+' '+window.location.href),'_blank')" title="Share on WhatsApp"><i class="fab fa-whatsapp"></i></button>
            <button class="share-btn facebook" onclick="window.open('https://www.facebook.com/sharer/sharer.php?u='+encodeURIComponent(window.location.href),'_blank')" title="Share on Facebook"><i class="fab fa-facebook-f"></i></button>
            <button class="share-btn linkedin" onclick="window.open('https://www.linkedin.com/sharing/share-offsite/?url='+encodeURIComponent(window.location.href),'_blank')" title="Share on LinkedIn"><i class="fab fa-linkedin-in"></i></button>
            <button class="share-btn twitter" onclick="window.open('https://twitter.com/intent/tweet?url='+encodeURIComponent(window.location.href)+'&text='+encodeURIComponent(document.title),'_blank')" title="Share on X"><i class="fab fa-x-twitter"></i></button>
            <button class="share-btn copy-link" onclick="navigator.clipboard.writeText(window.location.href);this.innerHTML='<i class=\\'fas fa-check\\'></i>';setTimeout(()=>this.innerHTML='<i class=\\'fas fa-link\\'></i>',2000)" title="Copy Link"><i class="fas fa-link"></i></button>
        </div>

        <!-- Table of Contents (auto-generated via JS) -->
        <div class="toc-container" id="tocContainer">
            <h4><i class="fas fa-list"></i> Table of Contents</h4>
            <ol id="tocList"></ol>
        </div>

        ${CONTENT}

        <!-- Social Share Bar (bottom) -->
        <div class="social-share-bar">
            <span><i class="fas fa-share-alt"></i> Share this article:</span>
            <button class="share-btn whatsapp" onclick="window.open('https://wa.me/?text='+encodeURIComponent(document.title+' '+window.location.href),'_blank')" title="Share on WhatsApp"><i class="fab fa-whatsapp"></i></button>
            <button class="share-btn facebook" onclick="window.open('https://www.facebook.com/sharer/sharer.php?u='+encodeURIComponent(window.location.href),'_blank')" title="Share on Facebook"><i class="fab fa-facebook-f"></i></button>
            <button class="share-btn linkedin" onclick="window.open('https://www.linkedin.com/sharing/share-offsite/?url='+encodeURIComponent(window.location.href),'_blank')" title="Share on LinkedIn"><i class="fab fa-linkedin-in"></i></button>
            <button class="share-btn twitter" onclick="window.open('https://twitter.com/intent/tweet?url='+encodeURIComponent(window.location.href)+'&text='+encodeURIComponent(document.title),'_blank')" title="Share on X"><i class="fab fa-x-twitter"></i></button>
            <button class="share-btn copy-link" onclick="navigator.clipboard.writeText(window.location.href);this.innerHTML='<i class=\\'fas fa-check\\'></i>';setTimeout(()=>this.innerHTML='<i class=\\'fas fa-link\\'></i>',2000)" title="Copy Link"><i class="fas fa-link"></i></button>
        </div>

        <div class="related-posts">
            <h3><i class="fas fa-book-open"></i> Related Articles</h3>
            <ul>
                <li><a href="real-estate-seo-guide.html"><i class="fas fa-arrow-right"></i> Real Estate SEO Guide: Rank #1 on Google</a></li>
                <li><a href="facebook-ads-real-estate.html"><i class="fas fa-arrow-right"></i> Facebook Ads for Real Estate: Generate 100+ Leads Daily</a></li>
                <li><a href="reduce-cost-per-lead.html"><i class="fas fa-arrow-right"></i> How to Reduce Cost Per Lead by 40%</a></li>
            </ul>
        </div>

        <div class="article-cta">
            <h3>Ready to Boost Your Real Estate Marketing?</h3>
            <p>LeadHorizon specializes in generating high-quality leads for builders and developers. Get a free audit and discover how we can help you grow.</p>
            <a href="../contact.html" class="btn btn-gold">Get Free Audit</a>
        </div>

        <div class="author-box">
            <div class="author-avatar">LH</div>
            <div class="author-info">
                <h4>LeadHorizon Team</h4>
                <p>LeadHorizon is Delhi NCR's premier digital marketing agency for real estate. We help builders generate more leads at lower costs through data-driven strategies.</p>
            </div>
        </div>
    </article>

    <footer>
        <div class="container">
            <div class="footer-grid">
                <div class="footer-about"><a href="../index.html" class="logo">Lead<span>Horizon</span></a><p>Premier digital marketing for real estate.</p></div>
                <div><h4>Services</h4><ul><li><a href="../seo-for-real-estate.html">SEO</a></li><li><a href="../ppc-advertising.html">PPC</a></li></ul></div>
                <div><h4>Company</h4><ul><li><a href="../blog.html">Blog</a></li><li><a href="../contact.html">Contact</a></li></ul></div>
                <div><h4>Contact</h4><ul class="footer-contact"><li><i class="fas fa-phone-alt"></i> +91-7011066532</li></ul></div>
            </div>
            <div class="footer-bottom"><p>&copy; ${YEAR} LeadHorizon</p></div>
        </div>
    </footer>

    <a href="https://wa.me/917011066532" class="whatsapp-float" target="_blank"><i class="fab fa-whatsapp"></i></a>
    <script src="../script.js?v=3" defer></script>

    <!-- TOC Generator + Reading Progress -->
    <script>
    document.addEventListener('DOMContentLoaded',function(){
        // Auto-generate Table of Contents from H2 headings
        var headings=document.querySelectorAll('.article-content h2');
        var tocList=document.getElementById('tocList');
        var tocContainer=document.getElementById('tocContainer');
        if(headings.length>1&&tocList){
            headings.forEach(function(h,i){
                var id='section-'+(i+1);
                h.id=id;
                var li=document.createElement('li');
                var a=document.createElement('a');
                a.href='#'+id;
                a.textContent=h.textContent;
                li.appendChild(a);
                tocList.appendChild(li);
            });
        }else if(tocContainer){
            tocContainer.style.display='none';
        }

        // Reading Progress Bar
        var progressBar=document.getElementById('readingProgress');
        if(progressBar){
            window.addEventListener('scroll',function(){
                var scrollTop=window.scrollY;
                var docHeight=document.documentElement.scrollHeight-window.innerHeight;
                var progress=(scrollTop/docHeight)*100;
                progressBar.style.width=progress+'%';
            });
        }
    });
    </script>
</body>
</html>
HTMLEOF

echo "✅ Blog generated: $OUTPUT_DIR/$FILENAME"

# Save metadata for other scripts
cat > "$OUTPUT_DIR/latest_blog.json" << JSONEOF
{
    "filename": "${FILENAME}",
    "title": "${SEO_TITLE}",
    "slug": "${SLUG}",
    "date": "${TODAY}",
    "category": "${CATEGORY}",
    "url": "${SITE_URL}/blog/${FILENAME}"
}
JSONEOF

echo "✅ Metadata saved: $OUTPUT_DIR/latest_blog.json"
