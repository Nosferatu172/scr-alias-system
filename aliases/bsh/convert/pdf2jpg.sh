#!/usr/bin/env bash
# Script Name: pdf2jpg.sh
# ID: SCR-ID-20260329042820-C7WN3MKXXT
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: pdf2jpg

# ============================
#  Interactive PDF → JPG Tool
# ============================

echo "=== PDF → JPG Converter (WSL/Kali) ==="
read -p "Enter directory containing PDF files: " DIR

# Remove quotes if user dragged folder in
DIR="${DIR%\"}"
DIR="${DIR#\"}"

if [[ ! -d "$DIR" ]]; then
    echo "❌ Directory does not exist: $DIR"
    exit 1
fi

echo ""
echo "📂 Contents of directory:"
ls -1 "$DIR"
echo ""

# Get all PDF files
mapfile -t PDFS < <(find "$DIR" -maxdepth 1 -type f -iname "*.pdf")

if [[ ${#PDFS[@]} -eq 0 ]]; then
    echo "⚠️ No PDF files found in: $DIR"
    exit 1
fi

echo "Found ${#PDFS[@]} PDF file(s)."
echo ""

echo "Convert:"
echo "1) A specific file"
echo "2) ALL PDFs in folder"
read -p "Choose (1 or 2): " CHOICE

TARGETS=()

if [[ "$CHOICE" == "1" ]]; then
    echo ""
    echo "Select a file:"
    for i in "${!PDFS[@]}"; do
        echo "$((i+1))). ${PDFS[$i]}"
    done
    read -p "Enter number: " FILE_NUM
    INDEX=$((FILE_NUM - 1))

    if [[ -z "${PDFS[$INDEX]}" ]]; then
        echo "❌ Invalid choice."
        exit 1
    fi

    TARGETS=("${PDFS[$INDEX]}")

elif [[ "$CHOICE" == "2" ]]; then
    TARGETS=("${PDFS[@]}")

else
    echo "❌ Invalid choice."
    exit 1
fi

echo ""
echo "🔥 Preparing conversion..."

# Output folder
OUT="$DIR/pdf_jpg_output"
mkdir -p "$OUT"

# Auto-detect max CPU threads
CPU=$(nproc --all)

convert_pdf() {
    local FILE="$1"
    local BASE=$(basename "$FILE" .pdf)

    echo "➡️ Converting $BASE.pdf ..."
    pdftoppm "$FILE" "$OUT/${BASE}" -jpeg -jpegopt quality=95 > /dev/null 2>&1

    echo "✅ Finished: $BASE"
}

export -f convert_pdf
export OUT

# If GNU parallel exists → use full CPU power
if command -v parallel >/dev/null 2>&1; then
    echo "⚙️ Using GNU parallel with $CPU threads..."
    parallel -j "$CPU" convert_pdf ::: "${TARGETS[@]}"
else
    echo "⚙️ GNU parallel not found. Running sequentially..."
    for PDF in "${TARGETS[@]}"; do
        convert_pdf "$PDF"
    done
fi

echo ""
echo "🎉 Done! JPG output saved in:"
echo "$OUT"
