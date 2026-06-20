#!/usr/bin/env python3
"""Convert a Claude Code .jsonl transcript into clean user<->assistant text.

Strips the noise that pollutes extraction: tool_use / tool_result blocks,
system-reminder wrappers, thinking blocks, attachments, hook output. Keeps
only the actual conversational substance — what the user said and what the
assistant said back in prose.

Usage:
  transcript_to_text.py <transcript.jsonl> [--tail-chars N] [--since-line N]
"""
import json, sys, argparse, re

REMINDER = re.compile(r"<system-reminder>.*?</system-reminder>", re.S)
PERSISTED = re.compile(r"<persisted-output>.*?</persisted-output>", re.S)


def text_from_content(content):
    """Pull just the text blocks out of a message's content."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    out = []
    for block in content:
        if not isinstance(block, dict):
            continue
        btype = block.get("type")
        if btype == "text":
            out.append(block.get("text", ""))
        # skip tool_use, tool_result, thinking, image, etc. — that's the noise
    return "\n".join(out)


def clean(s):
    s = REMINDER.sub("", s)
    s = PERSISTED.sub("", s)
    return s.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("transcript")
    ap.add_argument("--tail-chars", type=int, default=0,
                    help="keep only the last N chars (0 = all)")
    ap.add_argument("--since-line", type=int, default=0,
                    help="skip records before this line (watermark)")
    args = ap.parse_args()

    turns = []
    with open(args.transcript) as fh:
        for i, line in enumerate(fh):
            if i < args.since_line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("type") not in ("user", "assistant"):
                continue
            msg = d.get("message")
            if not isinstance(msg, dict):
                continue
            role = msg.get("role")
            txt = clean(text_from_content(msg.get("content")))
            if not txt:
                continue
            label = "USER" if role == "user" else "ASSISTANT"
            turns.append(f"### {label}\n{txt}")

    out = "\n\n".join(turns)
    if args.tail_chars and len(out) > args.tail_chars:
        out = out[-args.tail_chars:]
    sys.stdout.write(out)


if __name__ == "__main__":
    main()
