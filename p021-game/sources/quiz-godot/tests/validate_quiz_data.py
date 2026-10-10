#!/usr/bin/env python3
"""Validate GAME-G017's local quiz dataset using only the Python standard library."""

from collections import Counter
from datetime import date
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def load(name):
    with (DATA / name).open("r", encoding="utf-8") as fh:
        return json.load(fh)


def fail(message):
    raise SystemExit(f"ERROR: {message}")


categories_doc = load("quiz_categories.json")
questions_doc = load("quiz_questions.json")

if categories_doc.get("schemaVersion") != 1 or questions_doc.get("schemaVersion") != 1:
    fail("unsupported schemaVersion")
if categories_doc.get("gameId") != "GAME-G017" or questions_doc.get("gameId") != "GAME-G017":
    fail("gameId mismatch")
if categories_doc.get("datasetId") != questions_doc.get("datasetId"):
    fail("datasetId mismatch")
if categories_doc.get("language") != "ja-JP" or questions_doc.get("language") != "ja-JP":
    fail("language must be ja-JP")

per_run = categories_doc.get("questionsPerRun")
if not isinstance(per_run, int) or per_run < 10:
    fail("questionsPerRun must be an integer >= 10")

categories = categories_doc.get("categories", [])
questions = questions_doc.get("questions", [])
sources = questions_doc.get("sourceCatalog", {})
if not categories or not questions or not sources:
    fail("categories, questions, and sourceCatalog must be non-empty")

category_ids = [c.get("id") for c in categories]
if len(category_ids) != len(set(category_ids)) or any(not x for x in category_ids):
    fail("category ids must be non-empty and unique")

question_ids = set()
prompts = set()
counts = Counter()
level_counts = Counter()
date_re = re.compile(r"^\d{4}-\d{2}-\d{2}$")

for key, source in sources.items():
    if not key or not isinstance(source, dict):
        fail("invalid source catalog entry")
    verified = source.get("verifiedAt")
    if not isinstance(verified, str) or not date_re.match(verified):
        fail(f"source {key}: invalid verifiedAt")
    try:
        date.fromisoformat(verified)
    except ValueError:
        fail(f"source {key}: invalid verifiedAt date")
    url = source.get("url")
    if source.get("type") != "original" and (not isinstance(url, str) or not url.startswith("https://")):
        fail(f"source {key}: external source requires https URL")

for item in questions:
    qid = item.get("id")
    if not isinstance(qid, str) or not qid or qid in question_ids:
        fail(f"question id is missing or duplicated: {qid!r}")
    question_ids.add(qid)

    prompt = item.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip() or prompt in prompts:
        fail(f"{qid}: prompt is missing or duplicated")
    prompts.add(prompt)

    category = item.get("categoryId")
    if category not in category_ids:
        fail(f"{qid}: unknown category {category!r}")
    level = item.get("level")
    if not isinstance(level, int) or level not in (1, 2, 3, 4, 5):
        fail(f"{qid}: level must be 1..5")

    choices = item.get("choices")
    if not isinstance(choices, list) or len(choices) != 4 or len(set(choices)) != 4:
        fail(f"{qid}: choices must contain exactly four unique values")
    answer = item.get("answerIndex")
    if not isinstance(answer, int) or not 0 <= answer < 4:
        fail(f"{qid}: answerIndex out of range")
    if not isinstance(item.get("explanation"), str) or not item["explanation"].strip():
        fail(f"{qid}: explanation is required")

    refs = item.get("sourceRefs")
    if not isinstance(refs, list) or not refs:
        fail(f"{qid}: sourceRefs is required")
    unknown = [ref for ref in refs if ref not in sources]
    if unknown:
        fail(f"{qid}: unknown sourceRefs {unknown}")

    verified = item.get("verifiedAt")
    if not isinstance(verified, str) or not date_re.match(verified):
        fail(f"{qid}: invalid verifiedAt")
    try:
        date.fromisoformat(verified)
    except ValueError:
        fail(f"{qid}: invalid verifiedAt date")

    counts[category] += 1
    level_counts[(category, level)] += 1

enabled_count = 0
for category in categories:
    cid = category["id"]
    expected = category.get("questionCount")
    if expected != counts[cid]:
        fail(f"{cid}: questionCount={expected}, actual={counts[cid]}")
    if category.get("enabled"):
        enabled_count += 1
        if counts[cid] < per_run:
            fail(f"{cid}: fewer questions than questionsPerRun")
        if category.get("levels") != [1, 2, 3, 4, 5]:
            fail(f"{cid}: levels must be exactly [1,2,3,4,5]")
        for level in range(1, 6):
            if level_counts[(cid, level)] < 3:
                fail(f"{cid}: level {level} needs at least 3 questions")

if len(questions) != 45:
    fail(f"expected 45 questions, got {len(questions)}")
if enabled_count != 3:
    fail(f"expected 3 enabled categories, got {enabled_count}")

print(f"OK: {len(questions)} questions / {enabled_count} enabled categories / 5 levels each")
