#!/bin/bash
# Manual Blog Publisher
# Allows custom topic and category selection

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
mkdir -p "$OUTPUT_DIR"

echo "============================================================"
echo "📝 Manual Blog Publisher"
echo "============================================================"

# Get user input
read -p "Enter Blog Topic/Title: " TOPIC
if [ -z "$TOPIC" ]; then
    echo "❌ Topic is required!"
    exit 1
fi

read -p "Enter Primary Keyword: " PRIMARY_KW
if [ -z "$PRIMARY_KW" ]; then
    echo "❌ Primary keyword is required!"
    exit 1
fi

read -p "Enter Secondary Keywords (comma separated): " SECONDARY_KWS
if [ -z "$SECONDARY_KWS" ]; then
    SECONDARY_KWS="$PRIMARY_KW, real estate trends, property market"
fi

echo ""
echo "Select Category:"
echo "1. Market Trends"
echo "2. Investment Tips"
echo "3. News & Updates"
echo "4. Lifestyle"
echo "5. Builder & Developer Tips"
echo "6. Custom"
read -p "Enter choice (1-6): " CAT_CHOICE

case $CAT_CHOICE in
    1) CATEGORY="Market Trends" ;;
    2) CATEGORY="Investment Tips" ;;
    3) CATEGORY="News Updates" ;;
    4) CATEGORY="Lifestyle" ;;
    5) CATEGORY="Builder & Developer Tips" ;;
    6) read -p "Enter Custom Category: " CATEGORY ;;
    *) CATEGORY="Real Estate" ;;
esac

echo ""
echo "🚀 Starting publication process..."
echo "Topic: $TOPIC"
echo "Category: $CATEGORY"
echo "------------------------------------------------------------"

# Save to today_topic.json
python3 << PYSAVE
import json

data = {
    "topic": """$TOPIC""",
    "primary_keyword": """$PRIMARY_KW""",
    "secondary_keywords": """$SECONDARY_KWS""",
    "category": """$CATEGORY""",
    "market_analysis": "Manual topic selection",
    "date": "$(date '+%Y-%m-%d')",
    "type": "manual"
}

with open("$OUTPUT_DIR/today_topic.json", "w") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)

print("✅ Topic saved successfully")
PYSAVE

# Run the pipeline
echo ""
echo "🔬 Step 1: Gathering research..."
python3 "$SCRIPT_DIR/market_research.py"

echo ""
echo "📝 Step 2: Generating content..."
bash "$SCRIPT_DIR/generate_blog.sh"

echo ""
echo "📤 Step 3: Deploying..."
bash "$SCRIPT_DIR/deploy.sh"

echo ""
echo "🔍 Step 4: Indexing..."
python3 "$SCRIPT_DIR/google_indexing.py"

echo ""
echo "📱 Step 5: Social Sharing..."
python3 "$SCRIPT_DIR/social_share.py"

echo ""
echo "🎉 Done! Blog published."
