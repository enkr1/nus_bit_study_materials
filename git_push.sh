#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# This is a reliable way to get the script's directory, regardless of how it's called.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

cd "$SCRIPT_DIR"

# Check if we are in a git repository before proceeding
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not a git repository in '$SCRIPT_DIR'. Aborting."
  exit 1
fi

# Get current branch name
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

# Check if remote origin exists
if ! git remote get-url origin > /dev/null 2>&1; then
  echo "Warning: No remote 'origin' found. Skipping pull operation."
else
  echo "Pulling latest changes from origin/$CURRENT_BRANCH..."

  # Check if remote branch exists
  if git ls-remote --exit-code --heads origin "$CURRENT_BRANCH" > /dev/null 2>&1; then
    # Stash any uncommitted changes before pulling
    if ! git diff-index --quiet HEAD --; then
      echo "Stashing uncommitted changes..."
      git stash push -m "Auto-stash before pull $(date '+%Y-%m-%d %H:%M:%S')"
      STASHED=true
    else
      STASHED=false
    fi

    # Pull from remote
    if git pull origin "$CURRENT_BRANCH"; then
      echo "Successfully pulled from origin/$CURRENT_BRANCH"

      # Pop stashed changes if any
      if [ "$STASHED" = true ]; then
        echo "Restoring stashed changes..."
        if git stash pop; then
          echo "Stashed changes restored successfully"
        else
          echo "Warning: Conflict while restoring stashed changes. Please resolve manually."
          echo "Use 'git stash list' to see stashed changes and 'git stash apply' to retry."
        fi
      fi
    else
      echo "Error: Failed to pull from origin/$CURRENT_BRANCH"
      if [ "$STASHED" = true ]; then
        echo "Your changes are safely stashed. Use 'git stash pop' to restore them."
      fi
      exit 1
    fi
  else
    echo "Remote branch 'origin/$CURRENT_BRANCH' does not exist. Skipping pull."
  fi
fi

echo "Adding all changes to git..."
git add .

# Only commit if there are actual changes
if git diff-index --quiet HEAD --; then
    echo "No changes to commit. Working tree clean."
else
    # Generate a more descriptive commit message
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "Committing changes..."
    git commit -m ":zap: [auto-push] $TIMESTAMP"
fi

echo "Pushing to the remote repository..."
if git push origin "$CURRENT_BRANCH"; then
  echo "Successfully pushed to origin/$CURRENT_BRANCH"
else
  echo "Error: Failed to push to origin/$CURRENT_BRANCH"
  exit 1
fi

echo "Auto-push complete!"
echo "Summary:"
echo "  - Branch: $CURRENT_BRANCH"
echo "  - Remote: $(git remote get-url origin 2>/dev/null || echo 'No remote configured')"
echo "  - Last commit: $(git log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || echo 'No commits')"
