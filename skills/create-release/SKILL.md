---
name: create-release
description: Create a GitHub Release with changelog and version tag. Trigger for: /create-release, release, cut a release, tag release, publish release, ship version. Bumps version, generates changelog from commits, tags, and publishes via gh CLI.
---

# Create Release

Tag a version, bump version files, write a changelog, and publish a GitHub Release with optional artifacts.

## Invocation Forms
- `/create-release` — auto-detect next version from tags + commits
- `/create-release <version>` — exact version, e.g. `v1.2.0`
- `/create-release <version> --pre` — pre-release, e.g. `v1.2.0-rc.1`
- `/create-release <version> --dry-run` — show what would happen, do nothing

## Versioning — Semantic Versioning

Format: `vMAJOR.MINOR.PATCH` (always with `v` prefix)

| Bump | Trigger |
|------|---------|
| PATCH | only `fix/`, `chore/`, `docs/`, `refactor/`, `ci/` commits |
| MINOR | any `feat/` commit |
| MAJOR | commit body contains `BREAKING CHANGE:`, or type uses `!` (e.g. `feat!:`, `fix!:`) |

Pre-release convention: `v1.2.0-beta.1`, `v1.2.0-rc.1`, `v1.2.0-alpha.1`

---

## Workflow

### 0. Prerequisites
```bash
# Git identity required for annotated tags
git config user.name  || { echo "ERROR: Set git user.name first"; exit 1; }
git config user.email || { echo "ERROR: Set git user.email first"; exit 1; }

# gh CLI must be authenticated
gh auth status 2>&1 | grep -q "Logged in" || { echo "ERROR: Run gh auth login"; exit 1; }

# Must be on the correct branch (main or release/*)
git branch --show-current
```

### 1. Verify clean state
```bash
git fetch --tags --prune
git status --porcelain
```
If output is not empty → STOP: "Working tree is dirty — commit or stash first."

Check that local branch is up to date with remote:
```bash
git log origin/$(git branch --show-current)..HEAD --oneline | wc -l
```
If commits exist that aren't pushed → warn: "Unpushed commits exist — push first."

### 2. Find latest tag
```bash
LAST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]' | head -1)
echo "Last release: ${LAST_TAG:-none (first release)}"
```
Default when no tags exist: `v0.1.0` (first release is always a MINOR).

### 3. List commits since last tag
```bash
git log ${LAST_TAG:+${LAST_TAG}...HEAD} --oneline --no-merges
```
If no commits → STOP: "Nothing to release — no commits since ${LAST_TAG}."

### 4. Auto-detect version bump
```bash
COMMITS=$(git log ${LAST_TAG:+${LAST_TAG}...HEAD} --format="%s%n%b" --no-merges)

# MAJOR: breaking change
echo "$COMMITS" | grep -qE '(BREAKING CHANGE:|^[a-z]+(\(.+\))?!:)' && BUMP=major

# MINOR: new feature
echo "$COMMITS" | grep -qE '^feat(\(.+\))?:' && [ -z "$BUMP" ] && BUMP=minor

# PATCH: everything else
BUMP=${BUMP:-patch}

echo "Bump type: $BUMP"
```

### 5. Calculate next version
```bash
# Strip 'v' prefix and split
IFS='.' read -r MAJOR MINOR PATCH <<< "${LAST_TAG#v}"
MAJOR=${MAJOR:-0}; MINOR=${MINOR:-0}; PATCH=${PATCH:-0}

case $BUMP in
  major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR+1)); PATCH=0 ;;
  patch) PATCH=$((PATCH+1)) ;;
esac

VERSION="v${MAJOR}.${MINOR}.${PATCH}"

# Pre-release suffix
[ -n "$PRE" ] && VERSION="${VERSION}-${PRE}"   # e.g. rc.1 passed via --pre rc.1

echo "Next version: $VERSION"
```

If user provided a version explicitly → skip steps 4–5, use it directly.

### 6. Verify tag does not exist
```bash
git tag --list "$VERSION" | grep -q . \
  && { echo "Tag $VERSION already exists: $(gh release view $VERSION --json url --jq .url)"; exit 1; }
```

### 7. Bump version in project files

Detect and update version references:

**Node.js — `package.json`:**
```bash
npm version "$VERSION" --no-git-tag-version
# or manually:
node -e "const p=require('./package.json'); p.version='${VERSION#v}'; \
  require('fs').writeFileSync('package.json', JSON.stringify(p, null, 2)+'\n')"
git add package.json package-lock.json
git commit -m "chore: bump version to $VERSION"
git push origin $(git branch --show-current)
```

**Python — `pyproject.toml` or `setup.cfg`:**
```bash
sed -i "s/^version = .*/version = \"${VERSION#v}\"/" pyproject.toml
git add pyproject.toml
git commit -m "chore: bump version to $VERSION"
git push
```

