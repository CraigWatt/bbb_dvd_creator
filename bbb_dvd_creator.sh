#!/bin/bash

# Script: bbb_dvd_creator.sh
# Purpose: Automate splitting a video into segments, grouping them, creating a DVD structure
#          with specified VOB files, and testing with dvdnavtex.
# Usage: ./bbb_dvd_creator.sh [-q] [input_video.mp4]
# Example: ./bbb_dvd_creator.sh -q bbb_sunflower_1080p_30fps_normal.mp4

# Initialize variables
QUIET_MODE="false"
DEBUG_MODE="true"  # Set to "true" to enable debug outputs

# Function to display usage
usage() {
  echo "Usage: $0 [-q] [input_video.mp4]"
  echo "  -q    Enable quiet mode. Intermediate files will be deleted."
  exit 1
}

# Function to perform cleanup
cleanup() {
  if [[ "$QUIET_MODE" == "true" ]]; then
    echo "Deleting intermediate MPEG files..."
    rm -f "${MPEG_FILES[@]}"
  fi
  echo "Script execution completed."
}

# Trap EXIT to ensure cleanup is called
trap cleanup EXIT

# Parse command-line arguments
if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "Parsing command-line arguments..."
  echo "Arguments: $@"
fi

while getopts ":q" opt; do
  case ${opt} in
    q )
      QUIET_MODE="true"
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done

shift $((OPTIND -1))

# Check input arguments
if [ "$#" -ne 1 ]; then
  usage
fi

INPUT_VIDEO="$1"

if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "QUIET_MODE: $QUIET_MODE"
  echo "INPUT_VIDEO: $INPUT_VIDEO"
fi

# Check for required commands
for cmd in ffmpeg dvdauthor ffprobe; do
  if ! command -v $cmd &>/dev/null; then
    echo "Error: $cmd is not installed. Please install it and try again."
    exit 1
  fi
done

# Check if input video exists
if [ ! -f "$INPUT_VIDEO" ]; then
  echo "Error: Input video '$INPUT_VIDEO' not found."
  exit 1
fi

# Define the segment distribution
SEGMENTS_TOTAL=9
VOB_SEGMENTS=(1 2 6)  # Number of segments per VOB file

# Validate total segments
TOTAL_VOB_SEGMENTS=0
for num in "${VOB_SEGMENTS[@]}"; do
  TOTAL_VOB_SEGMENTS=$((TOTAL_VOB_SEGMENTS + num))
done

if [ "$TOTAL_VOB_SEGMENTS" -ne "$SEGMENTS_TOTAL" ]; then
  echo "Error: Total segments in VOB_SEGMENTS do not add up to $SEGMENTS_TOTAL."
  exit 1
fi

if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "SEGMENTS_TOTAL: $SEGMENTS_TOTAL"
  echo "VOB_SEGMENTS: ${VOB_SEGMENTS[*]}"
fi

# Get total duration of the video in seconds
TOTAL_DURATION=$(ffprobe -i "$INPUT_VIDEO" -show_entries format=duration -v quiet -of csv="p=0")
TOTAL_DURATION=${TOTAL_DURATION%.*} # Convert to integer

if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "TOTAL_DURATION: $TOTAL_DURATION seconds"
fi

# Calculate segment duration
SEGMENT_DURATION=$(echo "$TOTAL_DURATION / $SEGMENTS_TOTAL" | bc)

if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "SEGMENT_DURATION: $SEGMENT_DURATION seconds"
fi

# Create an array to hold individual segment filenames
SEGMENT_FILES=()

# Split the video into segments
echo "Splitting the video into segments..."
for ((i = 0; i < SEGMENTS_TOTAL; i++)); do
  START_TIME=$(echo "$i * $SEGMENT_DURATION" | bc)
  SEGMENT_NUM=$((i + 1))
  SEGMENT_FILE="segment$(printf "%02d" "$SEGMENT_NUM").mp4"
  echo "Creating segment $SEGMENT_NUM: $SEGMENT_FILE (Start: ${START_TIME}s, Duration: ${SEGMENT_DURATION}s)"
  ffmpeg -v quiet -y -i "$INPUT_VIDEO" -ss "$START_TIME" -t "$SEGMENT_DURATION" -c copy "$SEGMENT_FILE"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create segment $SEGMENT_NUM."
    exit 1
  fi
  SEGMENT_FILES+=("$SEGMENT_FILE")
done

if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "Segment files created: ${SEGMENT_FILES[*]}"
fi

