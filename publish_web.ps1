# publish_web.ps1
Write-Host "Building web version..." -ForegroundColor Cyan
cd frontend
flutter build web --base-href "/AI-study-planner/"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter web build failed!"
    exit 1
}

$mainJsPath = "build/web/main.dart.js"
if (Test-Path $mainJsPath) {
    Write-Host "Patching main.dart.js to support Int64 accessors on Web..." -ForegroundColor Cyan
    $content = Get-Content -Raw -Path $mainJsPath
    $content = $content.Replace('R_(a,b,c){throw A.f(A.aR("Int64 accessor not supported by dart2js."))}', 'R_(a,b,c){return Number(a.getBigInt64(b,c))}')
    $content = $content.Replace('RA(a,b,c,d){throw A.f(A.aR("Int64 accessor not supported by dart2js."))}', 'RA(a,b,c,d){a.setBigInt64(b,BigInt(c),d)}')
    Set-Content -Path $mainJsPath -Value $content -NoNewline
    Write-Host "Patching completed!" -ForegroundColor Green
}

Write-Host "Deploying to GitHub Pages..." -ForegroundColor Cyan
cd build/web

# Initialize a clean repository for deployment
git init
git remote add origin https://github.com/PRJWL3/AI-study-planner.git
git checkout -b gh-pages
git add .
git commit -m "deploy: publish web version"
git push -f origin gh-pages

cd ../../..
Write-Host "Web app successfully published to: https://PRJWL3.github.io/AI-study-planner/" -ForegroundColor Green
