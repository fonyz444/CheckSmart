# Tesseract OCR Trained Data Setup

## Required Files
Download these files and place them in this directory (`assets/tessdata/`):

1. **English**: [eng.traineddata](https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata)
2. **Russian**: [rus.traineddata](https://github.com/tesseract-ocr/tessdata/raw/main/rus.traineddata)

## Download Commands (PowerShell)
```powershell
Invoke-WebRequest -Uri "https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata" -OutFile "eng.traineddata"
Invoke-WebRequest -Uri "https://github.com/tesseract-ocr/tessdata/raw/main/rus.traineddata" -OutFile "rus.traineddata"
```

## File Sizes (Expected)
- eng.traineddata: ~4 MB
- rus.traineddata: ~5 MB

> ⚠️ The app will crash if these files are missing!
