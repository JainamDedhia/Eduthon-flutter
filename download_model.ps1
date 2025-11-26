# Download ML Model Script
# Run this script to download the sentence encoder model

Write-Host "🔽 Downloading ML Model for Quiz Generation..." -ForegroundColor Cyan
Write-Host ""

$modelUrl = "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/all-MiniLM-L6-v2-quant.tflite"
$outputPath = "assets\models\sentence_encoder.tflite"

# Create directory if it doesn't exist
if (-not (Test-Path "assets\models")) {
    Write-Host "📁 Creating assets\models directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "assets\models" -Force | Out-Null
}

Write-Host "⏬ Downloading from HuggingFace..." -ForegroundColor Yellow
Write-Host "   URL: $modelUrl" -ForegroundColor Gray
Write-Host "   Output: $outputPath" -ForegroundColor Gray
Write-Host ""

try {
    Invoke-WebRequest -Uri $modelUrl -OutFile $outputPath -UseBasicParsing
    
    if (Test-Path $outputPath) {
        $fileSize = (Get-Item $outputPath).Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
        
        Write-Host "✅ Download complete!" -ForegroundColor Green
        Write-Host "   File: $outputPath" -ForegroundColor Gray
        Write-Host "   Size: $fileSizeMB MB" -ForegroundColor Gray
        Write-Host ""
        
        if ($fileSizeMB -lt 5 -or $fileSizeMB -gt 15) {
            Write-Host "⚠️  Warning: File size seems unusual (expected ~8MB)" -ForegroundColor Yellow
            Write-Host "   Please verify the download completed correctly" -ForegroundColor Yellow
        } else {
            Write-Host "🎉 Model ready to use! Run 'flutter pub get' and rebuild your app." -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Download failed - file not found" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Download failed with error:" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Alternative: Download manually from:" -ForegroundColor Yellow
    Write-Host "   $modelUrl" -ForegroundColor Cyan
    Write-Host "   Then save it as: $outputPath" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
