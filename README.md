# LeadHorizon Blog Automation

Automated daily blog publishing system for real estate marketing websites. Generates SEO-optimized content using local AI (Ollama), publishes to server, and submits to search engines.

## Features

- **Daily Automated Publishing** - Runs at 6 AM via macOS LaunchAgent
- **Trend-Based Topics** - Selects topics based on current month/season
- **AI Content Generation** - Uses Ollama (local, free) for content
- **SEO Optimized** - Meta tags, Schema markup, Open Graph
- **Unique Featured Images** - Downloads from Unsplash per blog
- **Internal Linking** - Related articles section
- **Auto Sitemap Update** - Updates sitemap.xml on server
- **Search Engine Submission** - Pings Google & Bing

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    macOS LAUNCHD (System Service)               │
│                   Always running in background                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ Triggers at 6:00 AM daily
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         run_daily.sh                             │
│                    (Main Orchestrator Script)                    │
└─────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────┐
│ trend_topics  │──────▶│ generate_blog │──────▶│   deploy.sh   │
│    .sh        │       │     .sh       │       │               │
│               │       │               │       │               │
│ Topic Select  │       │ Content+Image │       │ Upload + SEO  │
└───────────────┘       └───────────────┘       └───────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐       ┌───────────────┐       ┌───────────────┐
│    Ollama     │       │   Ollama +    │       │   Hostinger   │
│  (Analysis)   │       │   Unsplash    │       │    Server     │
└───────────────┘       └───────────────┘       └───────────────┘
```

## Prerequisites

### 1. Install Homebrew (macOS)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Required Tools
```bash
# sshpass for non-interactive SSH
brew install hudochenkov/sshpass/sshpass

# coreutils for gshuf command
brew install coreutils

# Python 3 (usually pre-installed on macOS)
python3 --version
```

### 3. Install Ollama
Download from [https://ollama.ai](https://ollama.ai) and install.

```bash
# Pull the model
ollama pull llama3.2:latest

# Start Ollama server
ollama serve
```

## Setup Instructions

### Step 1: Clone Repository
```bash
cd ~
git clone https://github.com/yourusername/leadhorizon-automation.git
cd leadhorizon-automation
```

### Step 2: Configure
```bash
# Copy sample config
cp config.sample.sh config.sh

# Edit with your details
nano config.sh
```

Fill in:
- SSH credentials (from your hosting provider)
- Server paths
- Website URL
- Google Indexing credentials (optional)

### Step 3: Make Scripts Executable
```bash
chmod +x *.sh
```

### Step 4: Test Run
```bash
# Make sure Ollama is running
ollama serve &

# Run the automation
./run_daily.sh
```

### Step 5: Setup Daily Schedule (macOS)

Create LaunchAgent:
```bash
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.leadhorizon.blogautomation.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.leadhorizon.blogautomation</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>$HOME/leadhorizon-automation/run_daily.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>6</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/leadhorizon.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/leadhorizon.err.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
EOF

# Load the agent
launchctl load ~/Library/LaunchAgents/com.leadhorizon.blogautomation.plist
```

## File Structure

```
leadhorizon-automation/
├── config.sh              # Your configuration (gitignored)
├── config.sample.sh       # Sample configuration
├── run_daily.sh           # Main orchestrator
├── trend_topics.sh        # Topic selection with market analysis
├── generate_blog.sh       # Content generation with Ollama
├── deploy.sh              # Server upload & sitemap update
├── google_indexing.py     # Search engine submission
├── topics.txt             # Evergreen topics list
├── output/                # Generated files (gitignored)
│   ├── today_topic.json
│   ├── latest_blog.json
│   └── *.html, *.jpg
└── reports/               # Daily reports (gitignored)
```

## Useful Commands

```bash
# Check if LaunchAgent is loaded
launchctl list | grep leadhorizon

# Manually trigger the automation
launchctl start com.leadhorizon.blogautomation

# View today's log
tail -100 ~/leadhorizon-automation/automation.log

# Check last run report
cat ~/leadhorizon-automation/reports/$(date +%Y-%m-%d).txt

# Unload LaunchAgent (stop daily runs)
launchctl unload ~/Library/LaunchAgents/com.leadhorizon.blogautomation.plist
```

## SEO Features Included

| Feature | Implementation |
|---------|----------------|
| Meta Title | Under 60 chars, keyword optimized |
| Meta Description | Under 160 chars, compelling |
| Open Graph | Facebook/LinkedIn sharing |
| Schema Markup | Article structured data |
| Canonical URL | Prevents duplicate content |
| Featured Image | Unique per blog with ALT tag |
| Internal Linking | Related articles section |
| Sitemap | Auto-updated on publish |
| Mobile Responsive | Responsive design |

## Topic Selection

### Seasonal Topics (Month-based)
- January: New Year investment trends, Budget expectations
- February: Post-budget analysis, Valentine marketing
- March: Financial year-end deals, Tax saving
- April: New FY strategies, RERA updates
- May: Summer marketing, NRI investments
- June: Monsoon strategies, Mid-year review
- July: Waterproofing value, Virtual tours
- August: Independence Day campaigns, Festive prep
- September: Navratri marketing, Pre-Diwali launches
- October: Dussehra, Dhanteras, Diwali campaigns
- November: Post-Diwali analysis, Wedding season
- December: Year-end deals, Next year predictions

### Evergreen Topics (Fallback)
- Google Ads vs Facebook Ads
- WhatsApp Business for leads
- Instagram Reels strategy
- Real Estate CRM best practices
- AI tools for marketing
- And more...

## Troubleshooting

### Ollama not running
```bash
# Start Ollama
ollama serve

# Check if running
curl http://localhost:11434/api/tags
```

### SSH connection fails
```bash
# Test SSH manually
sshpass -p "your-password" ssh -o StrictHostKeyChecking=no -p 65002 user@host
```

### LaunchAgent not triggering
```bash
# Check if loaded
launchctl list | grep leadhorizon

# Reload
launchctl unload ~/Library/LaunchAgents/com.leadhorizon.blogautomation.plist
launchctl load ~/Library/LaunchAgents/com.leadhorizon.blogautomation.plist
```

## Requirements Summary

- macOS (for LaunchAgent scheduling)
- Ollama with llama3.2 model
- Homebrew + sshpass + coreutils
- SSH access to web server
- Python 3

## License

MIT License - Feel free to modify for your use.

## Author

Created for LeadHorizon - Real Estate Digital Marketing Agency
