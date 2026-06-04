# Cursor Remote extension → kurulu klasöre kopyala (oturum silme vb.)
$src = "c:\cursorProjects\cursor-remote\cursor-extension"
$dst = "$env:USERPROFILE\.cursor\extensions\jaloveeye.cursor-remote-extension-0.4.0"

Push-Location $src
npm run compile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Pop-Location

Copy-Item -Force "$src\out\*" "$dst\out\"
Copy-Item -Force "$src\package.json" "$dst\package.json"
Write-Host "Kopyalandi: $dst"
Write-Host "Cursor icinde: Developer Reload Window"
