#!/usr/bin/env ruby
# Script Name: rmine.rb
# ID: SCR-ID-20260329033045-SCFCE7518V
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: rmine

ENV["GTK_THEME"] ||= "Adwaita:dark"
require "gtk3"

# ----------------------------
# Helpers
# ----------------------------
def gtk_copy(text)
  Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD).text = text.to_s
end

def set_dark_mode(enabled)
  settings = Gtk::Settings.default
  settings.gtk_application_prefer_dark_theme = enabled
  settings.gtk_theme_name = enabled ? "Adwaita-dark" : "Adwaita"
rescue => e
  warn "Dark mode toggle failed: #{e}"
end

def looks_binary?(bytes)
  return false if bytes.nil? || bytes.empty?
  bytes.include?("\x00")
end

def safe_read_text(path, max_bytes: 5_000_000) # bigger cap for editing
  data = File.binread(path, [File.size(path), max_bytes].min)
  return :binary if looks_binary?(data)
  data.force_encoding("UTF-8")
  data.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
rescue StandardError => e
  "⚠️ Error reading file:\n#{e.class}: #{e.message}"
end

def safe_read_all_text(path)
  data = File.binread(path)
  return :binary if looks_binary?(data)
  data.force_encoding("UTF-8")
  data.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
rescue StandardError => e
  "⚠️ Error reading file:\n#{e.class}: #{e.message}"
end

def normalize_exts(raw)
  raw.to_s
     .split(/[,\s]+/)
     .map(&:strip)
     .reject(&:empty?)
     .map { |e| e.start_with?(".") ? e.downcase : ".#{e.downcase}" }
     .uniq
end

def file_ext(path)
  File.extname(path).downcase
end

def backup_file(path)
  ts = Time.now.strftime("%Y%m%d-%H%M%S")
  bak = "#{path}.bak-#{ts}"
  File.write(bak, File.binread(path), mode: "wb")
  bak
end

def parse_line_ranges(spec)
  # "5" "5-9" "1,3,7-10"
  nums = []
  spec.to_s.split(",").map(&:strip).reject(&:empty?).each do |chunk|
    if chunk.include?("-")
      a, b = chunk.split("-", 2).map(&:strip)
      a_i = Integer(a) rescue nil
      b_i = Integer(b) rescue nil
      next if a_i.nil? || b_i.nil?
      lo, hi = [a_i, b_i].minmax
      nums.concat((lo..hi).to_a)
    else
      i = Integer(chunk) rescue nil
      nums << i if i
    end
  end
  nums.uniq.select { |n| n >= 1 }.sort
end

# ----------------------------
# App State
# ----------------------------
@current_dir = Dir.pwd
@filter_text = ""
@ext_filters = []
@include_hidden = false
@mode = :both

@window = nil
@directory_entry = nil
@file_listbox = nil
@preview = nil
@status = nil

@filter_entry = nil
@ext_entry = nil
@hidden_check = nil
@mode_combo = nil

@displayed_paths = []

# ----------------------------
# Row helpers
# ----------------------------
def add_row(display_name, full_path:, kind:)
  row = Gtk::ListBoxRow.new
  label = Gtk::Label.new(display_name)
  label.set_xalign(0.0)
  row.add(label)

  row.instance_variable_set(:@full_path, full_path)
  row.instance_variable_set(:@display_name, display_name)
  row.instance_variable_set(:@kind, kind)

  @file_listbox.add(row)
end

def selected_row
  @file_listbox.selected_row
end

def selected_full_path
  r = selected_row
  r&.instance_variable_get(:@full_path)
end

def selected_kind
  r = selected_row
  r&.instance_variable_get(:@kind)
end

def set_status(msg)
  @status.text = msg.to_s
end

def ensure_selected_text_file!
  p = selected_full_path
  k = selected_kind
  if p.nil?
    set_status("⚠️ No selection.")
    return nil
  end
  unless k == :file && File.file?(p)
    set_status("⚠️ Select a FILE for this operation.")
    return nil
  end

  content = safe_read_all_text(p)
  if content == :binary
    set_status("🚫 Binary file: refusing to edit.")
    return nil
  end
  content
end

# ----------------------------
# Filtering logic
# ----------------------------
def passes_hidden?(name)
  return true if @include_hidden
  !name.start_with?(".")
end

def passes_name_filter?(display_name)
  ft = @filter_text.to_s.strip.downcase
  return true if ft.empty?
  display_name.downcase.include?(ft)
