# BBB DVD Creator

This script automates the process of splitting a video into segments, grouping them, converting them into DVD-compatible MPEG-2 format, and creating a DVD structure using `dvdauthor`. It is designed to work with the **Big Buck Bunny** video (`bbb_sunflower_1080p_30fps_normal.mp4`) but can be used with any video file.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Usage](#usage)
- [Script Overview](#script-overview)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- **Video Splitting:** Splits the input video into a specified number of equal-length segments.
- **Segment Grouping:** Groups segments into VOB files according to a predefined distribution.
- **Format Conversion:** Converts grouped segments into DVD-compatible MPEG-2 format.
- **DVD Structure Creation:** Generates a DVD structure (`VIDEO_TS`, `AUDIO_TS`) using `dvdauthor`.
- **Cleanup Option:** Offers a quiet mode to delete intermediate files after processing.
- **Debugging Support:** Provides detailed output for debugging purposes.

## Requirements

- **Operating System:** Linux or macOS
- **Dependencies:**
  - `bash`
  - `ffmpeg`
  - `ffprobe`
  - `dvdauthor`
- **Input Video:**
  - A video file in a format supported by `ffmpeg`.

## Usage

### 1. Ensure Dependencies are Installed

- **ffmpeg:** [Installation Guide](https://ffmpeg.org/download.html)
- **dvdauthor:** Install via your package manager (e.g., `sudo apt-get install dvdauthor` on Debian/Ubuntu)

### 2. Place the Script and Video in the Same Directory

- `bbb_dvd_creator.sh` (the script)
- `bbb_sunflower_1080p_30fps_normal.mp4` (or your input video)

### 3. Make the Script Executable

```bash
chmod +x bbb_dvd_creator.sh

4. Run the Script
bash
Copy code
./bbb_dvd_creator.sh [options] input_video.mp4
Options:

-q: Enable quiet mode to delete intermediate files after processing.
Example:

bash
Copy code
./bbb_dvd_creator.sh -q bbb_sunflower_1080p_30fps_normal.mp4
Script Overview
The script performs the following steps:

Parsing Arguments:

Checks for the -q option and input video file.
Validates the presence of required commands (ffmpeg, dvdauthor, ffprobe).
Splitting the Video:

Calculates the total duration of the input video.
Splits the video into 9 equal segments using ffmpeg.
Segment files are named segment01.mp4, segment02.mp4, etc.
Grouping Segments:

Groups the segments into VOB files according to the VOB_SEGMENTS array.
The default distribution is (1, 2, 6), meaning:
VOB 1 contains 1 segment.
VOB 2 contains 2 segments.
VOB 3 contains 6 segments.
Grouped files are named group01.mp4, group02.mp4, etc.
Converting to DVD-Compatible Format:

Converts each grouped .mp4 file into a DVD-compatible MPEG-2 format using ffmpeg.
Output files are named group01.mpg, group02.mpg, etc.
Creating DVD Structure:

Sets the VIDEO_FORMAT environment variable to NTSC (or PAL if modified).
Uses dvdauthor to create the DVD structure in the custom_dvd directory.
Writes the table of contents for the DVD.
Cleaning Up:

If the -q option is used, intermediate files are deleted.
Outputs the result of the process and indicates whether the test passed.
Customization
Change Segment Distribution
Modify the VOB_SEGMENTS array in the script to change how segments are grouped.

bash
Copy code
VOB_SEGMENTS=(1 2 6)  # Example: Change to (3 3 3) for equal distribution
Adjust Video Format
To use PAL format instead of NTSC, change the VIDEO_FORMAT environment variable and adjust ffmpeg parameters:

Set Video Format to PAL:

bash
Copy code
export VIDEO_FORMAT=PAL
Adjust ffmpeg Parameters:

In the script, replace:

bash
Copy code
-target ntsc-dvd \
-r 29.97 \
with:

bash
Copy code
-target pal-dvd \
-r 25 \
Enable/Disable Debug Mode
Set DEBUG_MODE at the top of the script to true or false to enable or disable verbose output.

bash
Copy code
DEBUG_MODE="false"
Troubleshooting
Missing Dependencies
Ensure all required commands are installed and accessible in your system's PATH.

ffmpeg Installation:

bash
Copy code
sudo apt-get install ffmpeg  # For Debian/Ubuntu
dvdauthor Installation:

bash
Copy code
sudo apt-get install dvdauthor  # For Debian/Ubuntu
Audio Discontinuity Warnings
Warnings during dvdauthor about audio discontinuities are common and usually harmless.

Possible Solution:

If playback issues occur, consider re-multiplexing the MPEG files with tools like mplex before running dvdauthor.

Script Permissions
If you receive a permission denied error, ensure the script is executable:

bash
Copy code
chmod +x bbb_dvd_creator.sh
DVD Playback Issues
Using Software Players:

Use a compatible DVD player software that can play from a DVD directory (e.g., VLC Media Player).

bash
Copy code
vlc custom_dvd/
Burning to Physical DVD:

If burning to a physical DVD, ensure both VIDEO_TS and AUDIO_TS directories are included.

License
This project is licensed under the MIT License.

Note: This script and README are provided as-is. Always test the script in a controlled environment before using it in a production setting.
