#!/usr/bin/env python3
# Script Name: scrcomppy.py
# ID: SCR-ID-20260317130916-XADT1KL0N5
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: scrcomppy
# scrcomp_pyside6_v2.py

import json
import os
import re
import sys
import difflib
from pathlib import Path

try:
    from PySide6.QtCore import Qt, QRect, QSize, Signal, QSignalBlocker
    from PySide6.QtGui import (
        QAction,
        QColor,
        QFont,
        QKeySequence,
        QPainter,
        QTextCursor,
        QTextCharFormat,
        QTextFormat,
    )
    from PySide6.QtWidgets import (
        QApplication,
        QCheckBox,
        QComboBox,
        QFileDialog,
        QHBoxLayout,
        QLabel,
        QMainWindow,
        QMessageBox,
        QPlainTextEdit,
        QTextEdit,
        QPushButton,
        QSizePolicy,
        QSplitter,
        QVBoxLayout,
        QWidget,
        QLineEdit,
    )
except ImportError as e:
    print("[ERROR] Missing dependency:", e)
    print("This script requires PySide6.\nInstall with: pip install PySide6")
    exit(1)


APP_NAME = "scrcomp_pyside6_v2"
CONFIG_DIR = Path.home() / ".config" / APP_NAME
CONFIG_FILE = CONFIG_DIR / "config.json"


