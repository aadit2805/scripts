#!/bin/bash

# =============================================================================
# Resume Auto-Sync Script
# =============================================================================
# Automatically syncs a resume PDF to a web project and deploys to Vercel.
# Designed to be triggered by macOS launchd when the source file changes.
#
# Setup:
#   1. Configure the variables below
#   2. Create a launchd plist to watch your source file (see example below)
#   3. Load the agent: launchctl load ~/Library/LaunchAgents/your-plist.plist
#
# Example launchd plist (save to ~/Library/LaunchAgents/com.yourname.resume-sync.plist):
#
#   <?xml version="1.0" encoding="UTF-8"?>
#   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
#   <plist version="1.0">
#   <dict>
#       <key>Label</key>
#       <string>com.yourname.resume-sync</string>
#       <key>ProgramArguments</key>
#       <array>
#           <string>/bin/bash</string>
#           <string>/path/to/sync-resume.sh</string>
#       </array>
#       <key>WatchPaths</key>
#       <array>
#           <string>/Users/yourname/Documents/Your-Resume.pdf</string>
#       </array>
#       <key>RunAtLoad</key>
#       <false/>
#   </dict>
#   </plist>
#
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration - Update these for your setup
# -----------------------------------------------------------------------------

# Source: Where you save your updated resume
SOURCE_FILE="$HOME/Documents/Your-Name-Resume.pdf"

# Destination: Where the resume lives in your web project
DEST_FILE="$HOME/path/to/your-project/public/resume.pdf"

# Project directory (for git operations)
PROJECT_DIR="$HOME/path/to/your-project"

# Git branch to push to
GIT_BRANCH="main"

# Log file location
LOG_FILE="$PROJECT_DIR/scripts/resume-sync.log"

# Enable/disable features
ENABLE_GIT=true           # Commit and push changes
ENABLE_VERCEL=true        # Deploy with Vercel CLI
ENABLE_NOTIFICATIONS=true # macOS notifications

# -----------------------------------------------------------------------------
# Script - No changes needed below this line
# -----------------------------------------------------------------------------

# Load nvm if available (needed for Vercel CLI installed via npm)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

notify() {
    if [ "$ENABLE_NOTIFICATIONS" = true ]; then
        osascript -e "display notification \"$1\" with title \"Resume Sync\""
    fi
}

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    log "ERROR: Source file not found: $SOURCE_FILE"
    exit 1
fi

# Check if file actually changed (compare checksums)
if [ -f "$DEST_FILE" ]; then
    SOURCE_HASH=$(md5 -q "$SOURCE_FILE" 2>/dev/null || md5sum "$SOURCE_FILE" | cut -d' ' -f1)
    DEST_HASH=$(md5 -q "$DEST_FILE" 2>/dev/null || md5sum "$DEST_FILE" | cut -d' ' -f1)
    if [ "$SOURCE_HASH" = "$DEST_HASH" ]; then
        log "No changes detected, skipping sync"
        exit 0
    fi
fi

log "Starting resume sync..."

# Copy the file
mkdir -p "$(dirname "$DEST_FILE")"
cp "$SOURCE_FILE" "$DEST_FILE"
if [ $? -ne 0 ]; then
    log "ERROR: Failed to copy file"
    notify "Failed to copy resume"
    exit 1
fi
log "Copied resume to project"

# Git commit and push
if [ "$ENABLE_GIT" = true ]; then
    cd "$PROJECT_DIR"

    RELATIVE_PATH="${DEST_FILE#$PROJECT_DIR/}"
    git add "$RELATIVE_PATH"
    git commit -m "Update resume

Auto-synced from $SOURCE_FILE"

    if [ $? -eq 0 ]; then
        git push origin "$GIT_BRANCH"
        if [ $? -eq 0 ]; then
            log "Pushed to git ($GIT_BRANCH)"
        else
            log "ERROR: Git push failed"
            notify "Git push failed"
            exit 1
        fi
    else
        log "No git changes to commit"
    fi
fi

# Deploy with Vercel CLI
if [ "$ENABLE_VERCEL" = true ]; then
    cd "$PROJECT_DIR"
    vercel --prod --yes
    if [ $? -eq 0 ]; then
        log "Vercel deployment triggered successfully"
    else
        log "ERROR: Vercel deployment failed"
        notify "Vercel deployment failed"
        exit 1
    fi
fi

log "Resume sync completed successfully"
notify "Resume updated and deployed"
