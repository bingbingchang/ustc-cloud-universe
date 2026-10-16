"""Download primary sources and retain page/section provenance for RAG."""
import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path

import httpx
from bs4 import BeautifulSoup
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent


def split_text(text, size=900, overlap=140):
    text = re.sub(r"[ \t]+", " ", text).strip()
    for start in range(0, len(text), size - overlap):
        part = text[start:start + size].strip()
        if len(part) >= 35:
            yield part


def ingest():
    sources = json.loads((ROOT / "sources.json").read_text(encoding="utf-8"))
    raw = ROOT / "knowledge" / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    chunks = []
    with httpx.Client(follow_redirects=True, timeout=90) as client:
        for source in sources:
            target = raw / (source["id"] + (".pdf" if source["type"] == "pdf" else ".html"))
            if not target.exists():
                response = client.get(source["url"])
                response.raise_for_status()
                target.write_bytes(response.content)
            if source["type"] == "pdf":
                pages = []
                for i, page in enumerate(PdfReader(target).pages):
                    if i + 1 in source.get("skip_pdf_pages", []):
                        continue
                    text = page.extract_text() or ""
                    heading = source.get("stop_at_heading")
                    match = re.search(r"(?im)^\s*" + re.escape(heading) + r"\s*$", text) if heading else None
                    pages.append((f"PDF第{i + 1}页", text[:match.start()] if match else text))
                    if match:
                        break
            else:
                soup = BeautifulSoup(target.read_text(encoding="utf-8"), "html.parser")
                article = soup.select_one(source["selector"])
                if article is None:
                    raise RuntimeError(f"{source['id']}: selector missing: {source['selector']}")
                for tag in article.select("script,style,nav,footer"):
                    tag.decompose()
                for table in article.select("table") if source.get("extract_tables") else []:
                    if table.find("table") is not None:
                        continue
                    rows = [" | ".join(cell.get_text(" ", strip=True) for cell in row.find_all(["th", "td"], recursive=False))
                            for row in table.find_all("tr")]
                    table.replace_with("\n" + "\n".join(rows) + "\n")
                if source.get("extract_tables") and article.name == "table":
                    text = "\n".join(" | ".join(cell.get_text(" ", strip=True) for cell in row.find_all(["th", "td"], recursive=False))
                                     for row in article.find_all("tr"))
                else:
                    text = article.get_text("\n", strip=True)
                pages = [("正文", text)]
            count_before = len(chunks)
            for location, text in pages:
                for n, part in enumerate(split_text(text)):
                    chunks.append({**source, "chunk_id": f"{source['id']}:{location}:{n}",
                                   "location": location, "text": part,
                                   "retrieved_at": datetime.now(timezone.utc).isoformat()})
            if len(chunks) == count_before:
                raise RuntimeError(f"{source['id']}: no extractable text")
            print(source["id"], len(chunks) - count_before, "chunks", flush=True)
    output = ROOT / "knowledge" / "chunks.json"
    output.write_text(json.dumps(chunks, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(chunks)} source chunks to {output}")


if __name__ == "__main__":
    argparse.ArgumentParser(description=__doc__).parse_args()
    ingest()
