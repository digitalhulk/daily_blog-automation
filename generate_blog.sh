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
else
    echo "📝 Using random topic from list..."
    TOPIC_LINE=$(get_random_topic)
    TOPIC=$(echo "$TOPIC_LINE" | cut -d'|' -f1)
    PRIMARY_KEYWORD=$(echo "$TOPIC_LINE" | cut -d'|' -f2)
    SECONDARY_KEYWORDS=$(echo "$TOPIC_LINE" | cut -d'|' -f3)
    MARKET_ANALYSIS=""
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
    MARKET_CONTEXT="\\n\\nMarket Context (use this insight in your article): $MARKET_ANALYSIS"
fi

# Create JSON payload file using heredoc to preserve formatting
PAYLOAD_FILE="/tmp/ollama_payload_$$.json"
cat > "$PAYLOAD_FILE" << JSONPAYLOAD
{
  "model": "$OLLAMA_MODEL",
  "prompt": "You are an expert SEO content writer for LeadHorizon, a real estate digital marketing agency in Delhi NCR, India. Today's date is $(date '+%B %d, %Y').\n\nWrite a comprehensive, SEO-optimized blog article about: \"$TOPIC\"\n\nPrimary keyword: $PRIMARY_KEYWORD\nSecondary keywords: $SECONDARY_KEYWORDS$MARKET_CONTEXT\n\nRequirements:\n1. Write 1500-2000 words of high-quality content\n2. Use the primary keyword naturally 5-7 times throughout the article\n3. Include H2 and H3 headings with keywords\n4. Write engaging introduction that hooks the reader\n5. Include actionable tips with real examples from India\n6. Add current statistics and data (use realistic 2025-2026 numbers)\n7. Write for builders and real estate developers in Delhi NCR, India\n8. Reference current market trends and conditions\n9. Include a call-to-action for LeadHorizon services\n10. Use simple, professional language\n\nIMPORTANT: Output your response in EXACTLY this format:\n<title>SEO Title (under 60 characters)</title>\n<meta_description>Meta description (under 160 characters)</meta_description>\n<content>\nYour full HTML content here with proper h2, h3, p, ul, li tags\n</content>",
  "stream": false
}
JSONPAYLOAD

