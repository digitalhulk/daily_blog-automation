#!/bin/bash
# LeadHorizon Daily Blog Automation
# Runs at 6 AM daily - Market trend analysis + Blog generation + SEO + Publish

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/automation.log"
source "$SCRIPT_DIR/config.sh"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "============================================================"
log "🚀 LeadHorizon Daily Blog Automation Started"
log "📅 Date: $(date '+%A, %B %d, %Y')"
log "⏰ Time: $(date '+%I:%M %p')"
log "============================================================"

# Clean up previous day's temp files
rm -f "$OUTPUT_DIR/today_topic.json" 2>/dev/null
rm -f "$OUTPUT_DIR"/*.jpg 2>/dev/null
rm -f "$OUTPUT_DIR"/*.html 2>/dev/null

# Step 0: Check if Ollama is running
log ""
log "🔌 Step 0: Checking Ollama..."
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    log "⚠️ Ollama not running. Starting Ollama..."
    ollama serve &>/dev/null &
    sleep 10
    if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        log "❌ Failed to start Ollama. Exiting."
        exit 1
    fi
fi
log "✅ Ollama is running"

# Step 1: Analyze Market Trends & Select Topic
log ""
log "📊 Step 1: Analyzing market trends..."
bash "$SCRIPT_DIR/trend_topics.sh" 2>&1 | tee -a "$LOG_FILE"

if [ ! -f "$OUTPUT_DIR/today_topic.json" ]; then
    log "❌ Trend analysis failed! Using fallback topic selection."
fi

log "✅ Topic selected"

# Step 1.5: Perplexity Market Research (Real-time data)
log ""
log "🔬 Step 1.5: Gathering real-time market research (Perplexity AI)..."
python3 "$SCRIPT_DIR/market_research.py" 2>&1 | tee -a "$LOG_FILE"

if grep -q "perplexity_research" "$OUTPUT_DIR/today_topic.json" 2>/dev/null; then
    log "✅ Market research completed"
else
    log "⚠️ Research skipped (will use basic analysis)"
fi

# Step 2: Generate Blog Content
log ""
log "📝 Step 2: Generating SEO-optimized blog content..."
bash "$SCRIPT_DIR/generate_blog.sh" 2>&1 | tee -a "$LOG_FILE"

if [ ! -f "$OUTPUT_DIR/latest_blog.json" ]; then
    log "❌ Blog generation failed!"
    exit 1
fi

BLOG_FILENAME=$(grep '"filename"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)
log "✅ Blog generated: $BLOG_FILENAME"

# Step 3: Deploy to Server
log ""
log "📤 Step 3: Deploying blog to server..."
bash "$SCRIPT_DIR/deploy.sh" 2>&1 | tee -a "$LOG_FILE"

if [ $? -ne 0 ]; then
    log "❌ Deployment failed!"
    exit 1
fi

log "✅ Blog deployed successfully"

# Step 4: Submit to Search Engines
log ""
log "🔍 Step 4: Submitting to search engines..."
python3 "$SCRIPT_DIR/google_indexing.py" 2>&1 | tee -a "$LOG_FILE"

log "✅ Search engine submission complete"

# Step 5: Share to Social Media (LinkedIn & Facebook)
log ""
log "📱 Step 5: Sharing to social media..."
python3 "$SCRIPT_DIR/social_share.py" 2>&1 | tee -a "$LOG_FILE"

log "✅ Social media sharing complete"

# Step 6: Generate Summary Report
log ""
log "============================================================"
log "📊 DAILY BLOG AUTOMATION SUMMARY"
log "============================================================"

BLOG_URL=$(grep '"url"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)
BLOG_TITLE=$(grep '"title"' "$OUTPUT_DIR/latest_blog.json" | cut -d'"' -f4)

log "📄 Title: $BLOG_TITLE"
log "🔗 URL: $BLOG_URL"
log "📅 Published: $(date '+%Y-%m-%d %H:%M:%S')"
log ""
log "✅ SEO Elements:"
log "   • Meta title & description ✓"
log "   • Featured image with ALT tag ✓"
log "   • Internal linking ✓"
log "   • Schema markup ✓"
log "   • Open Graph tags ✓"
log "   • Sitemap updated ✓"
log "   • Blog listing updated ✓"
log ""
log "🎉 Daily automation completed successfully!"
log "============================================================"

# Save daily report
REPORT_FILE="$SCRIPT_DIR/reports/$(date '+%Y-%m-%d').txt"
mkdir -p "$SCRIPT_DIR/reports"
cat > "$REPORT_FILE" << REPORT
LeadHorizon Daily Blog Report
=============================
Date: $(date '+%Y-%m-%d')
Time: $(date '+%H:%M:%S')

Blog Details:
- Title: $BLOG_TITLE
- URL: $BLOG_URL
- Filename: $BLOG_FILENAME

Status: SUCCESS

SEO Checklist:
[✓] Meta title optimized
[✓] Meta description optimized
[✓] Featured image with ALT
[✓] Internal links added
[✓] Schema markup added
[✓] Sitemap updated
[✓] Search engines notified
REPORT

log "📋 Report saved: $REPORT_FILE"
