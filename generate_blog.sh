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
    CATEGORY="Real Estate Tips"
    PERPLEXITY_RESEARCH=""
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

# Download unique featured image from Unsplash
echo "🖼️ Downloading unique featured image..."
FEATURED_IMAGE="${SLUG}.jpg"
IMAGE_PATH="$OUTPUT_DIR/${FEATURED_IMAGE}"

# Pre-selected high-quality real estate images from Unsplash (direct URLs)
REAL_ESTATE_IMAGES=(
    "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1582407947304-fd86f028f716?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1600573472550-8090b5e0745e?w=1200&h=630&fit=crop"
    "https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1200&h=630&fit=crop"
)

# Select random image based on day to ensure variety
# Remove leading zeros to avoid octal interpretation
DAY_OF_YEAR=$(date +%j | sed 's/^0*//')
IMAGE_INDEX=$((DAY_OF_YEAR % ${#REAL_ESTATE_IMAGES[@]}))
SELECTED_IMAGE="${REAL_ESTATE_IMAGES[$IMAGE_INDEX]}"

# Download image
curl -sL "$SELECTED_IMAGE" -o "$IMAGE_PATH" 2>/dev/null

# Verify download is actually a JPEG (check file size > 10KB)
FILE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null || echo "0")
if [ "$FILE_SIZE" -lt 10000 ]; then
    echo "⚠️ Image download failed (size: ${FILE_SIZE}), trying fallback..."
    # Try another image
    FALLBACK_INDEX=$(( (IMAGE_INDEX + 1) % ${#REAL_ESTATE_IMAGES[@]} ))
    curl -sL "${REAL_ESTATE_IMAGES[$FALLBACK_INDEX]}" -o "$IMAGE_PATH" 2>/dev/null

    # Check again
    FILE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null || echo "0")
    if [ "$FILE_SIZE" -lt 10000 ]; then
        echo "❌ All image downloads failed"
    else
        echo "✅ Fallback image downloaded (${FILE_SIZE} bytes)"
    fi
else
    echo "✅ Image downloaded (${FILE_SIZE} bytes)"
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
            <span class="badge">${CATEGORY}</span>
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
    "category": "${CATEGORY}",
    "url": "${SITE_URL}/blog/${FILENAME}"
}
JSONEOF

echo "✅ Metadata saved: $OUTPUT_DIR/latest_blog.json"
