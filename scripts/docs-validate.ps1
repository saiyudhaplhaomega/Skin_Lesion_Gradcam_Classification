# Validation script for docs-check
# Called by Makefile to avoid bash interpretation issues with $ and backtick

$ErrorActionPreference = 'Continue'

# Skip this script's own documentation to avoid false positives
$excludePattern = '09_DOCS_VALIDATION'

# 1. Check no docs/build or docs/advanced references exist (stale paths)
# Use word boundaries to avoid matching docs/building or docs/advanced-course
$buildRefs = Get-ChildItem 'README.md','docs/*.md','docs/local-dev/*.md','docs/product/*.md','docs/staging/*.md','docs/production/*.md','docs/reference/*.md','Skin_Lesion_Classification_frontend/*.md' -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.FullName -notmatch $excludePattern) {
        Select-String -Path $_.FullName -Pattern '\bdocs/build\b|\bdocs/advanced\b' -Quiet
    }
} | Where-Object { $_ }
if ($buildRefs) {
    Write-Host 'Found stale docs/build or docs/advanced reference'
    exit 1
}

# 2. Check no outdated "Aurora PostgreSQL first" reference
$dsqlRef = Get-ChildItem 'README.md','docs/*.md','docs/local-dev/*.md','docs/product/*.md','docs/staging/*.md','docs/production/*.md','docs/reference/*.md','Skin_Lesion_Classification_frontend/*.md' -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.FullName -notmatch $excludePattern) {
        Select-String -Path $_.FullName -Pattern 'Aurora PostgreSQL first' -Quiet
    }
} | Where-Object { $_ }
if ($dsqlRef) {
    Write-Host 'Found outdated DSQL reference'
    exit 1
}

# 3. Check EKS auto-heal guide has ECS boundary warning
$eksContent = Get-Content 'docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md' -Raw -ErrorAction SilentlyContinue
if ($eksContent -notmatch 'ECS-only Lambda code is not wired to EKS alarms') {
    Write-Host 'EKS auto-heal guide missing ECS boundary warning'
    exit 1
}

# 4. Check ECS auto-heal guide has EKS boundary warning
$ecsContent = Get-Content 'docs/production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md' -Raw -ErrorAction SilentlyContinue
if ($ecsContent -notmatch 'Do not wire this Lambda to EKS alarms') {
    Write-Host 'ECS auto-heal guide missing EKS boundary warning'
    exit 1
}

# 5. Check deleted module/lambda folders don't exist
if ((Test-Path 'infra/terraform/modules') -or (Test-Path 'infra/terraform/lambda')) {
    Write-Host 'Deleted Terraform module/lambda folders should not exist'
    exit 1
}

# 6. Check all doc files have "Cost Pause / Resume" section
$missingCost = Get-ChildItem 'docs' -Recurse -Filter '*.md' -ErrorAction SilentlyContinue | Where-Object {
    if ($_.FullName -notmatch $excludePattern) {
        (Select-String -Path $_.FullName -Pattern 'Cost Pause / Resume' -Quiet) -eq $null
    }
}
if ($missingCost) {
    Write-Host 'Doc file missing Cost Pause / Resume section'
    exit 1
}

# 7-9. Check 99_DOC_ORDER.md has correct ordering
$docOrder = Get-Content 'docs/99_DOC_ORDER.md' -ErrorAction SilentlyContinue | Out-String
if ($docOrder -notmatch '00_CLOUD_COST_CONTROL') {
    exit 1
}
if ($docOrder -notmatch '02_TERRAFORM_FROM_EMPTY_MAIN') {
    exit 1
}
if ($docOrder -notmatch '13_TERRAFORM_PARAMETERS') {
    exit 1
}

exit 0