end

def passes_mode?(kind)
  case @mode
  when :files then kind == :file
  when :dirs  then kind == :dir
  else true
  end
end

def passes_ext_filter?(path, kind)
  return true unless kind == :file
  return true if @ext_filters.empty?
  @ext_filters.include?(file_ext(path))
end

# ----------------------------
# Core actions
# ----------------------------
def load_files
  dir = @directory_entry.text.strip
  unless Dir.exist?(dir)
    set_status("❌ Invalid directory: #{dir}")
    return
  end

  @current_dir = dir
  @file_listbox.children.each { |child| @file_listbox.remove(child) }
  @displayed_paths = []

  parent = File.dirname(dir)
  add_row("⬆ Up One Folder", full_path: parent, kind: :up)

  entries = Dir.entries(dir).reject { |e| e == "." || e == ".." }
  entries.select! { |name| passes_hidden?(name) }

  entries.sort_by! do |name|
    full = File.join(dir, name)
    [File.directory?(full) ? 0 : 1, name.downcase]
  end

  shown = 0
  entries.each do |name|
    full = File.join(dir, name)
    kind = File.directory?(full) ? :dir : :file
    display = kind == :dir ? "#{name}/" : name

    next unless passes_mode?(kind)
    next unless passes_name_filter?(display)
    next unless passes_ext_filter?(full, kind)

    add_row(display, full_path: full, kind: kind)
    @displayed_paths << full
    shown += 1
  end

  @file_listbox.show_all
  set_status("✅ Loaded: #{dir} | showing: #{shown} | ext: #{@ext_filters.empty? ? 'any' : @ext_filters.join(', ')}")
end

def show_preview(path)
  if File.file?(path)
    content = safe_read_text(path)
    if content == :binary
      @preview.buffer.text = "🚫 Binary file preview disabled.\n\n#{path}"
      set_status("ℹ️ Binary file selected: #{File.basename(path)}")
    else
      @preview.buffer.text = content
      set_status("📄 Preview: #{File.basename(path)}")
    end
  else
    @preview.buffer.text = ""
  end
end

def browse_folder
  dialog = Gtk::FileChooserDialog.new(
    "Select Folder",
    @window,
    Gtk::FileChooserAction::SELECT_FOLDER,
    [["Cancel", Gtk::ResponseType::CANCEL], ["Select", Gtk::ResponseType::ACCEPT]]
  )
  if dialog.run == Gtk::ResponseType::ACCEPT
    @directory_entry.text = dialog.filename
    load_files
  end
  dialog.destroy
end

# ----------------------------
# Dialog helpers
# ----------------------------
def prompt_two_fields(title:, label1:, label2:, default1: "", default2: "")
  dialog = Gtk::Dialog.new(title: title, parent: @window, flags: Gtk::DialogFlags::MODAL)
  dialog.add_button("Cancel", Gtk::ResponseType::CANCEL)
  dialog.add_button("OK", Gtk::ResponseType::ACCEPT)
  dialog.set_default_size(560, 260)

  box = Gtk::Box.new(:vertical, 10)
  box.set_border_width(10)

  box.pack_start(Gtk::Label.new(label1), expand: false, fill: false, padding: 0)
  e1 = Gtk::Entry.new
  e1.text = default1
  box.pack_start(e1, expand: false, fill: true, padding: 0)

  box.pack_start(Gtk::Label.new(label2), expand: false, fill: false, padding: 0)
  e2 = Gtk::Entry.new
  e2.text = default2
  box.pack_start(e2, expand: false, fill: true, padding: 0)

  dialog.child.add(box)
  dialog.show_all

  out = nil
  if dialog.run == Gtk::ResponseType::ACCEPT
    out = [e1.text.to_s, e2.text.to_s]
  end
  dialog.destroy
  out
end

