param(
    [Parameter(Mandatory = $true)]
    [string]$Changes,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectDir

# Use the repo that the app's update service checks
$releaseRepo = "Musafir02/arcmusic-app"
$githubUrl = "https://github.com/$releaseRepo"

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

# Confirm before committing
if (-not $Force) {
    $confirm = Read-Host "Commit and tag $tag? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 1
    }
}

# Commit and tag in local repo
git add pubspec.yaml
git commit -m "release: $tag"
git tag "$tag"

# Push tag to release repo
$remoteName = "release-upstream"
$existingRemote = git remote -v | Select-String "$releaseRepo"
if (-not $existingRemote) {
    git remote add "$remoteName" "https://github.com/$releaseRepo.git"
} else {
    $remoteName = ($existingRemote -split '\s')[0]
}
git push "$remoteName" tag $tag

# Rename ARM APKs (skip x86_64)
$apkDir = "build\app\outputs\flutter-apk"
$uploadApks = @()
$archMap = @{
    "arm64-v8a"  = "arcmusic-arm64-v8a.apk"
    "armeabi-v7a" = "arcmusic-armeabi-v7a.apk"
}
foreach ($arch in $archMap.Keys) {
    $src = Join-Path $apkDir "app-$arch-release.apk"
    if (Test-Path $src) {
        $dst = Join-Path $apkDir $archMap[$arch]
        Copy-Item -Path $src -Destination $dst -Force
        $uploadApks += $dst
    }
}

Write-Host "Creating GitHub Release $tag ..." -ForegroundColor Cyan

# Generate patch.zip for flutter_patcher OTA updates
$patchDir = Join-Path $apkDir "patch_dist"
Write-Host "Generating patch.zip ..." -ForegroundColor Cyan
$versionCode = ($version -split '\+')[1]
dart run flutter_patcher:pack `
  --apk (Join-Path $apkDir "app-arm64-v8a-release.apk") `
  --version "$version" `
  --target-version-code $versionCode
if ($LASTEXITCODE -eq 0) {
    $patchZip = Join-Path $apkDir "patch.zip"
    if (Test-Path "dist\patch.zip") {
        Copy-Item -Path "dist\patch.zip" -Destination $patchZip -Force
        Remove-Item -Recurse -Force "dist" -ErrorAction SilentlyContinue
        $uploadApks += $patchZip
        Write-Host "patch.zip generated: $( (Get-Item $patchZip).Length / 1KB ) KB" -ForegroundColor Green
    }
}

# Create GitHub Release
$notesFile = [System.IO.Path]::GetTempFileName()
$notesText = @"
## $tag

$Changes

**APKs:**
- arm64-v8a (recommended for most modern devices)
- armeabi-v7a (older devices)

**OTA Patch:** patch.zip (auto-applied in-app, ~95% smaller than full APK)
"@
[System.IO.File]::WriteAllText($notesFile, $notesText)

gh release create "$tag" $uploadApks --title "ArcMusic $tag" --notes-file "$notesFile" --repo "$releaseRepo"
Remove-Item -LiteralPath $notesFile -Force

if ($LASTEXITCODE -eq 0) {
    Write-Host "Release $tag published successfully!" -ForegroundColor Green
    Write-Host "URL: https://github.com/$releaseRepo/releases/tag/$tag" -ForegroundColor Cyan
} else {
    throw "GitHub Release creation failed"
}