# Group the segments according to VOB_SEGMENTS
GROUPED_FILES=()
INDEX=0
echo "Grouping segments..."
for ((group = 0; group < ${#VOB_SEGMENTS[@]}; group++)); do
  NUM_SEGMENTS=${VOB_SEGMENTS[$group]}
  GROUP_NUM=$((group + 1))
  GROUP_FILE="group$(printf "%02d" "$GROUP_NUM").mp4"
  echo "Creating $GROUP_FILE by merging ${NUM_SEGMENTS} segments."
  
  # Collect segment files for this group
  GROUP_SEGMENTS=()
  for ((s = 0; s < NUM_SEGMENTS; s++)); do
    GROUP_SEGMENTS+=("${SEGMENT_FILES[$INDEX]}")
    INDEX=$((INDEX + 1))
  done
  
  if [[ "$DEBUG_MODE" == "true" ]]; then
    echo "Group $GROUP_NUM segments: ${GROUP_SEGMENTS[*]}"
  fi
  
  # Merge segments using ffmpeg concat demuxer and re-encode audio to fix discontinuities
  CONCAT_FILE="concat_list_group$(printf "%02d" "$GROUP_NUM").txt"
  rm -f "$CONCAT_FILE"
  for SEG in "${GROUP_SEGMENTS[@]}"; do
    echo "file '$SEG'" >> "$CONCAT_FILE"
  done
  ffmpeg -v quiet -y -f concat -safe 0 -i "$CONCAT_FILE" -c:v copy -c:a aac -b:a 192k "$GROUP_FILE"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create grouped file $GROUP_FILE."
    exit 1
  fi
  GROUPED_FILES+=("$GROUP_FILE")
  
  # Remove intermediate segment files if quiet mode is enabled
  if [[ "$QUIET_MODE" == "true" ]]; then
    echo "Deleting intermediate segment files for group$(printf "%02d" "$GROUP_NUM")..."
    rm -f "${GROUP_SEGMENTS[@]}"
    rm -f "$CONCAT_FILE"
  else
    # Remove concat list file
    rm -f "$CONCAT_FILE"
  fi
done

if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "Grouped files created: ${GROUPED_FILES[*]}"
fi

# Convert grouped files to DVD-compatible MPEG-2 format
MPEG_FILES=()
echo "Converting grouped files to DVD-compatible MPEG-2 format..."
for GROUP_FILE in "${GROUPED_FILES[@]}"; do
  # Extract GROUP_NUM from GROUP_FILE
  BASENAME=$(basename "$GROUP_FILE" .mp4)
  GROUP_NUM=${BASENAME#group}
  if [[ "$DEBUG_MODE" == "true" ]]; then
    echo "Processing $GROUP_FILE, GROUP_NUM: $GROUP_NUM"
  fi
  
  MPEG_FILE="group$(printf "%02d" "$GROUP_NUM").mpg"
  echo "Converting $GROUP_FILE to $MPEG_FILE"
  ffmpeg -v quiet -y -i "$GROUP_FILE" \
    -target ntsc-dvd \
    -aspect 16:9 \
    -vf scale=720:480 \
    -r 29.97 \
    -b:v 6000k \
    -b:a 192k \
    -ac 2 \
    "$MPEG_FILE"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to convert $GROUP_FILE to MPEG format."
    exit 1
  fi
  MPEG_FILES+=("$MPEG_FILE")
  
  # Remove grouped .mp4 files if quiet mode is enabled
  if [[ "$QUIET_MODE" == "true" ]]; then
    echo "Deleting grouped file $GROUP_FILE..."
    rm -f "$GROUP_FILE"
  fi
done

if [[ "$DEBUG_MODE" == "true" ]]; then
  echo "MPEG files created: ${MPEG_FILES[*]}"
fi

# **Set the VIDEO_FORMAT environment variable**
export VIDEO_FORMAT=NTSC

# Create DVD structure with the MPEG files
DVD_DIR="custom_dvd"
echo "Creating DVD structure in $DVD_DIR..."
mkdir -p "$DVD_DIR"

for MPEG_FILE in "${MPEG_FILES[@]}"; do
  echo "Adding $MPEG_FILE to DVD titleset"
  dvdauthor -o "$DVD_DIR" -t "$MPEG_FILE"
  if [ $? -ne 0 ]; then
    echo "Error: dvdauthor failed for $MPEG_FILE"
    exit 1
  fi
done

# Write the Table of Contents
dvdauthor -o "$DVD_DIR" -T
if [ $? -ne 0 ]; then
  echo "Error: dvdauthor failed to write the Table of Contents"
  exit 1
fi

echo "DVD structure created successfully."

# Run your dvdnavtex application
echo "Running dvdnavtex on $DVD_DIR"
if [ ! -f "./dvdnavtex" ]; then
  echo "Warning: dvdnavtex binary not found in the current directory."
else
  ./dvdnavtex "$DVD_DIR/"
  if [ $? -ne 0 ]; then
    echo "Error: dvdnavtex execution failed."
    exit 1
  fi
fi

# Verify the output files
ALL_FILES_EXIST=true
EXPECTED_OUTPUTS=("VTS_01_1.VOB" "VTS_02_1.VOB" "VTS_03_1.VOB")
echo "Verifying output files..."
for OUTPUT_FILE in "${EXPECTED_OUTPUTS[@]}"; do
  OUTPUT_PATH="$DVD_DIR/VIDEO_TS/$OUTPUT_FILE"
  if [ -f "$OUTPUT_PATH" ]; then
    echo "Output file $OUTPUT_PATH was created."
  else
    echo "Warning: Output file $OUTPUT_PATH not found."
    ALL_FILES_EXIST=false
  fi
done

if [ "$ALL_FILES_EXIST" = true ]; then
  echo "All output files were created successfully."
  echo "Test passed."
else
  echo "One or more output files were not created."
  echo "Test failed."
  # Do not exit here to allow cleanup
fi

# The cleanup function will be called automatically due to the trap
