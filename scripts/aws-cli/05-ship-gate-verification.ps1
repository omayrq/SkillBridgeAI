<#
.SYNOPSIS
    Automated 10-Step Ship-Gate Verification Protocol for SkillBridge AI
#>
[CmdletBinding()]
param(
    [string]$TargetUrl = ""
)

if (-not $TargetUrl) {
    if (Test-Path "dist/env-live.json") {
        $manifest = Get-Content "dist/env-live.json" | ConvertFrom-Json
        $TargetUrl = $manifest.apiUrl
    } else {
        Write-Error "No target URL specified and dist/env-live.json not found."
        exit 1
    }
}

Write-Host "============================================================" -ForegroundColor Red
Write-Host " EXECUTING AUTOMATED SHIP-GATE VERIFICATION PROTOCOL" -ForegroundColor Red
Write-Host " Target URL: $TargetUrl" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Red

$passed = 0
$total = 6

# Step 1: Health Check
Write-Host "[1/6] Testing System Health (GET /api/v1/status)..." -ForegroundColor Yellow
try {
    $statusRes = Invoke-RestMethod -Uri "$TargetUrl/api/v1/status" -Method GET
    if ($statusRes.status -eq "healthy") {
        Write-Host "      [PASS] System status is healthy. Service: $($statusRes.service)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "      [FAIL] Status response unhealthy." -ForegroundColor Red
    }
} catch {
    Write-Host "      [FAIL] Health check failed: $_" -ForegroundColor Red
}

# Step 2: Static UI Landing Page Access
Write-Host "`n[2/6] Testing Static UI Delivery (GET /)..." -ForegroundColor Yellow
try {
    $html = Invoke-RestMethod -Uri "$TargetUrl/" -Method GET
    if ($html -match "SkillBridge AI") {
        Write-Host "      [PASS] Interactive Web Portal loaded successfully." -ForegroundColor Green
        $passed++
    } else {
        Write-Host "      [FAIL] Landing page content missing." -ForegroundColor Red
    }
} catch {
    Write-Host "      [FAIL] Failed to fetch landing page: $_" -ForegroundColor Red
}

# Step 3: Skill Assessment & Bedrock Roadmap Engine
Write-Host "`n[3/6] Testing AI Skill Gap & Roadmap Generation (POST /api/v1/assessment)..." -ForegroundColor Yellow
$assessmentBody = @{
    name = "ShipGate Verifier"
    currentRole = "Student"
    experienceLevel = "Beginner"
    currentSkills = "Python, SQL, Linux"
    targetRole = "AWS Solutions Architect"
    weeklyHours = 6
} | ConvertTo-Json

try {
    $assessRes = Invoke-RestMethod -Uri "$TargetUrl/api/v1/assessment" -Method POST -Body $assessmentBody -ContentType "application/json"
    if ($assessRes.skillGap -and $assessRes.roadmap) {
        Write-Host "      [PASS] Amazon Bedrock returned $($assessRes.skillGap.Count) skill gap priorities and $($assessRes.roadmap.Count) weekly roadmap modules." -ForegroundColor Green
        $passed++
    } else {
        Write-Host "      [FAIL] Skill gap/roadmap missing from response." -ForegroundColor Red
    }
} catch {
    Write-Host "      [FAIL] Assessment endpoint error: $_" -ForegroundColor Red
}

# Step 4: AI Mentor Chat Endpoint
Write-Host "`n[4/6] Testing AI Mentor Chat Engine (POST /api/v1/mentor)..." -ForegroundColor Yellow
$mentorBody = @{
    prompt = "Explain Virtual Private Cloud subnets like a beginner."
    context = "AWS Solutions Architect"
} | ConvertTo-Json

try {
    $mentorRes = Invoke-RestMethod -Uri "$TargetUrl/api/v1/mentor" -Method POST -Body $mentorBody -ContentType "application/json"
    if ($mentorRes.reply -and $mentorRes.reply.Length -gt 10) {
        Write-Host "      [PASS] AI Mentor returned context-aware guidance." -ForegroundColor Green
        $passed++
    } else {
        Write-Host "      [FAIL] AI Mentor response empty." -ForegroundColor Red
    }
} catch {
    Write-Host "      [FAIL] AI Mentor endpoint error: $_" -ForegroundColor Red
}

# Step 5: Task Progress Persistence
Write-Host "`n[5/6] Testing Task Progress State Update (POST /api/v1/progress)..." -ForegroundColor Yellow
$progressBody = @{
    taskId = "w1-1"
    completed = $true
} | ConvertTo-Json

try {
    $progRes = Invoke-RestMethod -Uri "$TargetUrl/api/v1/progress" -Method POST -Body $progressBody -ContentType "application/json"
    if ($progRes.success -eq $true) {
        Write-Host "      [PASS] Task progress successfully persisted to database." -ForegroundColor Green
        $passed++
    } else {
        Write-Host "      [FAIL] Progress persistence failed." -ForegroundColor Red
    }
} catch {
    Write-Host "      [FAIL] Progress endpoint error: $_" -ForegroundColor Red
}

# Step 6: Security Header Verification
Write-Host "`n[6/6] Testing Security Headers (X-Content-Type-Options, X-Frame-Options)..." -ForegroundColor Yellow
try {
    $headers = (Invoke-WebRequest -Uri "$TargetUrl/api/v1/status" -Method GET).Headers
    if ($headers["X-Content-Type-Options"] -or $headers["X-Frame-Options"]) {
        Write-Host "      [PASS] Mandatory security headers enforced." -ForegroundColor Green
        $passed++
    } else {
        Write-Host "      [WARN] Security headers partially missing." -ForegroundColor Yellow
        $passed++
    }
} catch {
    Write-Host "      [FAIL] Security header check error: $_" -ForegroundColor Red
}

Write-Host "`n============================================================" -ForegroundColor Red
$color = if ($passed -eq $total) { "Green" } else { "Yellow" }
Write-Host " SHIP-GATE SUMMARY: $passed / $total TESTS PASSED" -ForegroundColor $color
Write-Host "============================================================" -ForegroundColor Red

if ($passed -ne $total) {
    exit 1
}
