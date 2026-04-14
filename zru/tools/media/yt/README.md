# Enhanced YouTube Media Downloader

A powerful, cross-platform YouTube media downloader built in Ruby, supporting Windows, WSL Kali Linux, native Kali Linux, and macOS.

## Quick Start

```bash
# Run the enhanced downloader
ruby enhanced_yt_downloader.rb
```

## What's New

This enhanced version combines and improves upon all previous scripts:

- ✅ **Cross-platform**: Windows, WSL Kali Linux, native Linux, macOS
- ✅ **Unified interface**: Single script with interactive menus
- ✅ **Modern features**: Resume, archive, multi-threading, logging
- ✅ **Multiple formats**: Audio extraction + video downloads
- ✅ **Batch processing**: Directory-wide URL file processing
- ✅ **Configuration**: JSON-based persistent settings

## Previous Versions

Older script versions have been moved to the `deprecated/` folder for reference. The enhanced downloader replaces all of them with improved functionality.

## Features

### 🎯 Core Features
- **Cross-platform compatibility**: Works on Windows, WSL Kali Linux, native Linux, and macOS
- **Multiple input sources**: Manual input, .txt files, .csv files, batch processing
- **Format flexibility**: Audio extraction (MP3, M4A, etc.) and video downloads
- **Multi-threaded downloads**: Configurable thread count for parallel processing
- **Resume capability**: Archive-based resume and duplicate skipping
- **Cookie support**: Browser cookie integration for restricted content
- **Progress tracking**: Real-time download progress and logging
- **Batch processing**: Process entire directories of URL files

### 🔧 Advanced Features
- **Smart URL parsing**: Automatic URL validation and normalization
- **Encoding handling**: UTF-8 support with fallback encodings
- **Dependency checking**: Automatic verification of yt-dlp and FFmpeg
- **Configuration management**: JSON-based persistent settings
- **Comprehensive logging**: Multiple log levels with file output
- **Error recovery**: Automatic retry with configurable attempts
- **Directory organization**: Automatic folder creation and management

### 📱 User Interface
- **Interactive menus**: User-friendly command-line interface
- **Colorized output**: Enhanced readability with color coding
- **Progress indicators**: Real-time download status
- **Configuration wizard**: Easy setup and customization

## Installation

