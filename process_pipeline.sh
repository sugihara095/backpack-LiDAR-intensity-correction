#!/bin/bash

# ==============================================================================
# Ouster PCD Processing Pipeline Script
# ==============================================================================

# --- Configuration ---
BASE_DIR="/home/hideki/pcdmap"
SEARCH_RADIUS=0.8
Z_SCALE=0.1
TARGET_RINGS="[8,9,10,11,12,13,14,15]"

# --- Input Validation ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <condition_name> <timestamp_suffix>"
    echo "Example: $0 parking_maruike_dry 20260118_2152"
    exit 1
fi

COND=$1
TIMESTAMP=$2
FULL_BASE="${COND}_${TIMESTAMP}"

# --- Define Paths ---
INPUT_PCD1="${BASE_DIR}/result_pcd_1/${COND}/${FULL_BASE}_1.pcd"
INPUT_PCD2="${BASE_DIR}/result_pcd_2/${COND}/${FULL_BASE}_2.pcd"
OUTPUT_PCD3="${BASE_DIR}/result_pcd_3/${COND}/${FULL_BASE}_3.pcd"
OUTPUT_PCD4="${BASE_DIR}/result_pcd_4/${COND}/${FULL_BASE}_4.pcd"
OUTPUT_PCD5="${BASE_DIR}/result_pcd_5/${COND}/${FULL_BASE}_5.pcd"
OUTPUT_PCD6="${BASE_DIR}/result_pcd_6/${COND}/${FULL_BASE}_6.pcd"
OUTPUT_PCD7="${BASE_DIR}/result_pcd_7/${COND}/${FULL_BASE}_7.pcd"

# --- Create Output Directories ---
echo "Creating output directories..."
mkdir -p "${BASE_DIR}/result_pcd_3/${COND}"
mkdir -p "${BASE_DIR}/result_pcd_4/${COND}"
mkdir -p "${BASE_DIR}/result_pcd_5/${COND}"
mkdir -p "${BASE_DIR}/result_pcd_6/${COND}"
mkdir -p "${BASE_DIR}/result_pcd_7/${COND}"

# --- Check Input Files ---
if [ ! -f "$INPUT_PCD1" ]; then
    echo "Error: Input file not found: $INPUT_PCD1"
    exit 1
fi
if [ ! -f "$INPUT_PCD2" ]; then
    echo "Error: Input file not found: $INPUT_PCD2"
    exit 1
fi

# ==============================================================================
# Pipeline Execution
# ==============================================================================

# 1. Field Restoration
echo "----------------------------------------------------------------"
echo "Step 1: Field Restoration (result_pcd_1 + result_pcd_2 -> 3)"
echo "----------------------------------------------------------------"
ros2 run pcd_field_restorer pcd_field_restorer_node "$INPUT_PCD1" "$INPUT_PCD2" "$OUTPUT_PCD3"

# 2. Cylinder Normal Estimation
echo "----------------------------------------------------------------"
echo "Step 2: Cylinder Normal Estimation (result_pcd_3 -> 4)"
echo "----------------------------------------------------------------"
ros2 run ouster_cylinder_normal_estimator cylinder_normal_estimator_node --ros-args \
    -p input_pcd:="$OUTPUT_PCD3" \
    -p output_pcd:="$OUTPUT_PCD4" \
    -p search_radius:=$SEARCH_RADIUS \
    -p z_scale:=$Z_SCALE

# 3. Angle and Distance Calculation
echo "----------------------------------------------------------------"
echo "Step 3: Angle and Distance Calculation (result_pcd_4 -> 5)"
echo "----------------------------------------------------------------"
ros2 run ouster_angle_dist_calculator angle_dist_calculator_node --ros-args \
    -p input_pcd:="$OUTPUT_PCD4" \
    -p output_pcd:="$OUTPUT_PCD5"

# 4. Intensity Correction
echo "----------------------------------------------------------------"
echo "Step 4: Intensity Correction (result_pcd_5 -> 6)"
echo "----------------------------------------------------------------"
# Note: uses parameters from ouster_intensity_corrector/config/params.yaml
ros2 launch ouster_intensity_corrector intensity_correction.launch.py \
    input_pcd:="$OUTPUT_PCD5" \
    output_pcd:="$OUTPUT_PCD6"

# 5. Ring Filtering
echo "----------------------------------------------------------------"
echo "Step 5: Ring Filtering (result_pcd_6 -> 7)"
echo "----------------------------------------------------------------"
ros2 launch ouster_ring_filter pcd_ring_filter.launch.py \
    input_pcd:="$OUTPUT_PCD6" \
    output_pcd:="$OUTPUT_PCD7" \
    target_rings:="$TARGET_RINGS"

echo "================================================================"
echo "Pipeline Completed Successfully!"
echo "Final Corrected PCD: $OUTPUT_PCD7"
echo "================================================================"
