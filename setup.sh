#!/bin/bash
# LeadHorizon Automation Setup Script
# Run this once to set up the automation system

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔧 LeadHorizon Blog Automation Setup"
echo "===================================="
echo ""

# Make scripts executable
echo "📁 Making scripts executable..."
chmod +x "$SCRIPT_DIR/generate_blog.sh"
chmod +x "$SCRIPT_DIR/deploy.sh"
chmod +x "$SCRIPT_DIR/run_daily.sh"
chmod +x "$SCRIPT_DIR/google_indexing.py"
chmod +x "$SCRIPT_DIR/setup.sh"

# Create output directory
mkdir -p "$SCRIPT_DIR/output"

echo "✅ Scripts ready"
echo ""

# Check dependencies
echo "🔍 Checking dependencies..."

# Check sshpass
if command -v sshpass &> /dev/null; then
    echo "✅ sshpass installed"
else
    echo "❌ sshpass not found. Installing..."
    brew install hudochenkov/sshpass/sshpass
fi

# Check Ollama
if command -v ollama &> /dev/null; then
    echo "✅ Ollama installed"
    ollama list
else
    echo "❌ Ollama not found. Please install from https://ollama.ai"
fi

# Check Python
if command -v python3 &> /dev/null; then
    echo "✅ Python3 installed"
else
    echo "❌ Python3 not found"
fi

echo ""
echo "===================================="
echo "📅 Setting up daily automation..."
echo "===================================="

# Create LaunchAgent for daily execution (macOS)
PLIST_FILE="$HOME/Library/LaunchAgents/com.leadhorizon.blogautomation.plist"

cat > "$PLIST_FILE" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.leadhorizon.blogautomation</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_DIR}/run_daily.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${SCRIPT_DIR}/launchd_output.log</string>
    <key>StandardErrorPath</key>
    <string>${SCRIPT_DIR}/launchd_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
PLISTEOF

echo "✅ LaunchAgent created: $PLIST_FILE"
echo ""

# Load the LaunchAgent
echo "📅 Loading LaunchAgent (will run daily at 9:00 AM)..."
launchctl unload "$PLIST_FILE" 2>/dev/null
launchctl load "$PLIST_FILE"

echo ""
echo "===================================="
echo "🎉 Setup Complete!"
echo "===================================="
echo ""
echo "📁 Automation folder: $SCRIPT_DIR"
echo "📅 Daily run time: 9:00 AM"
echo ""
echo "Commands:"
echo "  • Run now:     bash $SCRIPT_DIR/run_daily.sh"
echo "  • View logs:   cat $SCRIPT_DIR/automation.log"
echo "  • Stop daily:  launchctl unload $PLIST_FILE"
echo "  • Start daily: launchctl load $PLIST_FILE"
echo ""
echo "⚠️ Optional: Set up Google Indexing API"
echo "   Edit config.sh and add GOOGLE_SERVICE_ACCOUNT_JSON path"
echo ""
