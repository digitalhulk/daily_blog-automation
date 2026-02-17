#!/bin/bash
# LeadHorizon Blog Automation Configuration
# Copy this file to config.sh and fill in your details

# Server Details (Hostinger SSH)
SSH_HOST="your-server-ip"
SSH_PORT="65002"
SSH_USER="your-username"
SSH_PASS="your-password"

# Website Paths (adjust according to your hosting)
REMOTE_PATH="/home/your-user/domains/yourdomain.com/public_html"
BLOG_PATH="${REMOTE_PATH}/blog"
SITEMAP_PATH="${REMOTE_PATH}/sitemap.xml"

# Local Paths
LOCAL_DIR="$HOME/leadhorizon-automation"
OUTPUT_DIR="${LOCAL_DIR}/output"
TOPICS_FILE="${LOCAL_DIR}/topics.txt"

# Website Details
SITE_URL="https://yourdomain.com"
SITE_NAME="YourSiteName"

# Ollama Settings (install from https://ollama.ai)
# Recommended: llama3.1:8b for better content quality (1000-1200 words)
# Alternatives: mistral:latest (faster), llama3.2:latest (smaller)
OLLAMA_MODEL="llama3.1:8b"

# Google Indexing (Optional)
# 1. Go to Google Cloud Console
# 2. Create project and enable Indexing API
# 3. Create service account, download JSON key
# 4. Add service account email to Search Console as owner
# 5. Set path below
GOOGLE_SERVICE_ACCOUNT_JSON=""

# Perplexity API (for real-time market research)
# Get API key from: https://www.perplexity.ai/settings/api
PERPLEXITY_API_KEY=""