# Call Ollama API
echo "📡 Calling Ollama API..."
API_RESPONSE=$(curl -s http://localhost:11434/api/generate -d @"$PAYLOAD_FILE" 2>/dev/null)
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

# Convert markdown-style formatting to HTML if needed
content = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', content)
content = re.sub(r'\*([^*]+)\*', r'<em>\1</em>', content)

# Ensure content has proper HTML structure
if not re.search(r'<(p|h[1-6]|ul|ol|div)', content):
    # Wrap paragraphs in <p> tags
    paragraphs = content.split('\n\n')
    content = '\n'.join([f'<p>{p.strip()}</p>' for p in paragraphs if p.strip()])

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

# Download unique featured image from Unsplash based on topic
echo "🖼️ Downloading unique featured image..."
FEATURED_IMAGE="${SLUG}.jpg"
IMAGE_PATH="$OUTPUT_DIR/${FEATURED_IMAGE}"

# Unsplash search terms based on common real estate marketing topics
SEARCH_TERM=$(echo "$PRIMARY_KEYWORD" | sed 's/ /%20/g')

# Download image from Unsplash (random relevant image)
UNSPLASH_URL="https://source.unsplash.com/1200x630/?${SEARCH_TERM},real-estate,marketing"
curl -sL "$UNSPLASH_URL" -o "$IMAGE_PATH" 2>/dev/null

# Check if download was successful
if [ ! -f "$IMAGE_PATH" ] || [ ! -s "$IMAGE_PATH" ]; then
    echo "⚠️ Unsplash download failed, using fallback"
    # Fallback to a generic real estate image
    curl -sL "https://source.unsplash.com/1200x630/?real-estate,building" -o "$IMAGE_PATH" 2>/dev/null
fi

# Create SEO-optimized ALT tag
ALT_TAG="${SEO_TITLE} - ${PRIMARY_KEYWORD} Guide for Real Estate Developers | LeadHorizon Delhi NCR"
echo "✅ Featured image: $FEATURED_IMAGE"

# Create the HTML file
cat > "$OUTPUT_DIR/$FILENAME" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
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
        .blog-article-hero{background:linear-gradient(135deg,var(--primary) 0%,var(--primary-dark) 100%);padding:150px 0 80px;color:var(--white)}.blog-article-hero .badge{background:var(--gold);color:var(--dark)}.blog-article-hero h1{font-family:'Montserrat',sans-serif;font-size:2.8rem;margin:20px 0;line-height:1.3}.blog-meta-info{display:flex;gap:25px;margin-top:25px;font-size:.95rem;opacity:.9}.blog-meta-info i{margin-right:8px}.featured-image{width:100%;max-width:800px;margin:0 auto -40px;padding:0 20px;position:relative;z-index:10}.featured-image img{width:100%;height:400px;object-fit:cover;border-radius:15px;box-shadow:0 10px 40px rgba(0,0,0,0.2)}.article-content{padding:80px 0;max-width:800px;margin:0 auto}.article-content h2{font-family:'Montserrat',sans-serif;font-size:1.8rem;color:var(--dark);margin:50px 0 20px}.article-content h3{font-size:1.3rem;color:var(--dark);margin:35px 0 15px}.article-content p{color:var(--text-light);font-size:1.05rem;line-height:1.9;margin-bottom:20px}.article-content ul,.article-content ol{color:var(--text-light);margin:20px 0 20px 25px;line-height:2}.article-content a{color:var(--primary);text-decoration:underline}.key-takeaway{background:linear-gradient(135deg,rgba(128,0,0,.1) 0%,rgba(128,0,0,.05) 100%);border-left:4px solid var(--primary);padding:25px 30px;margin:30px 0;border-radius:0 10px 10px 0}.key-takeaway h4{color:var(--primary);margin-bottom:10px}.key-takeaway p{margin:0;color:var(--text)}.stat-box{background:var(--dark);color:var(--white);padding:30px;border-radius:15px;text-align:center;margin:30px 0}.stat-box .number{font-family:'Montserrat',sans-serif;font-size:3rem;color:var(--gold)}.article-cta{background:linear-gradient(135deg,#800000 0%,#4a0000 100%);color:var(--white);padding:50px;border-radius:15px;text-align:center;margin:50px 0}.article-cta h3{color:var(--white);margin-bottom:15px}.article-cta p{color:rgba(255,255,255,.9);margin-bottom:25px}.author-box{display:flex;gap:20px;padding:30px;background:#f8f9fa;border-radius:15px;margin:50px 0}.author-avatar{width:80px;height:80px;background:linear-gradient(135deg,#800000 0%,#4a0000 100%);border-radius:50%;display:flex;align-items:center;justify-content:center;color:var(--white);font-size:1.5rem;font-weight:700}.related-posts{background:#f8f9fa;padding:40px;border-radius:15px;margin:40px 0}.related-posts h3{margin-bottom:20px;color:var(--dark)}.related-posts ul{list-style:none;margin:0;padding:0}.related-posts li{margin-bottom:15px}.related-posts a{color:var(--primary);font-weight:500;text-decoration:none;display:flex;align-items:center;gap:10px}.related-posts a:hover{text-decoration:underline}.related-posts i{color:#d4af37}@media(max-width:768px){.blog-article-hero h1{font-size:1.8rem}.blog-meta-info{flex-wrap:wrap}.author-box{flex-direction:column;text-align:center}.featured-image img{height:250px}}
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

    <section class="blog-article-hero">
        <div class="container">
            <span class="badge">Digital Marketing</span>
            <h1>${SEO_TITLE}</h1>
            <div class="blog-meta-info">
                <span><i class="fas fa-calendar"></i> ${TODAY_DISPLAY}</span>
                <span><i class="fas fa-clock"></i> ${READ_TIME} min read</span>
            </div>
        </div>
    </section>

    <div class="featured-image">
        <img src="../images/${SLUG}.jpg" alt="${ALT_TAG}" loading="lazy">
    </div>

    <article class="article-content container">
        ${CONTENT}

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
    "url": "${SITE_URL}/blog/${FILENAME}"
}
JSONEOF

echo "✅ Metadata saved: $OUTPUT_DIR/latest_blog.json"
