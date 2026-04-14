#!/usr/bin/env python3
# Script Name: insta-loader.py
# ID: SCR-ID-20260317130745-6U3SZD6SHP
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: insta-loader

import instaloader
import getpass
import os
from pathlib import Path

def prompt_choice(prompt, choices):
    print(f"\n{prompt}")
    for i, choice in enumerate(choices, 1):
        print(f"  [{i}] {choice}")
    while True:
        try:
            selection = int(input("Choose an option: "))
            if 1 <= selection <= len(choices):
                return selection
        except ValueError:
            pass
        print("Invalid choice. Try again.")

def ask_path(default="~/Downloads/insta_backup"):
    user_input = input(f"\nWhere to save downloads? (default: {default})\n> ").strip()
    if not user_input:
        user_input = default
    return Path(os.path.expanduser(user_input))

def ask_filter():
    print("\nPost type filter (optional):")
    print("[1] All posts")
    print("[2] Only photos")
    print("[3] Only videos")
    choice = input("Choose a filter (1-3): ")
    return choice.strip()

def main():
    print("== Instagram Downloader ==")
    username = input("Instagram username: ").strip()
    password = getpass.getpass("Instagram password (input hidden): ")

    L = instaloader.Instaloader()
    try:
        L.login(username, password)
    except Exception as e:
        print(f"Login failed: {e}")
        return

    # Ask for download type
    mode = prompt_choice("What do you want to download?", [
        "Your own profile",
        "Another public profile",
        "Posts from a hashtag",
        "List of your followers",
        "List of who you're following"
    ])

    target_path = ask_path()
    L.dirname_pattern = str(target_path)

    post_filter = ask_filter()

    if mode == 1 or mode == 2:
        target_user = username if mode == 1 else input("Target Instagram username: ").strip()
        profile = instaloader.Profile.from_username(L.context, target_user)
        for post in profile.get_posts():
            if post_filter == '2' and not post.typename == 'GraphImage':
                continue
            if post_filter == '3' and not post.typename == 'GraphVideo':
                continue
            L.download_post(post, target=profile.username)
    elif mode == 3:
        hashtag = input("Enter hashtag (without #): ").strip()
        for post in instaloader.Hashtag.from_name(L.context, hashtag).get_posts():
            if post_filter == '2' and not post.typename == 'GraphImage':
                continue
            if post_filter == '3' and not post.typename == 'GraphVideo':
                continue
            L.download_post(post, target=f"#{hashtag}")
    elif mode == 4:
        profile = instaloader.Profile.from_username(L.context, username)
        print(f"\n{username}'s Followers:")
        for follower in profile.get_followers():
            print(f" - {follower.username}")
    elif mode == 5:
        profile = instaloader.Profile.from_username(L.context, username)
        print(f"\n{username} is Following:")
        for followee in profile.get_followees():
            print(f" - {followee.username}")

    print("\n✅ Done.")

if __name__ == "__main__":
    main()
