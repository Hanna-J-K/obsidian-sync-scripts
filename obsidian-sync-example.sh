
#!/bin/bash

set -uo pipefail

# local config
VAULT="absolute/path/to/obsidian/vault"
PERSONAL_GH_USER="GITHUB_USERNAME"
BRANCH="main"
EXPECTED_REMOTE="https://github.com/GITHUB_USERNAME/REPOSITORY_NAME.git"

# the exported variables are needed because launchd needs a fresh setup for individual shell config
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PERSONAL_GH_USER
export GIT_TERMINAL_PROMPT=0
export GIT_EDITOR=true
export GIT_SEQUENCE_EDITOR=true

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# explicitly select personal credentials without switching gh accounts.
# yes i assume Github CLI (gh) is used for authentication and yes i often have more than one account logged in 
# so we're naming a specific one rather than currently active one

GIT_AUTH_HELPER='!f() {
  if [ "$1" = get ]; then
    token=$(gh auth token --hostname github.com --user "$PERSONAL_GH_USER") || exit 1
    printf "username=x-access-token\npassword=%s\n" "$token"
  fi
}; f'

git_auth() {
  git -c credential.helper= \
      -c "credential.helper=$GIT_AUTH_HELPER" \
      "$@"
}

validate_repo() {
  local root current_branch remote git_dir

  if ! cd "$VAULT"; then
    log "ERROR: Cannot access vault: $VAULT"
    return 1
  fi

  root=$(git rev-parse --show-toplevel) || return 1
  if [[ "$root" != "$PWD" ]]; then
    log "ERROR: Vault must be the root of its Git repository."
    return 1
  fi

  current_branch=$(git symbolic-ref --quiet --short HEAD) || {
    log "ERROR: Repository has a detached HEAD or no active branch."
    return 1
  }
  if [[ "$current_branch" != "$BRANCH" ]]; then
    log "ERROR: Expected branch '$BRANCH', found '$current_branch'."
    return 1
  fi

  remote=$(git remote get-url origin) || return 1
  if [[ "$remote" != "$EXPECTED_REMOTE" ||
        ! "$remote" =~ ^https://github[.]com/[^/@:]+/[^/@:]+$ ]]; then
    log "ERROR: Origin does not match the expected HTTPS GitHub repository."
    return 1
  fi

  # an unfinished operation must be resolved before an automated sync.
  git_dir=$(git rev-parse --absolute-git-dir) || return 1
  if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ||
        -f "$git_dir/MERGE_HEAD" || -f "$git_dir/CHERRY_PICK_HEAD" ||
        -f "$git_dir/REVERT_HEAD" ]]; then
    log "ERROR: An unfinished Git operation requires manual attention."
    return 1
  fi

  # git add and commit must never run with unresolved conflict markers.
  if [[ -n "$(git ls-files -u)" ]]; then
    log "ERROR: Index contains unresolved merge conflicts."
    return 1
  fi
}

sync_vault() {
  local diff_status

  validate_repo || return 1
  log "Starting sync for $VAULT"

  # commit local files before integrating changes from another device.
  git add -A || return 1
  git diff --cached --quiet
  diff_status=$?

  case "$diff_status" in
    0) log "No local changes to commit." ;;
    1)
      if ! git commit -m "Obsidian sync: $(date '+%Y-%m-%d %H:%M:%S')"; then
        log "ERROR: Local commit failed."
        return 1
      fi
      ;;
    *)
      log "ERROR: Could not inspect staged changes."
      return 1
      ;;
  esac

  # do not try to rebase over changes produced while committing.
  if [[ -n "$(git status --porcelain)" ]]; then
    log "ERROR: Working tree changed during preparation; retry later."
    return 1
  fi

  log "Fetching remote branch $BRANCH..."
  if ! git_auth fetch --no-tags origin "refs/heads/$BRANCH"; then
    log "ERROR: Fetch failed. Local commits are preserved."
    return 1
  fi

  log "Integrating remote changes..."
  if ! git -c rebase.autoStash=false rebase --no-autostash FETCH_HEAD; then
    log "ERROR: Rebase failed; attempting to restore the pre-rebase state."
    if ! git rebase --abort; then
      log "ERROR: Rebase abort failed. Manual Git repair is required."
    fi
    log "Push skipped. Inspect the vault before retrying."
    return 1
  fi

  # if obsidian changed files during the rebase, defer the push.
  if [[ -n "$(git status --porcelain)" ]]; then
    log "ERROR: Working tree changed during sync. Push skipped."
    return 1
  fi

  log "Pushing to GitHub..."
  if ! git_auth push origin "HEAD:refs/heads/$BRANCH"; then
    log "ERROR: Push failed. Will retry on the next launch."
    return 1
  fi

  log "Sync complete."
}

if sync_vault; then
  exit 0
else
  log "ERROR: Synchronization did not complete."
  exit 1
fi
