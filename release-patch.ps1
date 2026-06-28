param(
    [Parameter(Mandatory = $true)]
    [string]$Changes,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectDir

$releaseRepo = "Musafir02/arcmusic-app"

# Read current version
$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version: ' | ForEach-Object { $_.Line }
$version = ($versionLine -split ': ')[1].Trim()
$parts = $version -split '\+'
$ver = $parts[0]
$build = [int]$parts[1] + 1
$newVersion = "$ver+$build"
$tag = "v$newVersion"

Write-Host "Patch release $newVersion ..." -ForegroundColor Cyan

# Update pubspec.yaml build number
(Get-Content "pubspec.yaml") -replace "^version: .+", "version: $newVersion" | Set-Content "pubspec.yaml"
Write-Host "Version bumped: $version -> $newVersion" -ForegroundColor Yellow

# Build APK (required by flutter_patcher:pack to extract libapp.so)
Write-Host "Building APK (required for patch extraction) ..." -ForegroundColor Cyan
flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }

# Confirm before committing
if (-not $Force) {
    $confirm = Read-Host "Commit, tag, and release $tag? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 1
    }
}

# Commit and tag in local repo
git add pubspec.yaml
git commit -m "patch: $tag"
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

# Generate patch.zip
$apkDir = "build\app\outputs\flutter-apk"
Write-Host "Generating patch.zip ..." -ForegroundColor Cyan
$versionCode = $build
dart run flutter_patcher:pack `
  --apk (Join-Path $apkDir "app-arm64-v8a-release.apk") `
  --version "$newVersion" `
  --target-version-code $versionCode
if ($LASTEXITCODE -ne 0) { throw "patch generation failed" }

$patchZip = Join-Path $apkDir "patch.zip"
if (Test-Path "dist\patch.zip") {
    Copy-Item -Path "dist\patch.zip" -Destination $patchZip -Force
    Remove-Item -Recurse -Force "dist" -ErrorAction SilentlyContinue
    Write-Host "patch.zip generated: $( (Get-Item $patchZip).Length / 1KB ) KB" -ForegroundColor Green
} else {
    throw "patch.zip not found in dist/"
}

# Create GitHub Release with just the patch
$notesFile = [System.IO.Path]::GetTempFileName()
$notesText = @"
## $tag (Patch)

$Changes

**OTA Patch:** patch.zip — auto-applied in-app on next restart.
"@
[System.IO.File]::WriteAllText($notesFile, $notesText)

gh release create "$tag" $patchZip --title "ArcMusic $tag (Patch)" --notes-file "$notesFile" --repo "$releaseRepo"
Remove-Item -LiteralPath $notesFile -Force

if ($LASTEXITCODE -eq 0) {
    Write-Host "Patch release $tag published!" -ForegroundColor Green
    Write-Host "URL: https://github.com/$releaseRepo/releases/tag/$tag" -ForegroundColor Cyan
} else {
    throw "GitHub Release creation failed"
}
