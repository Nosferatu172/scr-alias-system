# Enhanced Text File Manager

A cross-platform Ruby script for archiving and splitting text files with advanced features for Windows, WSL Kali Linux, Linux, and macOS.

## Features

- **Cross-platform compatibility**: Works on Windows, WSL, Linux, and macOS
- **Archive mode**: Copy .txt files with timestamps and custom tags
- **Split mode**: Divide large text files into smaller chunks
- **Duplicate detection**: SHA256-based duplicate file detection
- **Interactive mode**: User-friendly file selection
- **Dry-run mode**: Preview operations before execution
- **UTF-8 encoding support**: Handles various text encodings
- **CSV configuration**: Persistent settings storage

## Installation

1. Ensure Ruby is installed on your system
2. Install required gems:
   ```bash
   gem install colorize fileutils time optparse csv digest
   ```
3. Copy `enhanced_text_manager.rb` to your desired location

## Quick Start

1. Run the script to set up configuration:
   ```bash
   ruby enhanced_text_manager.rb -e
   ```

2. Archive all .txt files:
   ```bash
   ruby enhanced_text_manager.rb -a
   ```

3. Split a large file:
   ```bash
   ruby enhanced_text_manager.rb -s -f largefile.txt -l 5
   ```

## Usage

### Archive Mode

Archive .txt files with timestamps and optional tags:

```bash
# Archive all files (no prompts)
ruby enhanced_text_manager.rb -a

# Interactive file selection
ruby enhanced_text_manager.rb -i

# Archive specific file
ruby enhanced_text_manager.rb -f myfile.txt

# Archive with custom tag
ruby enhanced_text_manager.rb -f myfile.txt -t backup

# Force archive even if duplicate exists
ruby enhanced_text_manager.rb -f myfile.txt --force

# Preview what would be archived
ruby enhanced_text_manager.rb -a --dry-run
```

### Split Mode

Split large text files into smaller chunks:

```bash
# Split file into chunks of 5 lines each
ruby enhanced_text_manager.rb -s -f bigfile.txt -l 5

# Split with custom output directory
ruby enhanced_text_manager.rb -s -f bigfile.txt -l 10 -o /path/to/output

# Preview split operation
ruby enhanced_text_manager.rb -s -f bigfile.txt -l 5 --dry-run
```

### Configuration

```bash
# Edit source and archive directories
ruby enhanced_text_manager.rb -e

# Show current configuration
ruby enhanced_text_manager.rb -c

# Show help
ruby enhanced_text_manager.rb -h
```

## Configuration File

The script creates `enhanced_text_manager.csv` in the same directory, containing:

```csv
source,/path/to/source/directory
archive,/path/to/archive/directory
```

## Platform Detection

The script automatically detects your platform:
- **Windows**: Native Windows Terminal
- **WSL**: Windows Subsystem for Linux (shows distro name)
- **Linux**: Native Linux
- **macOS**: macOS

## Encoding Support

- Automatic UTF-8 setup
- Fallback encoding detection (UTF-8, Windows-1252, ISO-8859-1)
- Windows Terminal ANSI color support

## Examples

### Windows Example
```cmd
C:\> ruby enhanced_text_manager.rb -a
📦 Archive All Mode
Platform: Windows
Source: C:/Users/Documents/texts
Archive: C:/Users/Documents/archives

📊 Found 3 files
📦 Archived: notes.txt → 20260412_120000_123456_notes.txt
📦 Archived: todo.txt → 20260412_120000_123457_todo.txt
📦 Archived: draft.txt → 20260412_120000_123458_draft.txt

✅ Archived 3 files
🎉 Operation complete!
```

### WSL Kali Linux Example
```bash
$ ruby enhanced_text_manager.rb -s -f large_log.txt -l 100
📄 Split Mode
Platform: WSL (kali-linux)

🔧 Splitting: large_log.txt
Lines per file: 100
Output: /mnt/c/Users/Documents/archives
📄 Splitting 1250 lines into 13 files...
📦 Created: 20260412_120000_123456_large_log_part1.txt (100 lines)
📦 Created: 20260412_120000_123457_large_log_part2.txt (100 lines)
[...]

✅ Created 13 files
🎉 Operation complete!
```

## Error Handling

- Validates directory existence
- Handles file encoding issues gracefully
- Provides clear error messages
- Ctrl+C interrupt handling

## Dependencies

- Ruby 2.5+
- colorize gem
- fileutils (standard library)
- optparse (standard library)
- csv (standard library)
- digest (standard library)

## Troubleshooting

### "Source directory not found"
- Run `ruby enhanced_text_manager.rb -e` to reconfigure paths
- Ensure paths use forward slashes (/) for cross-platform compatibility

### Encoding issues
- The script automatically tries multiple encodings
- Files with mixed encodings may need manual preprocessing

### Permission errors
- Ensure write permissions in archive directory
- On WSL, check Windows directory permissions

## Advanced Usage

### Batch Processing
```bash
# Archive all files with a specific tag
for file in *.txt; do
  ruby enhanced_text_manager.rb -f "$file" -t batch_process
done
```

### Integration with Other Tools
```bash
# Split output from another command
some_command | tee temp.txt
ruby enhanced_text_manager.rb -s -f temp.txt -l 50
```

## Contributing

This script combines features from multiple text processing utilities:
- Archive functionality inspired by settxt series
- Split functionality from septxt utilities
- Cross-platform enhancements for modern usage

## License

This enhanced script is provided as-is for educational and practical use.