---
name: "create-release"
description: "Create a GitHub Release with changelog and version tag. Trigger for: /create-release, release, cut a release, tag release, publish release, ship version. Bumps version, generates changelog from commits, tags, and publishes via gh CLI."
---

# Create Release

Tag a version and publish a GitHub Release with an auto-generated changelog.

## Invocation Forms
- `/create-release` — infer next version from latest tag + commits
- `/create-release <version>` — use exact version (e.g. `v1.2.0`)
- `/create-release <version> --pre` — mark as pre-release

## Versioning

Follow [Semantic Versioning](https://semver.org): `vMAJOR.MINOR.PATCH`

| Bump | When |
|------|------|
| PATCH | only `fix/` or `chore/` commits since last tag |
| MINOR | any `feat/` commit since last tag |
| MAJOR | any `BREAKING CHANGE` in commit body, or `!` after type (e.g. `feat!:`) |

## Workflow

### 1. Check current state
```bash
git fetch --tags
git tag --sort=-v:refname | head -5      # latest tags
git log <last-tag>...HEAD --oneline      # commits since last release
git status                               # must be clean
```
If working tree is dirty: stop and warn — release from a clean state.

### 2. Determine next version
- Parse latest tag (default `v0.0.0` if none exists)
- Scan commit types since last tag → apply semver bump rule above
- If user provided a version, use it as-is

### 3. Generate changelog
Group commits since last tag by type:

```markdown
## What's Changed

### Features
- <commit message> (<short sha>)

### Bug Fixes
- <commit message> (<short sha>)

### Chores / Maintenance
- <commit message> (<short sha>)

**Full Changelog:** https://github.com/<owner>/<repo>/compare/<prev-tag>...<new-tag>
```

Skip merge commits (`Merge branch`, `Merge pull request`).

### 4. Create and push tag
```bash
git tag -a <version> -m "Release <version>"
git push origin <version>
```

### 5. Publish GitHub Release
```bash
gh release create <version> \
  --title "Release <version>" \
  --notes "$(cat <<'EOF'
<changelog>
EOF
)"
```

Add `--prerelease` flag if `--pre` was requested.

### 6. Handle release assets (optional)
If the project has a build step, ask: "Include build artifacts? (yes/no)"

If yes — run the build and attach:
```bash
gh release upload <version> <artifact-path>
```

Common patterns:
- Go: `go build -o dist/<name>` → attach `dist/<name>`
- Node: `npm run build` → attach `dist/` as zip
- Docker: push image, note the tag in release notes

### 7. Output
- Release URL
- Version tag created
- One-line summary of what was included (feat count, fix count)

## Edge Cases
- **No commits since last tag**: stop — nothing to release
- **Tag already exists**: stop and show existing release URL
- **No tags exist yet**: start from `v0.1.0` (not `v0.0.1` — first releases are minor)
- **main not up to date**: warn before tagging
- **Pre-release naming**: append `-beta.1`, `-rc.1`, etc. when `--pre` is used
