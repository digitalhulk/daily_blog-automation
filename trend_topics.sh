#!/bin/bash
# Trend-Based Topic Selection for LeadHorizon Blog
# Analyzes market trends and selects relevant topics

source "$(dirname "$0")/config.sh"
mkdir -p "$OUTPUT_DIR"

# Get current month (without leading zero for comparison)
MONTH=$(date +%-m)
DAY=$(date +%-d)

echo "🔍 Selecting trending topic for $(date '+%B %d, %Y')..."
echo "📅 Month: $MONTH, Day: $DAY"

# Function to get seasonal topics based on month
get_seasonal_topics() {
    case $MONTH in
        1)
            echo "New Year Property Investment Trends 2026|property investment 2026|real estate trends, new year investment
Union Budget 2026 Impact on Real Estate|budget 2026 real estate|property tax, home loan benefits
Best Time to Buy Property in Q1 2026|buy property q1 2026|property prices, market timing"
            ;;
        2)
            echo "Post Budget Real Estate Analysis 2026|budget impact real estate|property investment, tax benefits
Valentine's Day Marketing for Real Estate|valentine real estate marketing|couple homes, romantic properties
Financial Year End Property Deals|financial year property deals|tax saving, march investment"
            ;;
        3)
            echo "Last Minute Tax Saving Through Property|tax saving property investment|80c benefits, home loan
Financial Year End Real Estate Offers|year end property deals|builder discounts, march offers
How to Close Property Deals Before March 31|close property deals march|registration, documentation"
            ;;
        4)
            echo "New Financial Year Property Strategy|fy 2026-27 property investment|new year planning
RERA Updates 2026 What Builders Need to Know|rera updates 2026|compliance, regulations
Summer Property Marketing Strategies|summer real estate marketing|hot season, property sales"
            ;;
        5)
            echo "Summer Real Estate Marketing Ideas|summer property marketing|seasonal marketing, campaigns
NRI Property Investment Guide 2026|nri property investment india|overseas buyers, nri home loan
Pre-Monsoon Property Inspection Tips|property inspection tips|home buying, due diligence"
            ;;
        6)
            echo "Monsoon Real Estate Marketing Strategies|monsoon property marketing|rainy season marketing
Mid-Year Real Estate Market Review 2026|real estate review 2026|market analysis, trends
Digital Marketing During Monsoon Season|monsoon digital marketing|online leads, campaigns"
            ;;
        7)
            echo "Waterproofing and Property Value|waterproofing real estate|monsoon property, maintenance
Virtual Property Tours During Monsoon|virtual property tours|3d tours, online viewing
Lead Nurturing Strategies for Slow Season|lead nurturing real estate|follow up, conversion"
            ;;
        8)
            echo "Independence Day Real Estate Campaigns|independence day property offers|august deals
Preparing for Festive Season Sales|festive season real estate|diwali prep, navratri marketing
Ganesh Chaturthi Real Estate Marketing|ganesh chaturthi property|festive marketing, buying"
            ;;
        9)
            echo "Navratri Real Estate Marketing Guide|navratri property marketing|festive offers, dates
Shradh Period Property Marketing Strategy|shradh real estate marketing|sensitive marketing
Pre-Diwali Property Launch Strategies|pre diwali property launch|festive launch, booking"
            ;;
        10)
            echo "Dussehra Real Estate Offers Campaigns|dussehra property offers|festive deals, october sales
Dhanteras Property Buying Guide|dhanteras property buying|auspicious purchase, investment
Diwali Real Estate Marketing Complete Guide|diwali property marketing|festive campaigns, offers"
            ;;
        11)
            echo "Post Diwali Real Estate Market Analysis|post diwali property market|festive impact, trends
Wedding Season Property Marketing|wedding season real estate|newlywed homes, couple properties
Black Friday Real Estate Deals Strategy|black friday property deals|november offers, online"
            ;;
        12)
            echo "Year End Property Deals and Offers|year end real estate deals|december offers, clearance
Christmas New Year Real Estate Marketing|christmas property marketing|holiday campaigns
Real Estate Predictions for 2027|real estate predictions 2027|market forecast, trends"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Evergreen topics (used as fallback)
EVERGREEN_TOPICS="Google Ads vs Facebook Ads for Real Estate 2026|google ads vs facebook ads real estate|ppc comparison
WhatsApp Business for Real Estate Lead Generation|whatsapp business real estate|whatsapp marketing, leads
Instagram Reels Strategy for Property Marketing|instagram reels real estate|short video, viral marketing
YouTube Shorts for Real Estate Developers|youtube shorts property|video marketing, youtube
LinkedIn Marketing for Commercial Real Estate|linkedin commercial real estate|b2b property, linkedin ads
Real Estate CRM Best Practices 2026|real estate crm 2026|lead management, sales automation
AI Tools for Real Estate Marketing|ai real estate marketing|chatgpt, ai content, automation
Voice Search Optimization for Property Sites|voice search real estate|seo 2026, alexa google
Real Estate Email Marketing Automation|email automation real estate|drip campaigns, nurture
Retargeting Strategies for Property Buyers|retargeting real estate|remarketing, facebook pixel
Google My Business for Real Estate Agents|gmb real estate|local seo, google maps
Property Video Marketing Complete Guide|property video marketing|walkthrough, drone videos
Real Estate Influencer Marketing Strategy|influencer marketing real estate|collaboration, micro
Chatbot Implementation for Builder Websites|chatbot real estate website|ai chat, lead capture
Landing Page Optimization for Real Estate|landing page real estate|conversion optimization
How Builders Can Generate More Site Visits Through Digital Marketing|builder site visit generation|construction marketing, developer leads
RERA Compliance Marketing Guide for Developers|rera compliance marketing|rera registration, builder compliance
Project Launch Marketing Strategy for Builders|project launch marketing real estate|new project promotion, builder launch
Best CRM Tools for Real Estate Builders in India|crm tools builders india|developer crm, lead management builders
Referral Marketing Strategies for Real Estate Builders|referral marketing builders|word of mouth, builder referrals"

