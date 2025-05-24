#!/bin/bash

# Debug script for VAST-tools pipeline
# Usage: ./scripts/debug_vast_pipeline.sh <work_directory>

WORK_DIR=${1:-"work"}

echo "=== VAST-tools Pipeline Debug Report ==="
echo "Timestamp: $(date)"
echo "Work directory: $WORK_DIR"
echo ""

if [ ! -d "$WORK_DIR" ]; then
    echo "ERROR: Work directory $WORK_DIR not found!"
    exit 1
fi

echo "=== Searching for VAST-tools alignment outputs ==="
find "$WORK_DIR" -name "vast_out" -type d | head -10 | while read vast_dir; do
    echo "Found vast_out directory: $vast_dir"
    echo "  Contents:"
    ls -la "$vast_dir" | head -10
    echo "  Tab files:"
    find "$vast_dir" -name "*.tab" -type f | head -5
    echo "  to_combine directory:"
    if [ -d "$vast_dir/to_combine" ]; then
        echo "    EXISTS - Contents:"
        ls -la "$vast_dir/to_combine" | head -10
        echo "    File count: $(find "$vast_dir/to_combine" -type f | wc -l)"
    else
        echo "    MISSING!"
    fi
    echo ""
done

echo "=== Searching for combine_results outputs ==="
find "$WORK_DIR" -name "*INCLUSION_LEVELS_FULL*.tab" -type f | while read inclusion_file; do
    echo "Found inclusion table: $inclusion_file"
    echo "  Size: $(stat -c%s "$inclusion_file" 2>/dev/null || echo "unknown") bytes"
    echo "  First few lines:"
    head -n 5 "$inclusion_file" 2>/dev/null || echo "  Could not read file"
    echo ""
done

echo "=== Recent VAST-tools process logs ==="
find "$WORK_DIR" -name "*.command.out" -type f -newer /tmp -exec grep -l "vast-tools" {} \; | head -3 | while read log_file; do
    echo "Log file: $log_file"
    echo "  Last 20 lines:"
    tail -n 20 "$log_file"
    echo ""
done

echo "=== Recent error logs ==="
find "$WORK_DIR" -name "*.command.err" -type f -newer /tmp -size +0 | head -3 | while read err_file; do
    echo "Error file: $err_file"
    echo "  Contents:"
    cat "$err_file"
    echo ""
done

echo "=== Summary ==="
echo "Total vast_out directories: $(find "$WORK_DIR" -name "vast_out" -type d | wc -l)"
echo "Directories with to_combine: $(find "$WORK_DIR" -path "*/vast_out/to_combine" -type d | wc -l)"
echo "Total .tab files in vast_out: $(find "$WORK_DIR" -path "*/vast_out/*.tab" -type f | wc -l)"
echo "Inclusion tables found: $(find "$WORK_DIR" -name "*INCLUSION_LEVELS_FULL*.tab" -type f | wc -l)"

echo ""
echo "=== Recommendations ==="
if [ "$(find "$WORK_DIR" -path "*/vast_out/to_combine" -type d | wc -l)" -eq 0 ]; then
    echo "🔴 CRITICAL: No to_combine directories found!"
    echo "   - Check if VAST-tools alignment is completing successfully"
    echo "   - Verify input files are properly formatted"
    echo "   - Check VASTDB path and permissions"
elif [ "$(find "$WORK_DIR" -name "*INCLUSION_LEVELS_FULL*.tab" -type f | wc -l)" -eq 0 ]; then
    echo "🟡 WARNING: Alignments found but no inclusion table generated"
    echo "   - Check combine_results process logs"
    echo "   - Verify species parameter matches VASTDB"
else
    echo "✅ Pipeline appears to have run - check file sizes and content"
fi