def prompt_replace_lines_mode
  dialog = Gtk::Dialog.new(title: "Replace Lines", parent: @window, flags: Gtk::DialogFlags::MODAL)
  dialog.add_button("Cancel", Gtk::ResponseType::CANCEL)
  dialog.add_button("OK", Gtk::ResponseType::ACCEPT)
  dialog.set_default_size(640, 320)

  box = Gtk::Box.new(:vertical, 10)
  box.set_border_width(10)

  mode_combo = Gtk::ComboBoxText.new
  mode_combo.append_text("By exact line text (replace matching lines)")
  mode_combo.append_text("By line number(s) (e.g. 5,7-10)")
  mode_combo.active = 0

  box.pack_start(Gtk::Label.new("Mode:"), expand: false, fill: false, padding: 0)
  box.pack_start(mode_combo, expand: false, fill: false, padding: 0)

  label_a = Gtk::Label.new("Line text to match EXACTLY:")
  entry_a = Gtk::Entry.new
  label_b = Gtk::Label.new("Replacement line text:")
  entry_b = Gtk::Entry.new

  box.pack_start(label_a, expand: false, fill: false, padding: 0)
  box.pack_start(entry_a, expand: false, fill: true, padding: 0)
  box.pack_start(label_b, expand: false, fill: false, padding: 0)
  box.pack_start(entry_b, expand: false, fill: true, padding: 0)

  mode_combo.signal_connect("changed") do
    if mode_combo.active == 0
      label_a.text = "Line text to match EXACTLY:"
      entry_a.placeholder_text = "exact line content (no \\n)"
    else
      label_a.text = "Line number(s):"
      entry_a.placeholder_text = "e.g. 5,7-10"
    end
  end

  dialog.child.add(box)
  dialog.show_all

  out = nil
  if dialog.run == Gtk::ResponseType::ACCEPT
    out = {
      mode: (mode_combo.active == 0 ? :exact_line_text : :line_numbers),
      a: entry_a.text.to_s,
      b: entry_b.text.to_s
    }
  end
  dialog.destroy
  out
end

# ----------------------------
# Replace operations
# ----------------------------
def replace_text_exact
  content = ensure_selected_text_file!
  return unless content
  path = selected_full_path

  got = prompt_two_fields(
    title: "Replace Exact Text",
    label1: "Exact text to replace (matches literally):",
    label2: "Replacement text:"
  )
  return unless got
  old_text, new_text = got
  if old_text.empty?
    set_status("⚠️ Old text is empty; cancelled.")
    return
  end

  count = content.scan(old_text).length
  if count == 0
    set_status("ℹ️ No matches found.")
    return
  end

  bak = backup_file(path)
  updated = content.gsub(old_text, new_text)
  File.write(path, updated)

  set_status("✅ Replaced #{count} occurrence(s). Backup: #{File.basename(bak)}")
  show_preview(path)
rescue StandardError => e
  set_status("❌ Replace text failed: #{e.message}")
end

def replace_lines
  content = ensure_selected_text_file!
  return unless content
  path = selected_full_path

  cfg = prompt_replace_lines_mode
  return unless cfg

  lines = content.split("\n", -1) # keep trailing empty line
  replaced = 0

  if cfg[:mode] == :exact_line_text
    old_line = cfg[:a].to_s
    new_line = cfg[:b].to_s
    lines.map! do |ln|
      if ln == old_line
        replaced += 1
        new_line
      else
        ln
      end
    end
  else
    nums = parse_line_ranges(cfg[:a])
    if nums.empty?
      set_status("⚠️ No valid line numbers; cancelled.")
      return
    end
    new_line = cfg[:b].to_s
    nums.each do |n|
      idx = n - 1
      next if idx < 0 || idx >= lines.length
      lines[idx] = new_line
      replaced += 1
    end
  end

  if replaced == 0
    set_status("ℹ️ Nothing replaced.")
    return
  end

  bak = backup_file(path)
  File.write(path, lines.join("\n"))

  set_status("✅ Replaced #{replaced} line(s). Backup: #{File.basename(bak)}")
  show_preview(path)
rescue StandardError => e
  set_status("❌ Replace lines failed: #{e.message}")
end

# ----------------------------
# Presets
# ----------------------------
PRESETS = {
  "Code"  => [".rb", ".py", ".sh", ".zsh", ".ps1", ".bat", ".cmd", ".js", ".ts", ".json", ".yml", ".yaml", ".toml", ".ini", ".md", ".txt"],
  "Audio" => [".mp3", ".flac", ".wav", ".m4a", ".aac", ".ogg", ".opus"],
  "Video" => [".mp4", ".mkv", ".mov", ".avi", ".webm"],
  "Data"  => [".csv", ".tsv", ".json", ".xml", ".yml", ".yaml"]
}

def apply_preset(name)
  exts = PRESETS[name] || []
  @ext_entry.text = exts.join(",")
  @ext_filters = exts
  load_files
end

