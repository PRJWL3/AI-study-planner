# publish_web.ps1
Write-Host "Building web version..." -ForegroundColor Cyan
cd frontend
flutter build web --base-href "/AI-study-planner/"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter web build failed!"
    exit 1
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
