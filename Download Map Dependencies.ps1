# Script for downloading map dependencies extracted from a GBX file header.
# Skips entries with no or non-remote URLs.

# Usage:
# Paste your <dep> entries inside of a file next to this script called download_deps.txt
# Set your Maniaplanet documents folder below. No trailing slash.
$ManiaplanetDocuments = ""
# Run the script

Add-Type -AssemblyName System.Web

Write-Host "Maniaplanet Map Dependency Downloader`n"
$InputFile = Join-Path (Get-Location) "download_deps.txt"
$DownloadLog = Join-Path (Get-Location) "download_log.txt"

# Check if variables are set correctly
if (-not $ManiaplanetDocuments) {
    Write-Host "ERROR: ManiaplanetDocuments path is not set.`nPlease set the path at the top of the script." -ForegroundColor Red
	Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-Path $ManiaplanetDocuments)) {
    Write-Host "ERROR: ManiaplanetDocuments path does not exist: $ManiaplanetDocuments`nPlease check the path at the top of the script." -ForegroundColor Red
	Read-Host "Press Enter to exit"
    exit 1
}

# Check if file exists
if (-not (Test-Path $InputFile)) {
    Write-Host "ERROR: download_deps.txt not found in the current directory.`nPaste each <dep></dep> string on each line and save it to this file." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Load data from file
$lines = Get-Content $InputFile

# Check if file is empty
if (-not $lines) {
    Write-Host "ERROR: download_deps.txt is empty.`nPaste each <dep></dep> string on each line and save it to this file." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Not really necessary, but can be used, just a way to warn people if they're about to download duplicate files
# # Check if download_deps.txt has changed since the last run
# $HashFile  = Join-Path (Get-Location) "download_deps.hash"
# $currentHash = (Get-FileHash $InputFile -Algorithm MD5).Hash
# if (Test-Path $HashFile) {
#     $savedHash = Get-Content $HashFile
#     if ($currentHash -eq $savedHash) {
#         Write-Host "WARNING: download_deps.txt has not changed since the last download. You may have already downloaded these files." -ForegroundColor Yellow
#         Write-Host "Continue anyway? [Y/N]: " -NoNewline
#         $response = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#         Write-Host $response.Character
#         if ($response.Character.ToString().ToLower() -ne 'y') {
#             Write-Host "Cancelled." -ForegroundColor Red
#             Read-Host "Press Enter to exit"
#             exit 1
#         }
#         Write-Host ""
#     }
# }
# Set-Content -Path $HashFile -Value $currentHash

# Header with current date and time
$sessionHeader = "[START - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]"
Add-Content -Path $DownloadLog -Value "`n$sessionHeader"

# Writes an error and prints it to the console
function Write-ErrorLog($message) {
    Add-Content -Path $DownloadLog -Value ($message)
    Write-Host "[FAIL] $message" -ForegroundColor Red
}

# Writes a generic log entry
function Write-Log($message) {
    Add-Content -Path $DownloadLog -Value ($message)
}

# Parse <dep file="..." url="..."/> lines from the input file
$deps  = @()

foreach ($line in $lines) {
    # Extract file attribute
    if ($line -match 'file="([^"]+)"') {
        $filePath = $matches[1]
    } else {
        continue  # Not a dep line, skip
    }

    # Extract url attribute (optional)
    if ($line -match 'url="([^"]+)"') {
        $url = [System.Web.HttpUtility]::HtmlDecode($matches[1])
    } else {
        $url = $null
    }

    $deps += [PSCustomObject]@{ File = $filePath; Url = $url }
}

$total       = $deps.Count
$success     = 0
$skipped     = 0
$failed      = 0
$overwriteAll = $false
$skipAll      = $false

Write-Host "Parsed $total dep entries from download_deps.txt." -ForegroundColor Cyan
Write-Host ""

foreach ($dep in $deps) {
    # No URL at all
    if (-not $dep.Url) {
        Write-ErrorLog "NO URL: $($dep.File)"
        $skipped++
        continue
    }

    # Non-http URL (e.g. file://)
    if ($dep.Url -notmatch '^https?://') {
        Write-ErrorLog "SKIPPED (non-http URL '$($dep.Url)'): $($dep.File)"
        $skipped++
        continue
    }

    $destPath = Join-Path $ManiaplanetDocuments $dep.File
    $destDir  = Split-Path $destPath -Parent

    # Ensure destination directory exists
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Handle existing files
    if (Test-Path $destPath) {
        if ($skipAll) {
            Write-Log "SKIPPED (already exists): $($dep.File)"
            Write-Host "[SKIP] $($dep.File)" -ForegroundColor DarkYellow
            $skipped++
            continue
        }
        if (-not $overwriteAll) {
            Write-Host "[EXISTS] $($dep.File) - Overwrite? (Y/N/A=overwrite all/S=skip all): " -ForegroundColor Yellow -NoNewline
            $response = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Write-Host $response.Character
            $key = $response.Character.ToString().ToLower()
            $shouldSkip = $false
            switch ($key) {
                'a' { $overwriteAll = $true }
                's' {
                    $skipAll = $true
                    Write-Log "SKIPPED (already exists): $($dep.File)"
                    Write-Host "[SKIP] $($dep.File)" -ForegroundColor DarkYellow
                    $skipped++
                    $shouldSkip = $true
                }
                'n' {
                    Write-Log "SKIPPED (already exists): $($dep.File)"
                    Write-Host "[SKIP] $($dep.File)" -ForegroundColor DarkYellow
                    $skipped++
                    $shouldSkip = $true
                }
            }
            if ($shouldSkip) { continue }
        }
    }

    try {
        Invoke-WebRequest -Uri $dep.Url -OutFile $destPath -UseBasicParsing -ErrorAction Stop
        Write-Log "OK: $($dep.File) | URL: $($dep.Url)"
        Write-Host "[OK] $($dep.File)" -ForegroundColor Green
        $success++
    }
    catch {
        Write-ErrorLog "DOWNLOAD FAILED: $($dep.File) | URL: $($dep.Url) | Error: $($_.Exception.Message)"
        $failed++
    }
}

Write-Log "DONE: $success downloaded, $skipped skipped, $failed failed."

Write-Host ""
Write-Host "Done. $success downloaded, $skipped skipped, $failed failed." -ForegroundColor Cyan
Write-Host "See download_log.txt for a full activity log." -ForegroundColor Cyan
Write-Host ""
Write-Host "Clear download_deps.txt? [Y/N]: " -ForegroundColor Yellow -NoNewline
$clearResponse = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host $clearResponse.Character
if ($clearResponse.Character.ToString().ToLower() -eq 'y') {
    Clear-Content -Path $InputFile
    Write-Host "Cleared."
    Write-Host ""
}

# Wait before exiting
Read-Host "Press Enter to exit"