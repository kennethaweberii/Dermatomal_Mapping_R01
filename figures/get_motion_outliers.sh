#!/bin/bash

# Path to your base data directory
BASE_DIR="/home/sbedard/Projects/Dermatomal_Mapping_R01/data/BIDS/derivatives"

# File that contains the list of subjects (one per line)
SUBJECT_LIST="/home/sbedard/codes/Dermatomal_Mapping_R01/include_n40.txt"

# Output file
OUTPUT_FILE="motion_outlier_columns_summary.txt"

runs=(1 2 3)
# Clear the output file
> "$OUTPUT_FILE"

echo "Counting number of columns in motion outlier files..."
echo subject run motion_outliers >> "$OUTPUT_FILE"

# Loop through each subject in the list
for run in "${runs[@]}"; do
    while read -r subj; do
        # Define the file path
        FILE="${BASE_DIR}/${subj}/ses-spinalcord/func/run-${run}/${subj}_ses-spinalcord_task-tens_run-${run}_bold_motion_outliers.txt"

        # Check if the file exists
        if [[ -f "$FILE" ]]; then
            # Count number of columns (fields) in the first line
            ncols=$(awk '{print NF; exit}' "$FILE")
            echo ${subj} run-${run} ${ncols} >> "$OUTPUT_FILE"
            #echo "${subj}: ${ncols} columns" | tee -a "$OUTPUT_FILE"
        fi
    done < "$SUBJECT_LIST"
done
echo "Results saved to ${OUTPUT_FILE}"
