# Release Process

This document describes the automated release workflow for bash-logger.

## Overview

The project uses **semantic-release** to automate version management and releases based on commit messages that follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

## How It Works

### Automated Release Workflow

When commits are pushed to the `main` branch:

1. **Analyze commits** - Examines commit messages since the last release
2. **Determine version** - Calculates the next version based on commit types:
   * `feat:` → Minor version bump (0.9.0 → 0.10.0)
   * `fix:`, `perf:`, `refactor:` → Patch version bump (0.9.0 → 0.9.1)
   * `BREAKING CHANGE:` in commit footer → Major version bump (0.9.0 → 1.0.0)
   * `docs:`, `style:`, `test:`, `chore:`, `ci:` → No release
3. **Update files** - Automatically updates:
   * `BASH_LOGGER_VERSION` in [logging.sh](../logging.sh)
   * [CHANGELOG.md](../CHANGELOG.md) with release notes
4. **Package for consumers** - Creates distribution packages with:
   * logging.sh (main module)
   * configuration/ (example configs)
   * demo-scripts/ (usage examples)
   * docs/ (user documentation only)
   * README.md, LICENSE, CHANGELOG.md
   * Available as .tar.gz and .zip with SHA256 checksums
5. **Create release** - Creates GitHub release with:
   * Git tag
   * Release notes generated from commits
   * Downloadable packages (.tar.gz and .zip)
   * SHA256 checksums for verification
6. **Commit changes** - Commits updated files back to repository

### Version Tracking

The version is tracked in two places:

1. **logging.sh** - `BASH_LOGGER_VERSION` constant at the top of the file
2. **CHANGELOG.md** - Maintains complete release history
3. **Git tags** - Each release creates a version tag (e.g., `0.9.0`, `0.10.0`)

## Initial Setup (One-Time)

To enable releases starting from the current version (0.9.0):

### 1. Bootstrap Initial Version

```bash
# Create the initial version tag
./scripts/bootstrap-version.sh

# Push the tag
git push origin 0.9.0
```

### 2. Commit Release Configuration

```bash
# Stage the new files
git add .releaserc.json \
        .github/workflows/release.yml \
        logging.sh \
        scripts/bootstrap-version.sh \
        docs/releases.md

# Commit with semantic message
git commit -m "chore(ci): add semantic-release workflow

- Add semantic-release configuration
- Add release workflow for automated versioning
- Add BASH_LOGGER_VERSION constant to logging.sh
- Add bootstrap script for initial version tag"

# Push to trigger first automated release check
git push origin main
```

### 3. Verify Setup

After pushing:

1. Check the [Actions tab](../../actions) in GitHub
2. The release workflow should run
3. Since we just set up the system, it may not create a release yet
4. Next semantic commit will trigger a release

## Making Releases

Once set up, releases happen automatically when you push commits to `main` with
semantic commit messages.

### Commit Message Format

Follow the format enforced by the pre-commit hook:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Examples:**

```bash
# Feature - triggers minor version bump
git commit -m "feat(logging): add JSON output format"

# Bug fix - triggers patch version bump
git commit -m "fix(config): prevent duplicate log entries"

# Performance - triggers patch version bump
git commit -m "perf(output): optimize color code caching"

# Breaking change - triggers major version bump
git commit -m "refactor(api): rename init_logger to initialize

BREAKING CHANGE: init_logger function has been renamed to initialize.
Update all calls from init_logger() to initialize()."

# Documentation - no release
git commit -m "docs: update getting started guide"
```

### Release Types

| Commit Type               | Version Change | Example            |
| ------------------------- | -------------- | ------------------ |
| `feat:`                   | Minor (0.x.0)  | 0.9.0 → 0.10.0     |
| `fix:`, `perf:`           | Patch (0.0.x)  | 0.9.0 → 0.9.1      |
| `BREAKING CHANGE:` footer | Major (x.0.0)  | 0.9.0 → 1.0.0      |
| `docs:`, `chore:`, etc.   | None           | No release created |

## Checking Version Information

### In Code

Users can check the version programmatically:

```bash
source logging.sh
echo "Using bash-logger version: $BASH_LOGGER_VERSION"
```

### From Git

```bash
# Latest version tag
git describe --tags --abbrev=0

# All version tags
git tag -l
```

### From GitHub

* View releases: [Releases page](../../releases)
* Download specific version: [Tags page](../../tags)

### Downloading Release Packages

Each release provides consumer-friendly packages:

**Download from GitHub Releases:**

1. Go to [Releases page](../../releases)
2. Choose a version
3. Download either:
   * `bash-logger-X.Y.Z.tar.gz` (Linux/Mac)
   * `bash-logger-X.Y.Z.zip` (Windows/any)
4. Verify with SHA256 checksum file

**Package contents:**

```
bash-logger-X.Y.Z/
├── logging.sh              # Main module
├── configuration/          # Example configs
├── demo-scripts/           # Usage examples
├── docs/                   # User documentation
├── README.md               # Overview
├── INSTALL.md              # Installation guide
├── CHANGELOG.md            # Version history
└── LICENSE                 # MIT License
```

**Quick installation:**

```bash
# Extract
tar -xzf bash-logger-0.10.0.tar.gz
cd bash-logger-0.10.0

# Copy to your project
cp logging.sh /path/to/your/project/

# Or try demos
cd demo-scripts
./run_demos.sh
```

## Manual Release (If Needed)

If you need to create a release manually (not recommended):

```bash
# Create and push a tag
git tag -a 0.10.0 -m "Release 0.10.0"
git push origin 0.10.0

# Manually update logging.sh
sed -i 's/readonly BASH_LOGGER_VERSION=".*"/readonly BASH_LOGGER_VERSION="0.10.0"/' logging.sh

# Commit the version update
git add logging.sh
git commit -m "chore(release): 0.10.0"
git push origin main
```

## Troubleshooting

### Release Workflow Didn't Run

**Check:**

* Commit message contains `[skip ci]`? This prevents the workflow from running
* Commits use semantic format? Non-semantic commits won't trigger releases
* Workflow file exists at `.github/workflows/release.yml`?

### Release Created But Files Not Updated

**Check:**

* GitHub token has write permissions (set in workflow)
* No conflicts in CHANGELOG.md
* `logging.sh` not modified locally

### Version Skipped Expected Number

This is normal. Semantic-release may skip versions based on commit history.
For example, if multiple fixes are committed before release, only one patch
version is created.

### Need to Undo a Release

You cannot delete a release without affecting history. Instead:

1. Fix the issue in a new commit
2. Create a new release with the fix
3. Optionally mark the bad release as "pre-release" in GitHub

## Configuration

The release behavior is controlled by [.releaserc.json](../.releaserc.json).

**Key settings:**

* `branches: ["main"]` - Only releases from main branch
* `tagFormat` - Version tag format (no 'v' prefix)
* Release rules mapping commit types to version bumps
* Files to update on release
* GitHub release asset configuration

## Resources

* [Semantic Release Documentation](https://semantic-release.gitbook.io/)
* [Conventional Commits](https://www.conventionalcommits.org/)
* [Keep a Changelog](https://keepachangelog.com/)
* [Semantic Versioning](https://semver.org/)
* [Project Contributing Guide](../CONTRIBUTING.md)

## Questions?

If you have questions about the release process:

1. Check this documentation
2. Review [CONTRIBUTING.md](../CONTRIBUTING.md) for commit message format
3. Check workflow runs in [GitHub Actions](../../actions)
4. Open an [issue](../../issues/new) if you find a problem
