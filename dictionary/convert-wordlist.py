#!/usr/bin/env python3
"""把各种来源的词表转成输入法能导入的格式。

导入格式就是每行一条、TAB 分隔：
    word<TAB>中文释义<TAB>音标        (后两列可省)

公开词库下下来通常是别的格式，这个脚本负责转换、清洗、去重，并且可以先跟
现有词库比对，只留下真正缺的词。

    # 每行一个词的纯文本
    python3 convert-wordlist.py raw.txt -o medical.txt

    # Gene Ontology 之类的 OBO 本体，取 name 字段
    python3 convert-wordlist.py go-basic.obo --format obo -o bio.txt

    # MeSH ASCII（d20xx.bin），取 MH 主题词
    python3 convert-wordlist.py d2025.bin --format mesh -o mesh.txt

    # CSV/TSV，指定第几列是词、第几列是释义
    python3 convert-wordlist.py terms.csv --format csv --word-col 0 --trans-col 2 -o out.txt

    # 只输出词库里还没有的词（强烈建议加上，能看清到底新增多少）
    python3 convert-wordlist.py raw.txt --only-new -o new.txt
"""
import argparse, os, re, sqlite3, sys

DB = os.path.expanduser(
    "~/Library/Application Support/hallelujah/"
    "words_with_frequency_and_translation_and_ipa.sqlite3")
# 只收纯字母单词：words 表是单词表，带空格的词组归 Text-Expander 管
WORD_RE = re.compile(r"^[a-z][a-z'-]*[a-z]$")


def from_plain(path):
    for line in open(path, encoding="utf-8", errors="ignore"):
        line = line.strip()
        if line and not line.startswith("#"):
            yield line.split("\t")[0], ""


def from_csv(path, word_col, trans_col, sep):
    import csv as _csv
    with open(path, encoding="utf-8", errors="ignore", newline="") as f:
        for row in _csv.reader(f, delimiter=sep):
            if len(row) > word_col:
                tr = row[trans_col] if trans_col is not None and len(row) > trans_col else ""
                yield row[word_col], tr


def from_obo(path):
    """OBO 本体：取 [Term] 段里的 name。"""
    in_term = False
    for line in open(path, encoding="utf-8", errors="ignore"):
        line = line.rstrip("\n")
        if line.startswith("["):
            in_term = line.strip() == "[Term]"
        elif in_term and line.startswith("name:"):
            yield line[5:].strip(), ""


def from_mesh(path):
    """MeSH ASCII：MH = 主题词，MS = 说明（取首句当释义）。"""
    mh = ms = ""
    for line in open(path, encoding="utf-8", errors="ignore"):
        line = line.rstrip("\n")
        if line.startswith("MH = "):
            mh = line[5:].strip()
        elif line.startswith("MS = ") and not ms:
            ms = line[5:].strip()
        elif line.startswith("*NEWRECORD"):
            if mh:
                yield mh, ""
            mh = ms = ""
    if mh:
        yield mh, ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--format", choices=["plain", "csv", "tsv", "obo", "mesh"],
                    default="plain")
    ap.add_argument("--word-col", type=int, default=0)
    ap.add_argument("--trans-col", type=int)
    ap.add_argument("--only-new", action="store_true",
                    help="只保留现有词库里没有的词")
    ap.add_argument("--min-len", type=int, default=3)
    a = ap.parse_args()

    if a.format == "csv":
        rows = from_csv(a.input, a.word_col, a.trans_col, ",")
    elif a.format == "tsv":
        rows = from_csv(a.input, a.word_col, a.trans_col, "\t")
    elif a.format == "obo":
        rows = from_obo(a.input)
    elif a.format == "mesh":
        rows = from_mesh(a.input)
    else:
        rows = from_plain(a.input)

    seen, kept, dropped_form, dropped_multi = {}, 0, 0, 0
    for word, trans in rows:
        word = word.strip().lower()
        if " " in word:          # 多词术语交给 Text-Expander
            dropped_multi += 1
            continue
        if len(word) < a.min_len or not WORD_RE.match(word):
            dropped_form += 1
            continue
        if word not in seen:
            seen[word] = trans.strip()

    existing = set()
    if a.only_new:
        if not os.path.exists(DB):
            sys.exit(f"找不到词库：{DB}\n先启动一次输入法，或去掉 --only-new。")
        con = sqlite3.connect(DB)
        words = list(seen)
        for i in range(0, len(words), 900):     # 避开 SQLite 变量上限
            chunk = words[i:i + 900]
            existing.update(r[0] for r in con.execute(
                "SELECT word FROM words WHERE word IN (%s)" % ",".join("?" * len(chunk)),
                chunk))

    with open(a.output, "w", encoding="utf-8") as f:
        for word, trans in sorted(seen.items()):
            if word in existing:
                continue
            f.write(f"{word}\t{trans}\n" if trans else f"{word}\n")
            kept += 1

    print(f"读入 {len(seen) + dropped_form + dropped_multi} 条")
    print(f"  丢弃 多词术语 {dropped_multi}、不合词形 {dropped_form}")
    if a.only_new:
        print(f"  词库中已有 {len(existing)}")
    print(f"  写出 {kept} 条 -> {a.output}")


if __name__ == "__main__":
    main()