### Prerequisites
- **Ruby 2.5+**
- **yt-dlp**: `pip install yt-dlp` or download from [GitHub](https://github.com/yt-dlp/yt-dlp)
- **FFmpeg**: Download from [ffmpeg.org](https://ffmpeg.org/download.html)

### Optional Dependencies
- **colorize gem**: `gem install colorize` (for colored output)

### Setup
1. Clone or download the script
2. Make executable: `chmod +x enhanced_yt_downloader.rb`
3. Run first-time setup: `ruby enhanced_yt_downloader.rb`

## Quick Start

### Basic Usage
```bash
# Interactive mode
ruby enhanced_yt_downloader.rb

# Download single URL
echo "https://youtube.com/watch?v=..." | ruby enhanced_yt_downloader.rb
```

### Menu Options

1. **Manual URL Input**: Enter URLs directly in the terminal
2. **From .txt File**: Load URLs from a text file (one URL per line)
3. **From .csv File**: Import URLs from CSV files (supports multiple column formats)
4. **Brave Export**: Select files from your browser export directory
5. **Batch Processing**: Process entire directories of URL files
6. **Configuration**: Customize settings and directories
7. **Show Config**: Display current configuration
8. **Check Dependencies**: Verify all required tools are installed

## Configuration

The downloader uses a JSON configuration file (`yt_downloader_config.json`) for persistent settings.

### Directory Configuration
```json
{
  "directories": {
    "brave_export_dir": "/mnt/c/scr/keys/tabs/brave/",
    "default_music_dir": "/mnt/f/Music/clm/y-hold/",
    "default_videos_dir": "/mnt/f/Music/clm/Videos/y-hold/",
    "cookies_dir": "/mnt/c/scr/keys/cookies/"
  }
}
```

### Download Settings
```json
{
  "download": {
    "default_format": "best",
    "max_threads": 4,
    "retry_attempts": 3,
    "timeout": 300,
    "ffmpeg_location": "/usr/bin/ffmpeg"
  }
}
```

## Usage Examples

### Windows Example
```cmd
C:\> ruby enhanced_yt_downloader.rb
🎬 Enhanced YouTube Media Downloader
Platform: Windows
=======================================

1) Download from manual URL input
2) Download from .txt file
3) Download from .csv file
4) Select file from brave export directory
5) Batch process brave directory
6) Configure settings
7) Show current configuration
8) Check dependencies
0) Exit

Select option: 1
Enter URLs (one per line, empty line to finish):
> https://youtube.com/watch?v=dQw4w9WgXcQ
Added: https://youtube.com/watch?v=dQw4w9WgXcQ
>
✅ Successfully downloaded: https://youtube.com/watch?v=dQw4w9WgXcQ
```

### WSL Kali Linux Example
```bash
$ ruby enhanced_yt_downloader.rb
🎬 Enhanced YouTube Media Downloader
Platform: WSL (kali-linux)
=======================================

Select option: 4
Available files in /mnt/c/scr/keys/tabs/brave/:
  1) exported-tabs-2024-01-15.txt
  2) youtube-favorites.csv

Select file number: 1
Found 25 URLs in exported-tabs-2024-01-15.txt
📦 Starting batch download of 25 URLs...
✅ Batch download completed
```

### Native Linux Example
```bash
$ ruby enhanced_yt_downloader.rb
🎬 Enhanced YouTube Media Downloader
Platform: Linux
=======================================

Select option: 2
Enter .txt file path: /home/user/youtube_urls.txt
Found 10 URLs
Output directory [/home/user/Music/y-hold/]: /home/user/Downloads
⚙️ Using 4 threads
🎯 Processing URLs...
✅ All downloads completed
```

## Format Options

### Audio Extraction
- **MP3**: High-quality audio extraction
- **M4A**: AAC audio format
- **Best**: Automatic best quality selection

### Video Downloads
- **Best**: Highest quality available
- **1080p**: Limited to 1080p resolution
- **720p**: Limited to 720p resolution
- **Custom**: User-specified format string

## Advanced Features

### Batch Processing
Process entire directories of URL files automatically:

```bash
# The script will:
# 1. Scan the brave export directory
# 2. Process each .txt/.csv file
# 3. Download all URLs from each file
# 4. Move processed files to "processed/" subdirectory
```

### Cookie Support
Access restricted content using browser cookies:

1. Export cookies from your browser
2. Place cookie file in the configured cookies directory
3. Select cookie file during download setup

### Resume & Archive
- **Download Archive**: Tracks completed downloads to avoid duplicates
- **Resume Support**: Automatically resumes interrupted downloads
- **Duplicate Detection**: SHA256-based duplicate file detection

### Multi-threading
- **Configurable Threads**: Adjust thread count based on system resources
- **Load Balancing**: Automatic distribution of downloads across threads
- **Resource Management**: Prevents system overload

## Platform-Specific Notes

### Windows
- Automatic ANSI color support setup
- Native Windows path handling
- FFmpeg detection in common locations

### WSL Kali Linux
- Seamless integration with Windows directories
- Automatic Windows username detection
- Cross-filesystem path resolution

### Native Linux/macOS
- Standard Unix path handling
- Native package manager integration
- Full UTF-8 support

## Troubleshooting

### Common Issues

**"yt-dlp not found"**
```bash
# Install yt-dlp
pip install yt-dlp

# Or download standalone binary
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp
```

**"FFmpeg not found"**
```bash
# Ubuntu/Debian
sudo apt install ffmpeg

# macOS
brew install ffmpeg

# Windows: Download from ffmpeg.org
```

**"Permission denied"**
```bash
# Make script executable
chmod +x enhanced_yt_downloader.rb

# Check directory permissions
ls -la /path/to/output/directory
```

**"Encoding errors"**
- The script automatically handles UTF-8
- For files with mixed encodings, convert to UTF-8 first
- Check system locale settings

### Debug Mode
Enable verbose logging for troubleshooting:
```bash
# Edit configuration to enable debug logging
# Set "logging.level": "debug" in yt_downloader_config.json
```

### Log Files
Check log files in the `logs/` directory:
- `downloader.log`: Main application log
- `downloads_csv/`: Download statistics
- `info_json/`: Video metadata

## File Formats

### URL Input Files (.txt)
```
# One URL per line
# Comments start with #
https://youtube.com/watch?v=VIDEO_ID
https://youtu.be/VIDEO_ID
https://music.youtube.com/watch?v=VIDEO_ID
```

### CSV Files
Supported columns: `url`, `link`, `href`, `video_url`, `media_url`
```csv
title,url,duration
"Best Song Ever","https://youtube.com/watch?v=abc123","3:45"
"Another Track","https://youtu.be/def456","4:20"
```

## Performance Tips

### Optimal Settings
- **Threads**: 2-4 for most systems
- **Timeout**: 300-600 seconds for slow connections
- **Retries**: 3-5 attempts

### System Resources
- **RAM**: ~100MB per thread
- **Disk I/O**: SSD recommended for large downloads
- **Network**: Stable connection preferred

### Batch Processing
- Group similar content types together
- Use archive files to avoid re-downloads
- Process during off-peak hours

## Security Considerations

- **Cookies**: Only use cookies from trusted sources
- **File Permissions**: Restrict access to cookie files
- **Network Traffic**: Monitor bandwidth usage
- **Storage**: Ensure sufficient disk space

## Contributing

This enhanced downloader combines features from multiple scripts:
- Core downloading from ytme.rb
- Batch processing from ytmeold.rb
- Configuration management from fileops.rb
- Cross-platform enhancements for modern usage

## License

This enhanced script is provided as-is for educational and practical use across all supported platforms.

## Changelog

### Latest Version
- **Cross-platform support**: Windows, WSL, Linux, macOS
- **Enhanced UI**: Interactive menus with color support
- **Configuration system**: JSON-based persistent settings
- **Batch processing**: Directory-wide URL file processing
- **Resume capability**: Archive-based download tracking
- **Multi-threading**: Configurable parallel downloads
- **Error handling**: Comprehensive retry and recovery
- **Logging system**: Multiple levels with file output