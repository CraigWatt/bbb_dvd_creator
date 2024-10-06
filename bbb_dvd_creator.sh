#!/bin/bash

# Script: create_custom_dvd.sh
# Purpose: Automate splitting a video into segments, grouping them, creating a DVD structure
#          with specified VOB files, and testing with dvdnavtex.
# Usage: ./create_custom_dvd.sh [input_video.mp4]
# Example: ./create_custom_dvd.sh bbb_sunflower_1080p_30fps_normal.mp4

# Exit immediately if a command exits with a non-zero status
set -e

# Check for required commands
for cmd in ffmpeg dvdauthor bc; do
  if ! command -v $cmd &>/dev/null; then
    echo "Error: $cmd is not installed. Please install it and try again."
    exit 1
  fi
done

# Check input arguments
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 [input_video.mp4]"
  exit 1
fi

INPUT_VIDEO="$1"

# Check if input video exists
if [ ! -f "$INPUT_VIDEO" ]; then
  echo "Error: Input video '$INPUT_VIDEO' not found."
  exit 1
fi

# Define the segment distribution
SEGMENTS_TOTAL=9
VOB_SEGMENTS=(1 2 6)  # Number of segments per VOB file
GROUP_NAMES=("Group1" "Group2" "Group3")

# Validate total segments
if [ "$(IFS=+; echo "$((${VOB_SEGMENTS[*]}))")" -ne "$SEGMENTS_TOTAL" ]; then
  echo "Error: Total segments in VOB_SEGMENTS do not add up to $SEGMENTS_TOTAL."
  exit 1
fi

# Get total duration of the video in seconds
TOTAL_DURATION=$(ffprobe -i "$INPUT_VIDEO" -show_entries format=duration -v quiet -of csv="p=0")
TOTAL_DURATION=${TOTAL_DURATION%.*} # Convert to integer

# Calculate segment duration
SEGMENT_DURATION=$(echo "$TOTAL_DURATION / $SEGMENTS_TOTAL" | bc)

echo "Total Duration: $TOTAL_DURATION seconds"
echo "Total Segments: $SEGMENTS_TOTAL"
echo "Segment Duration: $SEGMENT_DURATION seconds"
echo "VOB Segments Distribution: ${VOB_SEGMENTS[*]}"

# Create an array to hold individual segment filenames
SEGMENT_FILES=()

# Split the video into segments
for ((i = 0; i < SEGMENTS_TOTAL; i++)); do
  START_TIME=$(echo "$i * $SEGMENT_DURATION" | bc)
  SEGMENT_NUM=$((i + 1))
  SEGMENT_FILE="segment${SEGMENT_NUM}.mp4"
  echo "Creating segment $SEGMENT_NUM: $SEGMENT_FILE (Start: ${START_TIME}s, Duration: ${SEGMENT_DURATION}s)"
  ffmpeg -i "$INPUT_VIDEO" -ss "$START_TIME" -t "$SEGMENT_DURATION" -c copy "$SEGMENT_FILE"
  SEGMENT_FILES+=("$SEGMENT_FILE")
done

# Group the segments according to VOB_SEGMENTS
GROUPED_FILES=()
INDEX=0
for ((group = 0; group < ${#VOB_SEGMENTS[@]}; group++)); do
  NUM_SEGMENTS=${VOB_SEGMENTS[$group]}
  GROUP_NAME="${GROUP_NAMES[$group]}"
  GROUP_FILE="${GROUP_NAME}.mp4"
  echo "Creating $GROUP_FILE by merging ${NUM_SEGMENTS} segments."
  
  # Collect segment files for this group
  GROUP_SEGMENTS=()
  for ((s = 0; s < NUM_SEGMENTS; s++)); do
    GROUP_SEGMENTS+=("${SEGMENT_FILES[$INDEX]}")
    INDEX=$((INDEX + 1))
  done
  
  # Merge segments using ffmpeg concat demuxer
  CONCAT_FILE="concat_list_${GROUP_NAME}.txt"
  rm -f "$CONCAT_FILE"
  for SEG in "${GROUP_SEGMENTS[@]}"; do
    echo "file '$SEG'" >> "$CONCAT_FILE"
  done
  ffmpeg -f concat -safe 0 -i "$CONCAT_FILE" -c copy "$GROUP_FILE"
  GROUPED_FILES+=("$GROUP_FILE")
done

# Convert grouped files to DVD-compatible MPEG-2 format
MPEG_FILES=()
for GROUP_FILE in "${GROUPED_FILES[@]}"; do
  GROUP_NUM=$(echo "$GROUP_FILE" | grep -o -E '[0-9]+')
  MPEG_FILE="group${GROUP_NUM}.mpg"
  echo "Converting $GROUP_FILE to DVD-compatible format: $MPEG_FILE"
  ffmpeg -i "$GROUP_FILE" \
    -target ntsc-dvd \
    -aspect 16:9 \
    -vf scale=720:480 \
    -r 29.97 \
    -b:v 6000k \
    -b:a 192k \
    -ac 2 \
    "$MPEG_FILE"
  MPEG_FILES+=("$MPEG_FILE")
done

# Create DVD structure with the MPEG files
DVD_DIR="custom_dvd"
echo "Creating DVD structure in $DVD_DIR"
mkdir -p "$DVD_DIR"

for MPEG_FILE in "${MPEG_FILES[@]}"; do
  echo "Adding $MPEG_FILE to DVD titleset"
  dvdauthor -o "$DVD_DIR" -t "$MPEG_FILE"
done

# Write the Table of Contents
dvdauthor -o "$DVD_DIR" -T

echo "DVD structure created successfully."

# Run your dvdnavtex application
echo "Running dvdnavtex on $DVD_DIR"
if [ ! -f "./dvdnavtex" ]; then
  echo "Error: dvdnavtex binary not found in the current directory."
  exit 1
fi

./dvdnavtex "$DVD_DIR/"

# Verify the output files
ALL_FILES_EXIST=true
EXPECTED_OUTPUTS=("title_01.vob" "title_02.vob" "title_03.vob")
for OUTPUT_FILE in "${EXPECTED_OUTPUTS[@]}"; do
  if [ -f "$OUTPUT_FILE" ]; then
    echo "Output file $OUTPUT_FILE was created."
  else
    echo "Error: Output file $OUTPUT_FILE not found."
    ALL_FILES_EXIST=false
  fi
done

if [ "$ALL_FILES_EXIST" = true ]; then
  echo "All output files were created successfully."
  echo "Test passed."
else
  echo "One or more output files were not created."
  echo "Test failed."
  exit 1
fi

# Clean up temporary files (optional)
echo "Cleaning up temporary files..."
rm -f segment*.mp4 group*.mp4 group*.mpg concat_list_*.txt
rm -rf "$DVD_DIR"

echo "Done."
