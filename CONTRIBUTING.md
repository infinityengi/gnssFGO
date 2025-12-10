# Contributing Guidelines

## Project Structure

This project uses Git submodules to manage multiple repositories:

```
Hiwi_project_gnss/ (main project)
├── gnssFGO/ (submodule)
│   └── irt_gnss_preprocessing/ (submodule within gnssFGO)
│       └── driver_modification/
│           ├── novatel_oem7_driver/ (submodule)
│           └── septentrio_gnss_driver/ (submodule)
```

## Making Changes

### 1. **Cloning the Repository**

To get the full project with all submodules:

```bash
git clone --recurse-submodules https://git-ce.rwth-aachen.de/om.sahu/gnss_fgo_preprocessing_module_septentrio_driver.git
cd Hiwi_project_gnss
```

### 2. **Making Changes to the Main Project**

Changes in the main project root files:

```bash
# Edit files in the root directory
git add <file>
git commit -m "your message"
git push
```

### 3. **Making Changes Inside Submodules**

#### Working with gnssFGO submodule:

```bash
cd gnssFGO

# Make changes
git add <file>
git commit -m "your message"
git push  # Only if you have permission to push to the upstream

# Go back to main project
cd ..

# Update the main project to track the new commit
git add gnssFGO
git commit -m "Update gnssFGO submodule: [description of changes]"
git push
```

#### Working with driver repositories (inside irt_gnss_preprocessing):

```bash
cd gnssFGO/irt_gnss_preprocessing/driver_modification/novatel_oem7_driver

# Make changes
git add <file>
git commit -m "your message"
git push  # Only if you have permission

# Navigate back to main project
cd ../../../../../

# Update the main project to track the changes
git add gnssFGO
git commit -m "Update gnssFGO: driver repositories updated"
git push
```

### 4. **Updating Submodules to Latest**

To pull the latest changes from upstream repositories:

```bash
# Update all submodules
git submodule update --remote --recursive

# Or update specific submodule
git submodule update --remote gnssFGO
```

### 5. **Commit Message Convention**

Follow this format for consistency:

- **Main project changes**: `feature|fix|docs: Brief description`
- **Submodule updates**: `Update <submodule_name>: Brief description`
- **Driver changes**: `Update gnssFGO: <driver_name> - description`

Examples:
```
docs: Update CHANGELOG with new features
feature: Add preprocessing pipeline configuration
fix: Resolve merge conflict in README
Update gnssFGO: Add driver repositories
Update gnssFGO: novatel_oem7_driver - fix GPS decoding issue
```

## Workflow Summary

```bash
# 1. Clone (first time only)
git clone --recurse-submodules <repo-url>
cd Hiwi_project_gnss

# 2. Make changes to your submodule
cd gnssFGO/path/to/file
git add <file>
git commit -m "Description"
cd ../../..

# 3. Update main project reference
git add gnssFGO
git commit -m "Update gnssFGO: Description"
git push

# 4. Update CHANGELOG.md with your changes
# Edit CHANGELOG.md in the [Unreleased] section

# 5. Final commit
git add CHANGELOG.md
git commit -m "docs: Update CHANGELOG with [feature/fix]"
git push
```

## Important Notes

⚠️ **Read-Only Repositories**: Some submodules (like `irt_gnss_preprocessing`, `novatel_oem7_driver`) are from upstream organizations and cannot be pushed to directly. These serve as references in your local development.

✅ **Your Personal Forks**: For repositories you can modify, ensure you have proper access before pushing.

📝 **Always Update CHANGELOG**: Before pushing, remember to update `CHANGELOG.md` with your changes in the `[Unreleased]` section.

## Getting Help

If you encounter issues with submodules:

```bash
# Check submodule status
git submodule status

# Reinitialize all submodules
git submodule update --init --recursive

# Clean and reset submodules
git submodule foreach --recursive git clean -fdx
git submodule foreach --recursive git reset --hard
```
