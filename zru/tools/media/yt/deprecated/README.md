# Deprecated YouTube Downloader Scripts

This folder contains older versions of the YouTube downloader scripts that have been superseded by the enhanced version in the parent directory.

## Files

- **ytmeold.rb**: Original comprehensive downloader with batch processing
- **ytme.rb**: Updated version with improved features
- **ytme1.rb** & **ytme1old.rb**: Threaded downloaders with different configurations
- **ytme0.rb** & **ytme0old.rb**: Hardcore mode downloaders (minimal prompts)
- **fileopsold.rb**: Older directory configuration module

## Status

These scripts are **deprecated** and should not be used for new downloads. They are kept here for reference and backward compatibility only.

## Recommended

Use `../enhanced_yt_downloader.rb` instead - it combines all the best features from these scripts with:

- Cross-platform support (Windows, WSL Kali Linux, native Linux, macOS)
- Modern user interface with menus
- Comprehensive configuration system
- Better error handling and logging
- Resume capability and duplicate detection
- Multi-format support (audio/video)
- Batch processing improvements

## Migration

If you were using any of these old scripts, simply replace them with:

```bash
ruby enhanced_yt_downloader.rb
```

The new script will automatically detect your platform and provide an improved experience.