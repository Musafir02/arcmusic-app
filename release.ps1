param(
    [Parameter(Mandatory = $true)]
    [string]$Changes
)

$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectDir

# Read current version from pubspec.yaml
$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version: ' | ForEach-Object { $_.Line }
$version = ($versionLine -split ': ')[1].Trim()

Write-Host "Building release $version ..." -ForegroundColor Cyan

# Build APKs
flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }

# Determine tag
$tag = "v$version"

# Check if tag already exists
$tagExists = git tag -l "$tag"
if ($tagExists) {
    Write-Host "Tag $tag already exists. Creating a new version..."
    # Increment build number
    $parts = $version -split '\+'
    $ver = $parts[0]
    $build = [int]$parts[1] + 1
    $version = "$ver+$build"

    # Update pubspec.yaml
    (Get-Content "pubspec.yaml") -replace '^version: .+', "version: $version" | Set-Content "pubspec.yaml"
    $tag = "v$version"
    Write-Host "New version: $version" -ForegroundColor Yellow

    # Rebuild with new version
    flutter build apk --release --split-per-abi
    if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }
}

# Git tag and push
git add pubspec.yaml
git commit -m "release: $tag"
git tag "$tag"
git push origin master --tags

# Find APK files
$apkDir = "build\app\outputs\flutter-apk"
$apks = Get-ChildItem -Path $apkDir -Filter "*-release.apk" | ForEach-Object { $_.FullName }

Write-Host "Creating GitHub Release $tag ..." -ForegroundColor Cyan

# Create GitHub Release
$notes = @"
## $tag

$Changes

**APKs:**
- arm64-v8a (recommended for most modern devices)
- armeabi-v7a (older devices)
"@

$notes | gh release create "$tag" $apks --title "$tag" --notes -

if ($LASTEXITCODE -eq 0) {
    Write-Host "Release $tag published successfully!" -ForegroundColor Green
    Write-Host "URL: https://github.com/Musafir02/arcmusic/releases/tag/$tag" -ForegroundColor Cyan
} else {
    throw "GitHub Release creation failed"
}
