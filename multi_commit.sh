#!/usr/bin/env bash
#
# Usage: ./multi_commit.sh [-p|--push] [remote] [branch]
# Automates multi-commit staging and pushing based on file categories.

set -euo pipefail

# Parse arguments
PUSH_AFTER=false
REMOTE="origin"
BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--push)
      PUSH_AFTER=true
      shift
      ;;
    *)
      if [[ -z "$REMOTE" || "$REMOTE" == "origin" ]]; then
        REMOTE="$1"
      elif [[ -z "$BRANCH" ]]; then
        BRANCH="$1"
      fi
      shift
      ;;
  esac
done

# Ensure we are inside a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not a git repository." >&2
  exit 1
fi

# Determine current branch if not provided
if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi

echo "Scanning repository state on branch: $BRANCH..."

# Helper function to stage and commit matched patterns
commit_group() {
  local commit_msg="$1"
  shift
  local patterns=("$@")

  # Stage files matching patterns
  for pattern in "${patterns[@]}"; do
    git add "$pattern" 2>/dev/null || true
  done

  # Check if anything was staged
  if ! git diff --cached --quiet; then
    git commit -m "$commit_msg"
    echo "✓ Committed: $commit_msg"
  fi
}

# 1. Documentation & Meta
commit_group "docs: update documentation and project metadata" \
  "*.md" "*.txt" "LICENSE" "docs/*" ".github/*"

# 2. Configuration & Build Scripts
commit_group "build: update configuration and dependency definitions" \
  "package.json" "package-lock.json" "yarn.lock" "pnpm-lock.yaml" \
  "Dockerfile" "docker-compose.yml" "Makefile" ".gitignore" \
  ".env.example" "*.config.js" "*.config.json" "tsconfig.json"

# 3. Source Code (Scripts, Modules, Source directory)
commit_group "feat: update core application source files" \
  "src/*" "lib/*" "app/*" "*.py" "*.js" "*.ts" "*.go" "*.rs" "*.cpp" "*.c" "*.h"

# 4. Tests & Fixtures
commit_group "test: update test suites and integration tests" \
  "test/*" "tests/*" "*.test.*" "*.spec.*"

# 5. Catch-all for remaining unstaged/untracked modifications
if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "chore: commit remaining assets and workspace changes"
  echo "✓ Committed: chore: commit remaining assets and workspace changes"
else
  echo "No remaining unstaged changes found."
fi

# Push if flag was supplied
if [[ "$PUSH_AFTER" == true ]]; then
  echo "Pushing changes to $REMOTE/$BRANCH..."
  git push "$REMOTE" "$BRANCH"
  echo "✓ Successfully pushed to $REMOTE/$BRANCH"
fi

echo "Multi-commit process complete."