# Get topics
SEASONAL=$(get_seasonal_topics)

if [ -n "$SEASONAL" ]; then
    # Use seasonal topic
    if command -v gshuf &> /dev/null; then
        SELECTED_TOPIC=$(echo "$SEASONAL" | gshuf -n 1)
    else
        SELECTED_TOPIC=$(echo "$SEASONAL" | sort -R | head -1)
    fi
    TOPIC_TYPE="seasonal"
else
    # Use evergreen topic
    if command -v gshuf &> /dev/null; then
        SELECTED_TOPIC=$(echo "$EVERGREEN_TOPICS" | gshuf -n 1)
    else
        SELECTED_TOPIC=$(echo "$EVERGREEN_TOPICS" | sort -R | head -1)
    fi
    TOPIC_TYPE="evergreen"
fi

# Parse topic parts
TOPIC_TITLE=$(echo "$SELECTED_TOPIC" | cut -d'|' -f1)
PRIMARY_KW=$(echo "$SELECTED_TOPIC" | cut -d'|' -f2)
SECONDARY_KW=$(echo "$SELECTED_TOPIC" | cut -d'|' -f3)

echo "📝 Selected Topic ($TOPIC_TYPE): $TOPIC_TITLE"
echo "🔑 Primary Keyword: $PRIMARY_KW"
echo "🏷️ Secondary Keywords: $SECONDARY_KW"
echo ""

# Analyze market trend using Ollama
echo "📊 Analyzing market trend..."

ANALYSIS_PROMPT="You are a real estate market analyst in India. In 2-3 sentences, explain why '$TOPIC_TITLE' is relevant for real estate digital marketing right now in $(date '+%B %Y'). Consider current market conditions, buyer behavior, and seasonal factors."

# Get analysis from Ollama
MARKET_ANALYSIS=$(echo "$ANALYSIS_PROMPT" | timeout 90 ollama run llama3.2:latest 2>/dev/null | tr '\n' ' ' | head -c 500)

if [ -z "$MARKET_ANALYSIS" ]; then
    MARKET_ANALYSIS="This topic is highly relevant for real estate marketers in the current market scenario, helping builders connect with potential buyers effectively."
fi

echo "📈 Market Analysis:"
echo "$MARKET_ANALYSIS"
echo ""

# Determine category based on topic keywords (7 categories)
TOPIC_LOWER=$(echo "$TOPIC_TITLE" | tr '[:upper:]' '[:lower:]')
KW_LOWER=$(echo "$PRIMARY_KW" | tr '[:upper:]' '[:lower:]')
COMBINED="$TOPIC_LOWER $KW_LOWER"

if echo "$COMBINED" | grep -qiE "builder|developer|construction|rera|project launch|referral.*builder"; then
    TOPIC_CATEGORY="Builder & Developer Tips"
elif echo "$COMBINED" | grep -qiE "seo|ranking|google my business|gmb|local seo|website|landing page|voice search"; then
    TOPIC_CATEGORY="SEO & Website"
elif echo "$COMBINED" | grep -qiE "google ads|facebook ads|ppc|retarget|remarketing|ad budget|ad campaign|paid"; then
    TOPIC_CATEGORY="Paid Ads"
elif echo "$COMBINED" | grep -qiE "instagram|youtube|linkedin|social media|reels|shorts|influencer|whatsapp"; then
    TOPIC_CATEGORY="Social Media"
elif echo "$COMBINED" | grep -qiE "lead gen|lead nurtur|lead scor|crm|email marketing|chatbot|conversion|follow.up"; then
    TOPIC_CATEGORY="Lead Generation"
elif echo "$COMBINED" | grep -qiE "ai |artificial intelligence|automation|chatgpt|machine learning|virtual tour|3d|proptech"; then
    TOPIC_CATEGORY="AI & Tech"
else
    TOPIC_CATEGORY="Market Trends"
fi

echo "📂 Category: $TOPIC_CATEGORY"

# Save to file for blog generator (properly escape JSON)
python3 << PYSAVE
import json

data = {
    "topic": """$TOPIC_TITLE""",
    "primary_keyword": """$PRIMARY_KW""",
    "secondary_keywords": """$SECONDARY_KW""",
    "market_analysis": """$MARKET_ANALYSIS""",
    "date": "$(date '+%Y-%m-%d')",
    "month": "$MONTH",
    "category": """$TOPIC_CATEGORY""",
    "type": "$TOPIC_TYPE"
}

with open("$OUTPUT_DIR/today_topic.json", "w") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)

print("JSON saved successfully")
PYSAVE

echo "✅ Topic saved to: $OUTPUT_DIR/today_topic.json"