def load_config() -> dict:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_config(data: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")


def line_has_path(text: str) -> bool:
    return bool(
        re.search(
            r"(/[^ \t\n\r]+|[A-Za-z]:\\[^ \t\n\r]+|\./[^ \t\n\r]+|\.\./[^ \t\n\r]+)",
            text,
        )
    )


def is_comment_line(text: str) -> bool:
    stripped = text.lstrip()
    prefixes = ("#", "//", ";", "--", "/*", "*", "*/", "<!--")
    return stripped.startswith(prefixes)


class LineNumberArea(QWidget):
    def __init__(self, editor: "CodeEditor"):
        super().__init__(editor)
        self.editor = editor

    def sizeHint(self) -> QSize:
        return QSize(self.editor.line_number_area_width(), 0)

    def paintEvent(self, event):
        self.editor.line_number_area_paint_event(event)


class CodeEditor(QPlainTextEdit):
    scrolled = Signal(int)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.line_number_area = LineNumberArea(self)

        font = QFont("Monospace")
        font.setStyleHint(QFont.StyleHint.Monospace)
        font.setPointSize(11)
        self.setFont(font)

        self.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.setTabStopDistance(4 * self.fontMetrics().horizontalAdvance(" "))

        self.blockCountChanged.connect(self.update_line_number_area_width)
        self.updateRequest.connect(self.update_line_number_area)
        self.cursorPositionChanged.connect(self.highlight_current_line)
        self.verticalScrollBar().valueChanged.connect(self._emit_scrolled)

        self.update_line_number_area_width(0)
        self.highlight_current_line()

    def _emit_scrolled(self, value: int) -> None:
        self.scrolled.emit(value)

    def line_number_area_width(self) -> int:
        digits = len(str(max(1, self.blockCount())))
        return 14 + self.fontMetrics().horizontalAdvance("9") * digits

    def update_line_number_area_width(self, _):
        self.setViewportMargins(self.line_number_area_width(), 0, 0, 0)

    def update_line_number_area(self, rect, dy):
        if dy:
            self.line_number_area.scroll(0, dy)
        else:
            self.line_number_area.update(0, rect.y(), self.line_number_area.width(), rect.height())

        if rect.contains(self.viewport().rect()):
            self.update_line_number_area_width(0)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        cr = self.contentsRect()
        self.line_number_area.setGeometry(
            QRect(cr.left(), cr.top(), self.line_number_area_width(), cr.height())
        )

    def line_number_area_paint_event(self, event):
        painter = QPainter(self.line_number_area)
        painter.fillRect(event.rect(), QColor("#0b0f14"))
        painter.setPen(QColor("#6f7b8a"))

        block = self.firstVisibleBlock()
        block_number = block.blockNumber()
        top = round(self.blockBoundingGeometry(block).translated(self.contentOffset()).top())
        bottom = top + round(self.blockBoundingRect(block).height())

        while block.isValid() and top <= event.rect().bottom():
            if block.isVisible() and bottom >= event.rect().top():
                painter.drawText(
                    0,
                    top,
                    self.line_number_area.width() - 6,
                    self.fontMetrics().height(),
                    Qt.AlignmentFlag.AlignRight,
                    str(block_number + 1),
                )

            block = block.next()
            top = bottom
            bottom = top + round(self.blockBoundingRect(block).height())
            block_number += 1

    def highlight_current_line(self):
        if self.isReadOnly():
            self.setExtraSelections([])
            return

        sel = QTextEdit.ExtraSelection()
        sel.format.setBackground(QColor("#141b24"))
        sel.format.setProperty(QTextFormat.Property.FullWidthSelection, True)
        sel.cursor = self.textCursor()
        sel.cursor.clearSelection()
        self.setExtraSelections([sel])

class CompareWindow(QMainWindow):
    def __init__(self, left_path: str | None = None, right_path: str | None = None):
        super().__init__()
        self.setWindowTitle("PySide6 Script Compare")
        self.resize(1820, 1020)

        self.config = load_config()
        self.last_dir = self.config.get("last_dir", str(Path.home()))
        self.link_scroll_enabled = self.config.get("link_scroll_enabled", True)

        self.left_path = str(Path(left_path).expanduser()) if left_path else None
        self.right_path = str(Path(right_path).expanduser()) if right_path else None

        self.left_dirty = False
        self.right_dirty = False
        self.ignore_changes = False

        self.syncing_scroll = False
        self.search_hits: list[dict] = []
        self.current_hit_index = -1

        self._build_ui()
        self._apply_dark_style()

        if self.left_path:
            self.load_file("left", self.left_path)
        if self.right_path:
            self.load_file("right", self.right_path)

        self.link_scroll_check.setChecked(self.link_scroll_enabled)
        self.update_headers()
        self.update_comparison_label()
        self.status_label.setText("Ready.")

    # ----------------------------
    # UI
    # ----------------------------
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)

        root = QVBoxLayout(central)
        root.setContentsMargins(8, 8, 8, 8)
        root.setSpacing(8)

        toolbar = QHBoxLayout()
        root.addLayout(toolbar)

        for label, handler in [
            ("Open Left", self.on_open_left),
            ("Open Right", self.on_open_right),
            ("New Left", self.on_new_left),
            ("New Right", self.on_new_right),
            ("Save Left", self.on_save_left),
            ("Save Right", self.on_save_right),
            ("Save Left As", self.on_save_left_as),
            ("Save Right As", self.on_save_right_as),
            ("Reload", self.on_reload),
            ("Clear Left", self.on_clear_left),
            ("Clear Right", self.on_clear_right),
            ("Clear Both", self.on_clear_both),
            ("Delete Left", self.on_delete_left),
            ("Delete Right", self.on_delete_right),
        ]:
            btn = QPushButton(label)
            btn.clicked.connect(handler)
            toolbar.addWidget(btn)

        self.highlight_check = QCheckBox("Highlight Differences")
        self.highlight_check.setChecked(True)
        self.highlight_check.toggled.connect(self.refresh_highlighting)
        toolbar.addWidget(self.highlight_check)

        self.link_scroll_check = QCheckBox("Link Scroll")
        self.link_scroll_check.toggled.connect(self.on_link_scroll_toggled)
        toolbar.addWidget(self.link_scroll_check)

        self.status_label = QLabel("Load two files to compare.")
        self.status_label.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        toolbar.addWidget(self.status_label)

        self.compare_label = QLabel("Comparison: --")
        toolbar.addWidget(self.compare_label)

        search_bar = QHBoxLayout()
        root.addLayout(search_bar)

        search_bar.addWidget(QLabel("Search:"))
        self.search_entry = QLineEdit()
        self.search_entry.returnPressed.connect(self.on_search)
        search_bar.addWidget(self.search_entry)

        search_bar.addWidget(QLabel("Replace:"))
        self.replace_entry = QLineEdit()
        self.replace_entry.returnPressed.connect(self.on_replace_current)
        search_bar.addWidget(self.replace_entry)

        self.scope_combo = QComboBox()
        self.scope_combo.addItems(["Both", "Left", "Right"])
        search_bar.addWidget(self.scope_combo)

        self.case_check = QCheckBox("Case")
        search_bar.addWidget(self.case_check)

        self.regex_check = QCheckBox("Regex")
        search_bar.addWidget(self.regex_check)

        for label, handler in [
            ("Find", self.on_search),
            ("Prev", self.on_prev_match),
            ("Next", self.on_next_match),
            ("Replace Current", self.on_replace_current),
            ("Replace All", self.on_replace_all),
        ]:
            btn = QPushButton(label)
            btn.clicked.connect(handler)
            search_bar.addWidget(btn)

        splitter = QSplitter(Qt.Orientation.Horizontal)
        root.addWidget(splitter, 1)

        left_wrap = QWidget()
        left_layout = QVBoxLayout(left_wrap)
        left_layout.setContentsMargins(0, 0, 0, 0)
        left_layout.setSpacing(4)

        self.left_header = QLabel("Left file: (none)")
        left_layout.addWidget(self.left_header)

        self.left_editor = CodeEditor()
        self.left_editor.textChanged.connect(self.on_left_changed)
        self.left_editor.scrolled.connect(self.on_left_scrolled)
        left_layout.addWidget(self.left_editor)

        right_wrap = QWidget()
        right_layout = QVBoxLayout(right_wrap)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(4)

        self.right_header = QLabel("Right file: (none)")
        right_layout.addWidget(self.right_header)

        self.right_editor = CodeEditor()
        self.right_editor.textChanged.connect(self.on_right_changed)
        self.right_editor.scrolled.connect(self.on_right_scrolled)
        right_layout.addWidget(self.right_editor)

        splitter.addWidget(left_wrap)
        splitter.addWidget(right_wrap)
        splitter.setSizes([910, 910])

        for label, shortcut, handler in [
            ("Open Left", "Ctrl+Shift+O", self.on_open_left),
            ("Open Right", "Ctrl+Alt+O", self.on_open_right),
            ("Save Left", "Ctrl+Shift+S", self.on_save_left),
            ("Save Right", "Ctrl+Alt+S", self.on_save_right),
            ("Find", "Ctrl+F", self.focus_search),
        ]:
            action = QAction(label, self)
            action.setShortcut(QKeySequence(shortcut))
            action.triggered.connect(handler)
            self.addAction(action)

    def _apply_dark_style(self):
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #101317;
                color: #d7dde8;
            }
            QPushButton {
                background-color: #1a212b;
                color: #d7dde8;
                border: 1px solid #2d3948;
                border-radius: 4px;
                padding: 4px 8px;
            }
            QPushButton:hover {
                background-color: #223041;
            }
            QLineEdit, QComboBox, QPlainTextEdit {
                background-color: #0d1117;
                color: #d7dde8;
                border: 1px solid #233041;
            }
            QLabel {
                color: #d7dde8;
            }
        """)

    # ----------------------------
    # helpers
    # ----------------------------
    def update_config(self):
        self.config["last_dir"] = self.last_dir
        self.config["link_scroll_enabled"] = self.link_scroll_enabled
        save_config(self.config)

    def focus_search(self):
        self.search_entry.setFocus()
        self.search_entry.selectAll()

    def choose_open_file(self, title: str) -> str | None:
        path, _ = QFileDialog.getOpenFileName(self, title, self.last_dir)
        if path:
            self.last_dir = str(Path(path).parent)
            self.update_config()
            return path
        return None

    def choose_save_file(self, title: str, current_path: str | None = None) -> str | None:
        start_dir = current_path if current_path else self.last_dir
        path, _ = QFileDialog.getSaveFileName(self, title, start_dir)
        if path:
            self.last_dir = str(Path(path).parent)
            self.update_config()
            return path
        return None

    def safe_read_text(self, path: str) -> str:
        return Path(path).read_text(encoding="utf-8", errors="replace")

    def safe_write_text(self, path: str, text: str) -> None:
        Path(path).write_text(text, encoding="utf-8")

    def editor_for_side(self, side: str) -> CodeEditor:
        return self.left_editor if side == "left" else self.right_editor

    def path_for_side(self, side: str) -> str | None:
        return self.left_path if side == "left" else self.right_path

    def set_path_for_side(self, side: str, path: str | None):
        if side == "left":
            self.left_path = path
        else:
            self.right_path = path

    def set_dirty_for_side(self, side: str, dirty: bool):
        if side == "left":
            self.left_dirty = dirty
        else:
            self.right_dirty = dirty

    def dirty_for_side(self, side: str) -> bool:
        return self.left_dirty if side == "left" else self.right_dirty

    def get_editor_text(self, side: str) -> str:
        return self.editor_for_side(side).toPlainText()

    def set_editor_text(self, side: str, text: str):
        editor = self.editor_for_side(side)
        with QSignalBlocker(editor):
            editor.setPlainText(text)

    def update_headers(self):
        left = f"Left file: {self.left_path if self.left_path else '(none)'}"
        right = f"Right file: {self.right_path if self.right_path else '(none)'}"
        if self.left_dirty:
            left += " *"
        if self.right_dirty:
            right += " *"
        self.left_header.setText(left)
        self.right_header.setText(right)

    def update_comparison_label(self):
        left_lines = self.left_editor.toPlainText().splitlines()
        right_lines = self.right_editor.toPlainText().splitlines()

        if not left_lines and not right_lines:
            self.compare_label.setText("Comparison: --")
            return

        ratio = difflib.SequenceMatcher(None, left_lines, right_lines).ratio() * 100.0
        if ratio >= 100.0:
            self.compare_label.setText("Comparison: 100% Match")
        else:
            self.compare_label.setText(f"Comparison: {ratio:.1f}% Match")

    def clear_extra_selections(self, editor: CodeEditor):
        editor.highlight_current_line()

    # ----------------------------
    # file ops
    # ----------------------------
    def load_file(self, side: str, path: str):
        try:
            text = self.safe_read_text(path)
        except Exception as e:
            self.status_label.setText(f"Failed to read {path}: {e}")
            return

        self.set_editor_text(side, text)
        self.set_path_for_side(side, path)
        self.set_dirty_for_side(side, False)
        self.update_headers()
        self.update_all_views()

    def save_side(self, side: str, save_as: bool = False):
        path = self.path_for_side(side)

        if save_as or not path:
            path = self.choose_save_file(
                f"Save {side.capitalize()} File As",
                current_path=path,
            )
            if not path:
                self.status_label.setText("Save cancelled.")
                return
            self.set_path_for_side(side, path)

        try:
            self.safe_write_text(path, self.get_editor_text(side))
        except Exception as e:
            self.status_label.setText(f"Save failed: {e}")
            return

        self.set_dirty_for_side(side, False)
        self.update_headers()
        self.status_label.setText(f"Saved {side}: {path}")

    def clear_side(self, side: str):
        self.set_editor_text(side, "")
        self.set_path_for_side(side, None)
        self.set_dirty_for_side(side, False)
        self.update_headers()
        self.update_all_views()

    def delete_side_file(self, side: str):
        path = self.path_for_side(side)
        if not path:
            self.status_label.setText(f"No {side} file loaded.")
            return

        reply = QMessageBox.question(
            self,
            f"Delete {side.capitalize()} File",
            f"Permanently delete this file?\n\n{path}",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            self.status_label.setText("Delete cancelled.")
            return

        current_text = self.get_editor_text(side)

        try:
            os.remove(path)
        except Exception as e:
            self.status_label.setText(f"Delete failed: {e}")
            return

        self.set_path_for_side(side, None)
        self.set_editor_text(side, current_text)
        self.set_dirty_for_side(side, True)
        self.update_headers()
        self.update_all_views()
        self.status_label.setText(f"Deleted {side} file from disk.")

    # ----------------------------
    # highlighting
    # ----------------------------
    def apply_diff_highlighting(self):
        self.left_editor.highlight_current_line()
        self.right_editor.highlight_current_line()

        if not self.highlight_check.isChecked():
            return

        left_lines = self.left_editor.toPlainText().splitlines()
        right_lines = self.right_editor.toPlainText().splitlines()
        matcher = difflib.SequenceMatcher(None, left_lines, right_lines)

        left_changed = set()
        right_changed = set()

        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag != "equal":
                left_changed.update(range(i1, i2))
                right_changed.update(range(j1, j2))

        self.apply_line_formats(self.left_editor, left_changed)
        self.apply_line_formats(self.right_editor, right_changed)

    def apply_line_formats(self, editor: CodeEditor, changed_lines: set[int]):
        selections = []

        for line_no in changed_lines:
            block = editor.document().findBlockByNumber(line_no)
            if not block.isValid():
                continue
            sel = QTextEdit.ExtraSelection()
            sel.cursor = QTextCursor(block)
            sel.format.setBackground(QColor("#173042"))
            sel.format.setProperty(QTextFormat.Property.FullWidthSelection, True)
            selections.append(sel)

        cur = QTextEdit.ExtraSelection()
        cur.cursor = editor.textCursor()
        cur.cursor.clearSelection()
        cur.format.setBackground(QColor("#141b24"))
        cur.format.setProperty(QTextFormat.Property.FullWidthSelection, True)
        selections.append(cur)

        editor.setExtraSelections(selections)


    def refresh_highlighting(self):
        self.update_all_views()

    def update_all_views(self):
        self.apply_diff_highlighting()
        self.update_comparison_label()
        if self.search_entry.text().strip():
            self.refresh_search_results(recenter=False)

    # ----------------------------
    # scrolling
    # ----------------------------
    def sync_scrollbars(self, source, target):
        source_max = max(1, source.maximum())
        target_max = max(1, target.maximum())
        ratio = source.value() / source_max if source_max else 0.0
        target.setValue(round(ratio * target_max))

    def on_left_scrolled(self, _value: int):
        if not self.link_scroll_enabled or self.syncing_scroll:
            return
        self.syncing_scroll = True
        try:
            self.sync_scrollbars(self.left_editor.verticalScrollBar(), self.right_editor.verticalScrollBar())
        finally:
            self.syncing_scroll = False

    def on_right_scrolled(self, _value: int):
        if not self.link_scroll_enabled or self.syncing_scroll:
            return
        self.syncing_scroll = True
        try:
            self.sync_scrollbars(self.right_editor.verticalScrollBar(), self.left_editor.verticalScrollBar())
        finally:
            self.syncing_scroll = False

    # ----------------------------
    # search / replace
    # ----------------------------
    def build_pattern(self, text: str):
        flags = 0 if self.case_check.isChecked() else re.IGNORECASE
        return re.compile(text if self.regex_check.isChecked() else re.escape(text), flags)

    def refresh_search_results(self, recenter: bool = True):
        self.search_hits = []
        self.current_hit_index = -1

        text = self.search_entry.text().strip()
        if not text:
            return

        try:
            pattern = self.build_pattern(text)
        except re.error as e:
            self.status_label.setText(f"Regex error: {e}")
            return

        scope = self.scope_combo.currentText()
        candidates = []
        if scope in ("Both", "Left"):
            candidates.append(("left", self.left_editor.toPlainText().splitlines()))
        if scope in ("Both", "Right"):
            candidates.append(("right", self.right_editor.toPlainText().splitlines()))

        for side_name, lines in candidates:
            for line_idx, raw in enumerate(lines):
                for match in pattern.finditer(raw):
                    self.search_hits.append({
                        "side": side_name,
                        "line_idx": line_idx,
                        "start": match.start(),
                        "end": match.end(),
                    })

        if not self.search_hits:
            self.status_label.setText("No matches found.")
            return

        self.current_hit_index = 0
        if recenter:
            self.jump_to_current_hit()
        self.status_label.setText(f"{len(self.search_hits)} match(es) found.")

    def jump_to_current_hit(self):
        if not self.search_hits or self.current_hit_index < 0:
            return

        hit = self.search_hits[self.current_hit_index]
        editor = self.left_editor if hit["side"] == "left" else self.right_editor
        block = editor.document().findBlockByNumber(hit["line_idx"])
        if not block.isValid():
            return

        cursor = QTextCursor(block)
        cursor.movePosition(QTextCursor.MoveOperation.Right, QTextCursor.MoveMode.MoveAnchor, hit["start"])
        cursor.movePosition(
            QTextCursor.MoveOperation.Right,
            QTextCursor.MoveMode.KeepAnchor,
            hit["end"] - hit["start"],
        )
        editor.setTextCursor(cursor)
        editor.centerCursor()
        editor.setFocus()

    def replace_once_in_line(self, line: str, search_text: str, replace_text: str) -> str:
        flags = 0 if self.case_check.isChecked() else re.IGNORECASE
        if self.regex_check.isChecked():
            return re.sub(search_text, replace_text, line, count=1, flags=flags)
        if self.case_check.isChecked():
            return line.replace(search_text, replace_text, 1)
        return re.compile(re.escape(search_text), flags).sub(replace_text, line, count=1)

    def replace_all_in_line(self, line: str, search_text: str, replace_text: str) -> str:
        flags = 0 if self.case_check.isChecked() else re.IGNORECASE
        if self.regex_check.isChecked():
            return re.sub(search_text, replace_text, line, flags=flags)
        if self.case_check.isChecked():
            return line.replace(search_text, replace_text)
        return re.compile(re.escape(search_text), flags).sub(replace_text, line)

    # ----------------------------
    # handlers
    # ----------------------------
    def on_open_left(self):
        path = self.choose_open_file("Open Left File")
        if path:
            self.load_file("left", path)
            self.status_label.setText("Left file loaded.")

    def on_open_right(self):
        path = self.choose_open_file("Open Right File")
        if path:
            self.load_file("right", path)
            self.status_label.setText("Right file loaded.")

    def on_new_left(self):
        path = self.choose_save_file("Create New Left File")
        if not path:
            self.status_label.setText("New left cancelled.")
            return
        self.set_path_for_side("left", path)
        self.set_editor_text("left", "")
        self.set_dirty_for_side("left", True)
        self.update_headers()
        self.update_all_views()
        self.status_label.setText("New left file ready.")

    def on_new_right(self):
        path = self.choose_save_file("Create New Right File")
        if not path:
            self.status_label.setText("New right cancelled.")
            return
        self.set_path_for_side("right", path)
        self.set_editor_text("right", "")
        self.set_dirty_for_side("right", True)
        self.update_headers()
        self.update_all_views()
        self.status_label.setText("New right file ready.")

    def on_save_left(self):
        self.save_side("left", save_as=False)

    def on_save_right(self):
        self.save_side("right", save_as=False)

    def on_save_left_as(self):
        self.save_side("left", save_as=True)

    def on_save_right_as(self):
        self.save_side("right", save_as=True)

    def on_reload(self):
        if self.left_path:
            self.load_file("left", self.left_path)
        if self.right_path:
            self.load_file("right", self.right_path)
        self.status_label.setText("Reloaded.")

    def on_clear_left(self):
        self.clear_side("left")
        self.status_label.setText("Left cleared.")

    def on_clear_right(self):
        self.clear_side("right")
        self.status_label.setText("Right cleared.")

    def on_clear_both(self):
        self.clear_side("left")
        self.clear_side("right")
        self.status_label.setText("Both cleared.")

    def on_delete_left(self):
        self.delete_side_file("left")

    def on_delete_right(self):
        self.delete_side_file("right")

    def on_highlight_toggled(self, _checked: bool):
        self.refresh_highlighting()

    def on_link_scroll_toggled(self, checked: bool):
        self.link_scroll_enabled = checked
        self.update_config()

    def on_left_changed(self):
        if self.ignore_changes:
            return
        self.left_dirty = True
        self.update_headers()
        self.update_all_views()

    def on_right_changed(self):
        if self.ignore_changes:
            return
        self.right_dirty = True
        self.update_headers()
        self.update_all_views()

    def on_search(self):
        if not self.search_entry.text().strip():
            self.status_label.setText("Enter search text first.")
            return
        self.refresh_search_results(recenter=True)

    def on_next_match(self):
        if not self.search_hits:
            self.on_search()
            return
        self.current_hit_index = (self.current_hit_index + 1) % len(self.search_hits)
        self.jump_to_current_hit()

    def on_prev_match(self):
        if not self.search_hits:
            self.on_search()
            return
        self.current_hit_index = (self.current_hit_index - 1) % len(self.search_hits)
        self.jump_to_current_hit()

    def on_replace_current(self):
        search_text = self.search_entry.text().strip()
        replace_text = self.replace_entry.text()
        if not search_text:
            self.status_label.setText("Enter search text first.")
            return

        if not self.search_hits:
            self.on_search()
            if not self.search_hits:
                return

        hit = self.search_hits[self.current_hit_index]
        side = hit["side"]
        lines = self.get_editor_text(side).splitlines()
        lines[hit["line_idx"]] = self.replace_once_in_line(lines[hit["line_idx"]], search_text, replace_text)

        original = self.get_editor_text(side)
        new_text = "\n".join(lines)
        if original.endswith("\n"):
            new_text += "\n"

        self.set_editor_text(side, new_text)
        self.set_dirty_for_side(side, True)
        self.update_headers()
        self.update_all_views()
        self.status_label.setText("Replaced current match.")

    def on_replace_all(self):
        search_text = self.search_entry.text().strip()
        replace_text = self.replace_entry.text()
        if not search_text:
            self.status_label.setText("Enter search text first.")
            return

        scope = self.scope_combo.currentText()
        changed_lines = 0

        for side in ("left", "right"):
            if scope == "Left" and side != "left":
                continue
            if scope == "Right" and side != "right":
                continue

            lines = self.get_editor_text(side).splitlines()
            original = self.get_editor_text(side)
            new_lines = []
            for line in lines:
                new_line = self.replace_all_in_line(line, search_text, replace_text)
                if new_line != line:
                    changed_lines += 1
                new_lines.append(new_line)

            new_text = "\n".join(new_lines)
            if original.endswith("\n"):
                new_text += "\n"

            self.set_editor_text(side, new_text)
            self.set_dirty_for_side(side, True)

        self.update_headers()
        self.update_all_views()
        self.status_label.setText(f"Replace all complete. {changed_lines} line(s) changed.")

    def closeEvent(self, event):
        if not (self.left_dirty or self.right_dirty):
            self.update_config()
            event.accept()
            return

        reply = QMessageBox.question(
            self,
            "Unsaved changes",
            "You have unsaved changes. Close anyway?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self.update_config()
            event.accept()
        else:
            event.ignore()


def main():
    app = QApplication(sys.argv)

    left_path = sys.argv[1] if len(sys.argv) >= 2 else None
    right_path = sys.argv[2] if len(sys.argv) >= 3 else None

    win = CompareWindow(left_path, right_path)
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