def copy_results_paths
  if @displayed_paths.empty?
    set_status("⚠️ No results to copy.")
    return
  end
  gtk_copy(@displayed_paths.join("\n"))
  set_status("📋 Copied #{@displayed_paths.length} result paths.")
end

def copy_results_count
  gtk_copy(@displayed_paths.length.to_s)
  set_status("📋 Copied result count: #{@displayed_paths.length}")
end

# ----------------------------
# Build UI
# ----------------------------
@window = Gtk::Window.new
@window.set_title("Finder UI (Dark + Filters + Replace)")
@window.set_default_size(1280, 760)
@window.set_border_width(10)

root = Gtk::Box.new(:vertical, 8)
@window.add(root)

# Row 1: directory
dir_row = Gtk::Box.new(:horizontal, 8)
root.pack_start(dir_row, expand: false, fill: true, padding: 0)

dir_row.pack_start(Gtk::Label.new("Directory:"), expand: false, fill: false, padding: 0)
@directory_entry = Gtk::Entry.new
@directory_entry.text = @current_dir
dir_row.pack_start(@directory_entry, expand: true, fill: true, padding: 0)

browse_btn = Gtk::Button.new(label: "Browse")
refresh_btn = Gtk::Button.new(label: "Refresh")
dir_row.pack_start(browse_btn, expand: false, fill: false, padding: 0)
dir_row.pack_start(refresh_btn, expand: false, fill: false, padding: 0)

# Row 2: filters
filter_row = Gtk::Box.new(:horizontal, 8)
root.pack_start(filter_row, expand: false, fill: true, padding: 0)

filter_row.pack_start(Gtk::Label.new("Name filter:"), expand: false, fill: false, padding: 0)
@filter_entry = Gtk::Entry.new
@filter_entry.placeholder_text = "e.g. downloader, config, script"
filter_row.pack_start(@filter_entry, expand: true, fill: true, padding: 0)

filter_row.pack_start(Gtk::Label.new("Extensions:"), expand: false, fill: false, padding: 0)
@ext_entry = Gtk::Entry.new
@ext_entry.placeholder_text = ".rb,.py,.sh  (blank = any)"
filter_row.pack_start(@ext_entry, expand: true, fill: true, padding: 0)

@hidden_check = Gtk::CheckButton.new("Include hidden")
filter_row.pack_start(@hidden_check, expand: false, fill: false, padding: 0)

filter_row.pack_start(Gtk::Label.new("Show:"), expand: false, fill: false, padding: 0)
@mode_combo = Gtk::ComboBoxText.new
@mode_combo.append_text("Both")
@mode_combo.append_text("Files only")
@mode_combo.append_text("Dirs only")
@mode_combo.active = 0
filter_row.pack_start(@mode_combo, expand: false, fill: false, padding: 0)

clear_btn = Gtk::Button.new(label: "Clear")
filter_row.pack_start(clear_btn, expand: false, fill: false, padding: 0)

# Row 3: presets + tools + replace + dark toggle
row3 = Gtk::Box.new(:horizontal, 8)
root.pack_start(row3, expand: false, fill: true, padding: 0)

row3.pack_start(Gtk::Label.new("Presets:"), expand: false, fill: false, padding: 0)
preset_buttons = {}
PRESETS.keys.each do |k|
  b = Gtk::Button.new(label: k)
  preset_buttons[k] = b
  row3.pack_start(b, expand: false, fill: false, padding: 0)
end

row3.pack_start(Gtk::Separator.new(:vertical), expand: false, fill: true, padding: 6)

copy_paths_btn = Gtk::Button.new(label: "Copy Result Paths")
copy_count_btn = Gtk::Button.new(label: "Copy Result Count")
row3.pack_start(copy_paths_btn, expand: false, fill: false, padding: 0)
row3.pack_start(copy_count_btn, expand: false, fill: false, padding: 0)

row3.pack_start(Gtk::Separator.new(:vertical), expand: false, fill: true, padding: 6)

copy_cwd_btn = Gtk::Button.new(label: "Copy Current Dir")
copy_sel_btn = Gtk::Button.new(label: "Copy Selected Path")
copy_text_btn = Gtk::Button.new(label: "Copy Preview Text")
row3.pack_start(copy_cwd_btn, expand: false, fill: false, padding: 0)
row3.pack_start(copy_sel_btn, expand: false, fill: false, padding: 0)
row3.pack_start(copy_text_btn, expand: false, fill: false, padding: 0)

row3.pack_start(Gtk::Separator.new(:vertical), expand: false, fill: true, padding: 6)

