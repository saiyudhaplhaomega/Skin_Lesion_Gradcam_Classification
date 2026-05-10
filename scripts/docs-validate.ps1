# Validation script for docs-check
# Called by Makefile to avoid bash interpretation issues with $ and backtick

$ErrorActionPreference = 'Continue'

# Skip this script's own documentation to avoid false positives
$excludePattern = '09_DOCS_VALIDATION'
$root = (Get-Location).Path

function Fail($message) {
    Write-Host $message
    exit 1
}

$allMarkdown = Get-ChildItem 'README.md','docs/*.md','docs/local-dev/*.md','docs/product/*.md','docs/staging/*.md','docs/production/*.md','docs/reference/*.md','Skin_Lesion_Classification_frontend/*.md' -ErrorAction SilentlyContinue

# 1. Check every file listed in docs/99_DOC_ORDER.md exists
$docOrderPath = 'docs/99_DOC_ORDER.md'
$docOrderRaw = Get-Content $docOrderPath -Raw -ErrorAction SilentlyContinue
if (-not $docOrderRaw) {
    Fail 'Missing docs/99_DOC_ORDER.md'
}

$orderedGuideMatches = [regex]::Matches($docOrderRaw, '`([^`]+\.md)`')
$orderedGuides = @()
foreach ($match in $orderedGuideMatches) {
    $relative = $match.Groups[1].Value
    if ($relative -like 'docs/*') {
        $candidate = $relative
    } else {
        $candidate = Join-Path 'docs' $relative
    }
    $orderedGuides += ($candidate -replace '\\', '/')

    if (-not (Test-Path $candidate)) {
        Fail "Guide listed in docs/99_DOC_ORDER.md does not exist: $candidate"
    }
}

$actualGuides = Get-ChildItem 'docs' -Recurse -File -Filter '*.md' | ForEach-Object {
    $_.FullName.Substring($root.Length + 1) -replace '\\', '/'
}
$unlistedGuides = $actualGuides | Where-Object { $_ -notin $orderedGuides }
if ($unlistedGuides) {
    Fail "Guide file is missing from docs/99_DOC_ORDER.md: $($unlistedGuides -join ', ')"
}

# 2. Check relative Markdown links resolve
foreach ($file in $allMarkdown) {
    $content = Get-Content $file.FullName -Raw
    $linkMatches = [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')
    foreach ($linkMatch in $linkMatches) {
        $target = $linkMatch.Groups[1].Value
        if ($target -match '^(https?:|mailto:|#)') {
            continue
        }

        $targetPath = ($target -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($targetPath)) {
            continue
        }

        $targetPath = [uri]::UnescapeDataString($targetPath)
        if ($targetPath.StartsWith('<') -and $targetPath.EndsWith('>')) {
            $targetPath = $targetPath.Substring(1, $targetPath.Length - 2)
        }

        $resolvedPath = Join-Path $file.DirectoryName $targetPath
        if (-not (Test-Path $resolvedPath)) {
            $relativeFile = $file.FullName.Substring($root.Length + 1)
            Fail "Broken Markdown link in ${relativeFile}: $target"
        }
    }
}

# 3. Check no docs/build or docs/advanced references exist (stale paths)
# Use word boundaries to avoid matching docs/building or docs/advanced-course
$buildRefs = $allMarkdown | ForEach-Object {
    if ($_.FullName -notmatch $excludePattern) {
        Select-String -Path $_.FullName -Pattern '\bdocs/build\b|\bdocs/advanced\b' -Quiet
    }
} | Where-Object { $_ }
if ($buildRefs) {
    Fail 'Found stale docs/build or docs/advanced reference'
}

# 4. Check no outdated "Aurora PostgreSQL first" reference
$dsqlRef = $allMarkdown | ForEach-Object {
    if ($_.FullName -notmatch $excludePattern) {
        Select-String -Path $_.FullName -Pattern 'Aurora PostgreSQL first' -Quiet
    }
} | Where-Object { $_ }
if ($dsqlRef) {
    Fail 'Found outdated DSQL reference'
}

# 5. Check EKS auto-heal guide has ECS boundary warning
$eksContent = Get-Content 'docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md' -Raw -ErrorAction SilentlyContinue
if ($eksContent -notmatch 'ECS-only Lambda code is not wired to EKS alarms') {
    Fail 'EKS auto-heal guide missing ECS boundary warning'
}

# 6. Check ECS auto-heal guide has EKS boundary warning
$ecsContent = Get-Content 'docs/production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md' -Raw -ErrorAction SilentlyContinue
if ($ecsContent -notmatch 'Do not wire this Lambda to EKS alarms') {
    Fail 'ECS auto-heal guide missing EKS boundary warning'
}

# 7. Check deleted module/lambda folders do not exist
if ((Test-Path 'infra/terraform/modules') -or (Test-Path 'infra/terraform/lambda')) {
    Fail 'Deleted Terraform module/lambda folders should not exist'
}

# 8. Check cloud guides have "Cost Pause / Resume" section
# Only staging and production guides create cloud resources
$missingCost = Get-ChildItem 'docs/staging/*.md','docs/production/*.md' -ErrorAction SilentlyContinue | Where-Object {
    (Select-String -Path $_.FullName -Pattern 'Cost Pause / Resume' -Quiet) -eq $null
}
if ($missingCost) {
    Fail 'Cloud guide missing Cost Pause / Resume section'
}

# 9. Check 99_DOC_ORDER.md has key staging gates
if ($docOrderRaw -notmatch '00_CLOUD_COST_CONTROL') {
    Fail 'docs/99_DOC_ORDER.md missing 00_CLOUD_COST_CONTROL'
}
if ($docOrderRaw -notmatch '02_TERRAFORM_FROM_EMPTY_MAIN') {
    Fail 'docs/99_DOC_ORDER.md missing 02_TERRAFORM_FROM_EMPTY_MAIN'
}
if ($docOrderRaw -notmatch '03_TERRAFORM_VPC') {
    Fail 'docs/99_DOC_ORDER.md missing 03_TERRAFORM_VPC'
}
if ($docOrderRaw -notmatch '04_TERRAFORM_PARAMETERS') {
    Fail 'docs/99_DOC_ORDER.md missing 04_TERRAFORM_PARAMETERS'
}

exit 0
