#!/usr/bin/env python3
# Script Name: recent-emails.py
# ID: SCR-ID-20260317130859-RNGPEGI6NW
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: recent-emails

import imaplib
import email
from email.header import decode_header
import getpass
import sys

def decode_maybe(value):
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8", errors="replace")
        except Exception:
            return value.decode(errors="replace")
    return str(value)

def decode_header_value(raw_value):
    if not raw_value:
        return ""
    parts = decode_header(raw_value)
    decoded = []
    for part, enc in parts:
        if isinstance(part, bytes):
            try:
                decoded.append(part.decode(enc or "utf-8", errors="replace"))
            except Exception:
                decoded.append(part.decode("utf-8", errors="replace"))
        else:
            decoded.append(part)
    return "".join(decoded)

def main():
    print("=== Read-Only Email Viewer ===")
    print("This script ONLY signs in and reads headers. It does NOT delete or modify mail.\n")

    # Common servers for quick help
    print("Common IMAP servers (for reference):")
    print("  - Gmail   : imap.gmail.com")
    print("  - Outlook : outlook.office365.com")
    print("  - Yahoo   : imap.mail.yahoo.com")
    print("  - iCloud  : imap.mail.me.com\n")

    imap_server = input("IMAP server (e.g. imap.gmail.com): ").strip()
    if not imap_server:
        print("IMAP server is required.")
        sys.exit(1)

    email_address = input("Your email address (login username): ").strip()
    if not email_address:
        print("Email address is required.")
        sys.exit(1)

    print("\nPassword will NOT be echoed.")
    password = getpass.getpass("Password (or app password if required): ")

    # How many recent emails to show
    try:
        num_to_show = int(input("How many recent emails to show [10]: ").strip() or "10")
    except ValueError:
        num_to_show = 10

    print("\nConnecting via SSL to", imap_server, "...")
    try:
        mail = imaplib.IMAP4_SSL(imap_server)
    except Exception as e:
        print(f"Error connecting to server: {e}")
        sys.exit(1)

    print("Logging in...")
    try:
        mail.login(email_address, password)
    except imaplib.IMAP4.error as e:
        print(f"Login failed: {e}")
        print("\nIf you're using Gmail or another provider with 2FA, you may need an app-specific password.")
        sys.exit(1)

    # Select inbox in read-only mode
    try:
        mail.select("INBOX", readonly=True)
    except Exception as e:
        print(f"Could not select INBOX: {e}")
        mail.logout()
        sys.exit(1)

    # Search all messages
    print("Searching for messages in INBOX...")
    try:
        status, data = mail.search(None, "ALL")
    except Exception as e:
        print(f"Search failed: {e}")
        mail.logout()
        sys.exit(1)

    if status != "OK":
        print("Search did not return OK status.")
        mail.logout()
        sys.exit(1)

    msg_ids = data[0].split()
    if not msg_ids:
        print("No messages found in INBOX.")
        mail.logout()
        sys.exit(0)

    # Take the last N message IDs (most recent)
    msg_ids = msg_ids[-num_to_show:]

    print(f"\nShowing up to {len(msg_ids)} most recent messages:\n")
    for i, msg_id in enumerate(reversed(msg_ids), start=1):
        status, msg_data = mail.fetch(msg_id, "(RFC822.HEADER)")
        if status != "OK":
            print(f"[{i}] Could not fetch message {msg_id.decode()}")
            continue

        raw_email = msg_data[0][1]
        msg = email.message_from_bytes(raw_email)

        from_raw = msg.get("From", "")
        to_raw = msg.get("To", "")
        subject_raw = msg.get("Subject", "")
        date_raw = msg.get("Date", "")

        from_decoded = decode_header_value(from_raw)
        to_decoded = decode_header_value(to_raw)
        subject_decoded = decode_header_value(subject_raw)
        date_decoded = decode_maybe(date_raw)

        print("=" * 60)
        print(f"[{i}]")
        print(f"From   : {from_decoded}")
        print(f"To     : {to_decoded}")
        print(f"Subject: {subject_decoded}")
        print(f"Date   : {date_decoded}")

    print("\nDone. Logged out safely.")
    mail.logout()

if __name__ == "__main__":
    main()