replace_text_btn = Gtk::Button.new(label: "Replace Text")
replace_lines_btn = Gtk::Button.new(label: "Replace Lines")
row3.pack_start(replace_text_btn, expand: false, fill: false, padding: 0)
row3.pack_start(replace_lines_btn, expand: false, fill: false, padding: 0)

row3.pack_start(Gtk::Separator.new(:vertical), expand: false, fill: true, padding: 6)

dark_toggle = Gtk::ToggleButton.new(label: "🌙 Dark Mode")
dark_toggle.active = true
row3.pack_start(dark_toggle, expand: false, fill: false, padding: 0)

# Main split
main = Gtk::Box.new(:horizontal, 10)
root.pack_start(main, expand: true, fill: true, padding: 0)

left_scroll = Gtk::ScrolledWindow.new
left_scroll.set_policy(Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC)
left_scroll.set_size_request(470, -1)

@file_listbox = Gtk::ListBox.new
left_scroll.add(@file_listbox)
main.pack_start(left_scroll, expand: false, fill: true, padding: 0)

right_scroll = Gtk::ScrolledWindow.new
right_scroll.set_policy(Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC)

@preview = Gtk::TextView.new
@preview.set_editable(false)
@preview.set_wrap_mode(Gtk::WrapMode::WORD_CHAR)
right_scroll.add(@preview)
main.pack_start(right_scroll, expand: true, fill: true, padding: 0)

@status = Gtk::Label.new("Ready.")
@status.set_xalign(0.0)
root.pack_start(@status, expand: false, fill: true, padding: 0)

# ----------------------------
# Signals
# ----------------------------
@window.signal_connect("destroy") { Gtk.main_quit }

browse_btn.signal_connect("clicked") { browse_folder }
refresh_btn.signal_connect("clicked") { load_files }
@directory_entry.signal_connect("activate") { load_files }

@filter_entry.signal_connect("changed") do
  @filter_text = @filter_entry.text.to_s
  load_files
end

@ext_entry.signal_connect("changed") do
  @ext_filters = normalize_exts(@ext_entry.text)
  load_files
end

@hidden_check.signal_connect("toggled") do
  @include_hidden = @hidden_check.active?
  load_files
end

@mode_combo.signal_connect("changed") do
  @mode =
    case @mode_combo.active
    when 1 then :files
    when 2 then :dirs
    else :both
    end
  load_files
end

clear_btn.signal_connect("clicked") do
  @filter_entry.text = ""
  @ext_entry.text = ""
  @hidden_check.active = false
  @mode_combo.active = 0
  @filter_text = ""
  @ext_filters = []
  @include_hidden = false
  @mode = :both
  load_files
end

preset_buttons.each do |name, btn|
  btn.signal_connect("clicked") { apply_preset(name) }
end

@file_listbox.signal_connect("row-activated") do |_listbox, row|
  path = row.instance_variable_get(:@full_path)
  kind = row.instance_variable_get(:@kind)

  case kind
  when :up, :dir
    @directory_entry.text = path
    load_files
    @preview.buffer.text = ""
  when :file
    show_preview(path)
  end
end

copy_paths_btn.signal_connect("clicked") { copy_results_paths }
copy_count_btn.signal_connect("clicked") { copy_results_count }

copy_cwd_btn.signal_connect("clicked") do
  gtk_copy(@directory_entry.text.strip)
  set_status("📋 Copied current directory.")
end

copy_sel_btn.signal_connect("clicked") do
  p = selected_full_path
  if p
    gtk_copy(p)
    set_status("📋 Copied selected path.")
  else
    set_status("⚠️ No selection to copy.")
  end
end

copy_text_btn.signal_connect("clicked") do
  txt = @preview.buffer.text.to_s
  if txt.strip.empty?
    set_status("⚠️ Nothing in preview to copy.")
  else
    gtk_copy(txt)
    set_status("📋 Copied preview text.")
  end
end

replace_text_btn.signal_connect("clicked") { replace_text_exact }
replace_lines_btn.signal_connect("clicked") { replace_lines }

dark_toggle.signal_connect("toggled") do
  enabled = dark_toggle.active?
  set_dark_mode(enabled)
  set_status(enabled ? "🌙 Dark mode enabled" : "☀️ Light mode enabled")
end

# ----------------------------
# Start
# ----------------------------
set_dark_mode(true)
load_files
@window.show_all
Gtk.main
