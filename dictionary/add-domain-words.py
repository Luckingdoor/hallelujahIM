#!/usr/bin/env python3
"""往输入法词库里补一个领域的专业词。

输入法运行时读的是用户目录下的副本，不是 app 包里那份，所以加词不需要 sudo：
    ~/Library/Application Support/hallelujah/words_with_frequency_and_translation_and_ipa.sqlite3

词表文件每行一条，用 TAB 分隔，后两列可省略：
    word<TAB>中文释义<TAB>音标

用法：
    python3 add-domain-words.py medical.txt              # 加词
    python3 add-domain-words.py medical.txt --freq 300000
    python3 add-domain-words.py medical.txt --dry-run    # 只看不写
    python3 add-domain-words.py --list-added             # 看已加过哪些
    python3 add-domain-words.py --remove medical.txt     # 撤掉

关于 --freq：它只影响同前缀候选之间的排序，不决定词会不会出现。
参考量级：the=231亿、computer=2.2亿、algorithm=1600万、词库中位数≈9万。
默认 300000 大约落在全库前 25%~30%，既能排在生僻词前面，又不会顶掉日常词。
"""
import argparse, os, sqlite3, sys

DB = os.path.expanduser(
    "~/Library/Application Support/hallelujah/"
    "words_with_frequency_and_translation_and_ipa.sqlite3")
MARK = "__domain__"          # 记录哪些词是后加的，便于撤销


def connect():
    if not os.path.exists(DB):
        sys.exit(f"找不到词库：{DB}\n先启动一次输入法，它会把词库复制到用户目录。")
    con = sqlite3.connect(DB)
    con.execute("CREATE TABLE IF NOT EXISTS domain_words ("
                "word TEXT PRIMARY KEY, source TEXT, frequency INT)")
    # 表结构要和输入法内置的导入功能保持一致，否则两边互相插不进去
    cols = {r[1] for r in con.execute("PRAGMA table_info(domain_words)")}
    if "frequency" not in cols:
        con.execute("ALTER TABLE domain_words ADD COLUMN frequency INT")
    return con


def read_terms(path):
    terms = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            word = parts[0].strip()
            if not word:
                continue
            if " " in word:
                print(f"  跳过多词术语（words 表只存单词）：{word}")
                continue
            terms.append((word.lower(),
                          parts[1].strip() if len(parts) > 1 else "",
                          parts[2].strip() if len(parts) > 2 else ""))
    return terms


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file", nargs="?")
    ap.add_argument("--freq", type=int, default=300000)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--list-added", action="store_true")
    ap.add_argument("--remove", metavar="FILE")
    a = ap.parse_args()

    con = connect()
    if a.list_added:
        rows = con.execute("SELECT source, COUNT(*) FROM domain_words "
                           "GROUP BY source").fetchall()
        if not rows:
            print("还没有加过领域词。")
        for src, n in rows:
            print(f"  {src}: {n} 条")
        return

    if a.remove:
        src = os.path.basename(a.remove)
        words = [r[0] for r in con.execute(
            "SELECT word FROM domain_words WHERE source=?", (src,))]
        con.executemany("DELETE FROM words WHERE word=?", [(w,) for w in words])
        con.execute("DELETE FROM domain_words WHERE source=?", (src,))
        con.commit()
        print(f"已撤除 {len(words)} 条（来自 {src}）")
        return

    if not a.file:
        ap.error("需要词表文件，或用 --list-added / --remove")

    terms = read_terms(a.file)
    src = os.path.basename(a.file)
    existing = {r[0] for r in con.execute(
        "SELECT word FROM words WHERE word IN (%s)" %
        ",".join("?" * len(terms)), [t[0] for t in terms])} if terms else set()
    new = [t for t in terms if t[0] not in existing]

    print(f"词表 {src}: 共 {len(terms)} 条，已存在 {len(existing)} 条，新增 {len(new)} 条")
    if a.dry_run:
        for w, tr, ipa in new[:20]:
            print(f"    + {w}  {tr}")
        if len(new) > 20:
            print(f"    ... 另有 {len(new)-20} 条")
        return

    con.executemany(
        "INSERT OR REPLACE INTO words (word, frequency, translation, ipa) "
        "VALUES (?,?,?,?)", [(w, a.freq, tr, ipa) for w, tr, ipa in new])
    con.executemany("INSERT OR REPLACE INTO domain_words (word, source, frequency) "
                    "VALUES (?,?,?)", [(w, src, a.freq) for w, _, _ in new])
    con.commit()
    print(f"已写入 {len(new)} 条，frequency={a.freq}")
    print("重启输入法生效：pkill -9 hallelujah")


if __name__ == "__main__":
    main()