**Go — `cmd/<name>/version.go` (if exists):**
```bash
sed -i "s/Version = .*/Version = \"$VERSION\"/" cmd/*/version.go
git add .
git commit -m "chore: bump version to $VERSION"
git push
```

If no version file exists in the project → skip this step, tag only.

### 8. Generate changelog

Build the changelog from commit history:

```bash
git log ${LAST_TAG:+${LAST_TAG}...HEAD} --format="%s %h" --no-merges
```

Group by prefix into sections:

```markdown
## What's Changed in <VERSION>

### Breaking Changes
- <subject> (<sha>)   ← from `feat!:`, `fix!:`, `BREAKING CHANGE:` in body

### Features
- <subject> (<sha>)   ← from `feat:`, `feat(<scope>):`

### Bug Fixes
- <subject> (<sha>)   ← from `fix:`, `fix(<scope>):`

### Refactors
- <subject> (<sha>)   ← from `refactor:`

### Chores / Maintenance
- <subject> (<sha>)   ← from `chore:`, `docs:`, `ci:`, `build:`, `style:`, `test:`

**Full Changelog:** https://github.com/<owner>/<repo>/compare/<LAST_TAG>...<VERSION>
```

Rules:
- Omit sections with no commits
- Omit merge commits (`Merge branch`, `Merge pull request`)
- If a `feat!:` commit exists, it appears in Breaking Changes AND is omitted from Features

### 9. Append to `CHANGELOG.md`
```bash
# Prepend new entry at the top of CHANGELOG.md
ENTRY="## [$VERSION] - $(date +%Y-%m-%d)\n\n<changelog sections>\n"
if [ -f CHANGELOG.md ]; then
  sed -i "1s/^/$ENTRY\n/" CHANGELOG.md
else
  printf "# Changelog\n\n$ENTRY" > CHANGELOG.md
fi
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for $VERSION"
git push
```

### 10. Create and push tag
```bash
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"
```

Verify tag pushed:
```bash
git ls-remote --tags origin "$VERSION" | grep -q . \
  || { echo "ERROR: Tag push failed"; exit 1; }
```

### 11. Publish GitHub Release
```bash
gh release create "$VERSION" \
  --title "Release $VERSION" \
  --notes "$(cat <<'EOF'
<changelog>
EOF
)" \
  ${PRE:+--prerelease}
```

Alternatively, use GitHub's auto-generated notes as a supplement:
```bash
gh release create "$VERSION" \
  --title "Release $VERSION" \
  --generate-notes \
  --notes-start-tag "${LAST_TAG}"
```

Use `--generate-notes` when the project uses PRs with good titles — it pulls from merged PR titles automatically.

### 12. Build and attach artifacts (ask user)

Ask: "Attach build artifacts? (yes/no)"

**Go:**
```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-X main.Version=$VERSION" \
  -o dist/app-linux-amd64 ./cmd/...
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags="-X main.Version=$VERSION" \
  -o dist/app-darwin-arm64 ./cmd/...
gh release upload "$VERSION" dist/app-linux-amd64 dist/app-darwin-arm64
```

**Node.js:**
```bash
npm run build
zip -r dist-$VERSION.zip dist/
gh release upload "$VERSION" dist-$VERSION.zip
```

**Docker:**
```bash
docker build -t ghcr.io/12MICKY/<name>:$VERSION -t ghcr.io/12MICKY/<name>:latest .
docker push ghcr.io/12MICKY/<name>:$VERSION
docker push ghcr.io/12MICKY/<name>:latest
# Note image in release body — no file upload needed
```

### 13. Output
```
Released: v1.2.0
URL:      https://github.com/<owner>/<repo>/releases/tag/v1.2.0
Includes: 2 features, 1 fix, 3 chores
Artifacts: app-linux-amd64, app-darwin-arm64  (if attached)
```

---

## Dry Run Mode
When `--dry-run` is given:
- Show computed version, bump type, and full changelog
- Show which files would be modified
- Do NOT create tag, release, or commit anything

---

## Rollback a Bad Release

If a release needs to be pulled:

```bash
# 1. Delete the GitHub Release (keeps the tag)
gh release delete "$VERSION" --yes

# 2. Delete the tag remotely and locally
git push origin :refs/tags/"$VERSION"
git tag -d "$VERSION"

# 3. Revert the version bump commit if it was pushed
git revert <commit-sha> --no-edit
git push

# 4. Re-release when fixed
# /create-release <same-version>
```

---

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| No commits since last tag | STOP — nothing to release |
| Tag already exists | STOP — show existing release URL |
| No prior tags | Start at `v0.1.0` |
| Dirty working tree | STOP — must be clean |
| Git identity not set | STOP before tagging |
| `--pre` without suffix | Default to `-beta.1` |
| `--dry-run` | Print plan only, no changes |
| No version file found | Skip bump step, tag only |
| No CI on repo | Skip Gate 3 (no status checks) |
