# XPeng G6 Manual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the XPeng G6 PDF manual (367 pages, English) into a Spanish MkDocs site hosted on GitHub Pages, queryable by Claude via WebFetch.

**Architecture:** A one-time Python script extracts text and images from the PDF using PyMuPDF, translates each chapter to Spanish via `claude -p`, and writes one `.md` file per chapter into `docs/`. MkDocs Material builds the static site; GitHub Actions deploys it to GitHub Pages on every push to `main`.

**Tech Stack:** Python 3.12, PyMuPDF 1.27, MkDocs Material 9.x, GitHub Actions, `claude -p` (OAuth, no API key)

## Global Constraints

- Python interpreter: `python3.12` (has PyMuPDF and MkDocs installed at `/opt/homebrew/lib/python3.12`)
- PDF source: `/Users/german/Downloads/G6 2025-LHD User Manual.pdf` (367 pages, 38.6 MB)
- Project root: `~/development/xpeng-g6-manual/`
- Chapter .md files named: `cap01-bienvenida.md`, `cap02-perfil-vehiculo.md`, etc.
- Images named: `capXX-imgYY.png` (zero-padded), stored in `docs/images/`
- Image references in Markdown: `![Imagen N](images/capXX-imgYY.png)` (relative to docs/)
- Translation: `claude -p` via subprocess with stdin pipe; timeout 300s per chunk
- Chunk size for translation: 3000 characters max (fits comfortably in context)
- Progress file: `scripts/.progress.json` — tracks which chapters are done; allows resuming
- `mkdocs.yml` is generated/overwritten by the script after conversion
- MkDocs command: `python3.12 -m mkdocs`
- GitHub repo name: `xpeng-g6-manual`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `scripts/convert.py` | Create | Full pipeline: extract → translate → write |
| `scripts/.progress.json` | Auto-created | Tracks completed chapters |
| `docs/images/` | Auto-populated | Extracted PNG images |
| `docs/cap01-bienvenida.md` … `docs/cap16-informacion-vehiculo.md` | Auto-generated | Chapter content in Spanish |
| `docs/index.md` | Auto-generated | Master index with chapter descriptions |
| `mkdocs.yml` | Auto-generated | MkDocs config + nav |
| `.github/workflows/deploy.yml` | Create | CI: build + deploy to GitHub Pages |
| `.gitignore` | Create | Ignore common artifacts |

---

## Task 1: Project scaffold

**Files:**
- Create: `~/development/xpeng-g6-manual/` (new git repo)
- Create: `.gitignore`
- Create: `docs/images/.gitkeep`
- Create: `scripts/.gitkeep`

- [ ] **Step 1: Create the project directory and initialize git**

```bash
mkdir -p ~/development/xpeng-g6-manual/docs/images
mkdir -p ~/development/xpeng-g6-manual/scripts
cd ~/development/xpeng-g6-manual
git init
```

- [ ] **Step 2: Create `.gitignore`**

```
site/
__pycache__/
*.pyc
.DS_Store
scripts/.progress.json
```

Write that content to `~/development/xpeng-g6-manual/.gitignore`.

- [ ] **Step 3: Add placeholder files so git tracks empty dirs**

```bash
touch ~/development/xpeng-g6-manual/docs/images/.gitkeep
touch ~/development/xpeng-g6-manual/scripts/.gitkeep
```

- [ ] **Step 4: Initial commit**

```bash
cd ~/development/xpeng-g6-manual
git add .gitignore docs/images/.gitkeep scripts/.gitkeep
git commit -m "chore: project scaffold"
```

Expected: 1 commit, 3 files.

---

## Task 2: PDF extractor

**Files:**
- Create: `scripts/convert.py`

**Interfaces:**
- Produces:
  - `Chapter` dataclass: `num: int`, `title: str`, `slug: str`, `start_page: int`, `end_page: int`
  - `get_chapter_ranges(pdf_path: str) -> list[Chapter]`
  - `extract_chapter_content(doc: fitz.Document, chapter: Chapter, images_dir: Path) -> str`

- [ ] **Step 1: Create `scripts/convert.py` with the Chapter dataclass and extractor**

Write `~/development/xpeng-g6-manual/scripts/convert.py` with this content:

```python
#!/usr/bin/env python3.12
"""Convert XPeng G6 PDF manual to Spanish MkDocs site."""

import fitz  # PyMuPDF
import json
import re
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

PDF_PATH = Path("/Users/german/Downloads/G6 2025-LHD User Manual.pdf")
PROJECT_ROOT = Path(__file__).parent.parent
DOCS_DIR = PROJECT_ROOT / "docs"
IMAGES_DIR = DOCS_DIR / "images"
PROGRESS_FILE = Path(__file__).parent / ".progress.json"
CHUNK_SIZE = 3000  # chars per translation chunk

CHAPTER_SLUGS = [
    "bienvenida",
    "perfil-vehiculo",
    "xos",
    "asistencia-realidad-virtual",
    "imagen-inteligente",
    "asistencia-conduccion",
    "estacionamiento-asistido",
    "seguridad-activa",
    "viaje-seguro",
    "entrada-salida",
    "operacion-conduccion",
    "configuracion-confort",
    "instrucciones-carga",
    "mantenimiento-diario",
    "rescate-emergencia",
    "informacion-vehiculo",
]


@dataclass
class Chapter:
    num: int        # 1-based
    title: str      # English title from TOC
    slug: str       # Spanish slug
    start_page: int # 0-based (PyMuPDF)
    end_page: int   # 0-based inclusive


def get_chapter_ranges(pdf_path: Path) -> list[Chapter]:
    """Extract level-1 TOC entries as chapter boundaries."""
    doc = fitz.open(str(pdf_path))
    toc = doc.get_toc()
    doc.close()

    level1 = [(title, page - 1) for level, title, page in toc if level == 1]
    chapters = []
    for i, (title, start) in enumerate(level1):
        end = level1[i + 1][1] - 1 if i + 1 < len(level1) else 366  # 0-based last page
        slug = CHAPTER_SLUGS[i] if i < len(CHAPTER_SLUGS) else f"capitulo-{i+1:02d}"
        chapters.append(Chapter(
            num=i + 1,
            title=title,
            slug=slug,
            start_page=start,
            end_page=end,
        ))
    return chapters


def extract_chapter_content(doc: fitz.Document, chapter: Chapter, images_dir: Path) -> str:
    """Extract text and images for a chapter. Images saved to images_dir."""
    parts = []
    image_count = 0

    for page_num in range(chapter.start_page, chapter.end_page + 1):
        page = doc[page_num]

        # Extract text blocks and image blocks in reading order
        blocks = page.get_text("blocks")
        blocks.sort(key=lambda b: (round(b[1] / 20), b[0]))  # sort by row then x

        for block in blocks:
            block_type = block[6]
            if block_type == 0:  # text
                text = block[4].strip()
                if text and len(text) > 2:
                    parts.append(text)
            elif block_type == 1:  # image placeholder in block list
                # Images are extracted separately below
                pass

        # Extract images for this page
        for img_info in page.get_images(full=False):
            xref = img_info[0]
            image_count += 1
            img_name = f"cap{chapter.num:02d}-img{image_count:02d}.png"
            img_path = images_dir / img_name
            if not img_path.exists():
                pix = fitz.Pixmap(doc, xref)
                if pix.n > 4:  # CMYK → RGB
                    pix = fitz.Pixmap(fitz.csRGB, pix)
                pix.save(str(img_path))
            parts.append(f"![Imagen {image_count}](images/{img_name})")

    return "\n\n".join(parts)
```

- [ ] **Step 2: Test chapter range detection**

```bash
cd ~/development/xpeng-g6-manual
python3.12 -c "
from scripts.convert import get_chapter_ranges, PDF_PATH
chapters = get_chapter_ranges(PDF_PATH)
for c in chapters:
    print(c.num, c.title, f'pp{c.start_page+1}-{c.end_page+1}')
"
```

Expected: 16 lines, first is `1 Hello, XPENG friend pp1-3`, last is `16 Vehicle Information pp350-367`.

- [ ] **Step 3: Test image/text extraction on first chapter**

```bash
python3.12 -c "
import fitz
from scripts.convert import get_chapter_ranges, extract_chapter_content, PDF_PATH, IMAGES_DIR
IMAGES_DIR.mkdir(parents=True, exist_ok=True)
doc = fitz.open(str(PDF_PATH))
chapters = get_chapter_ranges(PDF_PATH)
content = extract_chapter_content(doc, chapters[0], IMAGES_DIR)
print(content[:800])
print('---')
print('Images created:', list(IMAGES_DIR.glob('cap01*')))
"
```

Expected: English text from "Hello, XPENG friend" chapter, plus image references if any.

- [ ] **Step 4: Commit**

```bash
cd ~/development/xpeng-g6-manual
git add scripts/convert.py
git commit -m "feat: PDF extractor — chapter ranges and text/image extraction"
```

---

## Task 3: Translation function

**Files:**
- Modify: `scripts/convert.py`

**Interfaces:**
- Consumes: `content: str` (English Markdown-ish text)
- Produces: `translate_text(content: str) -> str` (Spanish text)
- Produces: `translate_chapter_content(content: str) -> str` (splits into chunks, translates each)

- [ ] **Step 1: Add translation functions to `scripts/convert.py`**

Add after `extract_chapter_content`:

```python
def translate_text(text: str) -> str:
    """Translate a single chunk of English text to Spanish using claude -p."""
    prompt = (
        "Sos un traductor técnico. Traducí el siguiente texto de un manual de auto "
        "del inglés al español. Conservá todo el formato Markdown, las listas, los "
        "encabezados y las referencias a imágenes exactamente como están. "
        "Devolvé únicamente el texto traducido, sin explicaciones ni comentarios.\n\n"
        + text
    )
    result = subprocess.run(
        ["claude", "-p"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Translation failed (exit {result.returncode}): {result.stderr[:200]}")
    return result.stdout.strip()


def translate_chapter_content(content: str) -> str:
    """Split content into CHUNK_SIZE chunks, translate each, reassemble."""
    if len(content) <= CHUNK_SIZE:
        return translate_text(content)

    # Split at paragraph boundaries
    paragraphs = content.split("\n\n")
    chunks: list[str] = []
    current = ""
    for para in paragraphs:
        if len(current) + len(para) > CHUNK_SIZE and current:
            chunks.append(current.strip())
            current = para
        else:
            current = current + "\n\n" + para if current else para
    if current.strip():
        chunks.append(current.strip())

    translated_parts = []
    for i, chunk in enumerate(chunks, 1):
        print(f"    chunk {i}/{len(chunks)} ({len(chunk)} chars)...", end=" ", flush=True)
        translated_parts.append(translate_text(chunk))
        print("ok")

    return "\n\n".join(translated_parts)
```

- [ ] **Step 2: Test translation on a short paragraph**

```bash
python3.12 -c "
from scripts.convert import translate_text
result = translate_text('The seat belt must be worn at all times while the vehicle is in motion. Failure to do so may result in serious injury.')
print(result)
"
```

Expected: Spanish translation of the sentence, no extra commentary.

- [ ] **Step 3: Commit**

```bash
cd ~/development/xpeng-g6-manual
git add scripts/convert.py
git commit -m "feat: translation — claude -p chunks with paragraph-boundary splitting"
```

---

## Task 4: Markdown writer and index generator

**Files:**
- Modify: `scripts/convert.py`

**Interfaces:**
- Consumes: `chapter: Chapter`, `translated_content: str`, `docs_dir: Path`
- Produces:
  - `write_chapter_md(chapter: Chapter, translated_title: str, content: str, docs_dir: Path) -> Path`
  - `generate_index_md(chapters: list[Chapter], translated_titles: dict[int, str], docs_dir: Path)`

- [ ] **Step 1: Add writer functions to `scripts/convert.py`**

Add after `translate_chapter_content`:

```python
def write_chapter_md(chapter: Chapter, translated_title: str, content: str, docs_dir: Path) -> Path:
    """Write a translated chapter to docs/capXX-slug.md."""
    filename = f"cap{chapter.num:02d}-{chapter.slug}.md"
    path = docs_dir / filename
    header = f"# {translated_title}\n\n"
    path.write_text(header + content, encoding="utf-8")
    return path


def generate_index_md(chapters: list[Chapter], translated_titles: dict[int, str], docs_dir: Path) -> None:
    """Write docs/index.md with chapter list and short descriptions."""
    lines = [
        "# Manual de Usuario — XPeng G6\n",
        "> Manual traducido al español. Versión del sistema: V5.8.0.\n",
        "## Capítulos\n",
    ]
    for ch in chapters:
        title = translated_titles.get(ch.num, ch.title)
        filename = f"cap{ch.num:02d}-{ch.slug}.md"
        lines.append(f"- [{ch.num}. {title}]({filename})")
    (docs_dir / "index.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_mkdocs_yml(chapters: list[Chapter], translated_titles: dict[int, str]) -> None:
    """Write mkdocs.yml with full nav."""
    nav_entries = ["  - Índice: index.md"]
    for ch in chapters:
        title = translated_titles.get(ch.num, ch.title)
        filename = f"cap{ch.num:02d}-{ch.slug}.md"
        nav_entries.append(f"  - '{ch.num}. {title}': {filename}")

    content = f"""site_name: XPeng G6 — Manual de Usuario
site_url: https://germanpereyra.github.io/xpeng-g6-manual/  # replace with your GitHub username

theme:
  name: material
  language: es
  features:
    - navigation.instant
    - navigation.top
    - search.highlight

plugins:
  - search:
      lang: es

nav:
{chr(10).join(nav_entries)}
"""
    (PROJECT_ROOT / "mkdocs.yml").write_text(content, encoding="utf-8")
```

- [ ] **Step 2: Test full pipeline for chapter 1**

```bash
python3.12 -c "
import fitz
from scripts.convert import *
doc = fitz.open(str(PDF_PATH))
chapters = get_chapter_ranges(PDF_PATH)
ch = chapters[0]
content = extract_chapter_content(doc, ch, IMAGES_DIR)
translated = translate_chapter_content(content)
translated_title = translate_text(ch.title)
path = write_chapter_md(ch, translated_title, translated, DOCS_DIR)
print('Written:', path)
print(path.read_text()[:400])
"
```

Expected: file `docs/cap01-bienvenida.md` created with Spanish content, `# Bienvenido, amigo XPENG` or similar header.

- [ ] **Step 3: Commit**

```bash
cd ~/development/xpeng-g6-manual
git add scripts/convert.py
git commit -m "feat: Markdown writer, index generator, mkdocs.yml generator"
```

---

## Task 5: Progress tracking and main orchestrator

**Files:**
- Modify: `scripts/convert.py`

**Interfaces:**
- Consumes: all previous functions
- Produces: `main()` — entry point that runs the full pipeline with resume support

- [ ] **Step 1: Add progress tracking and `main()` to `scripts/convert.py`**

Add at the end of the file:

```python
def load_progress() -> dict:
    if PROGRESS_FILE.exists():
        return json.loads(PROGRESS_FILE.read_text())
    return {"done": [], "translated_titles": {}}


def save_progress(done: list[int], translated_titles: dict[str, str]) -> None:
    PROGRESS_FILE.write_text(json.dumps(
        {"done": done, "translated_titles": translated_titles}, indent=2
    ))


def main() -> None:
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    progress = load_progress()
    done: list[int] = progress["done"]
    translated_titles: dict[str, str] = progress["translated_titles"]

    doc = fitz.open(str(PDF_PATH))
    chapters = get_chapter_ranges(PDF_PATH)

    print(f"Found {len(chapters)} chapters. Already done: {done}")

    for chapter in chapters:
        if chapter.num in done:
            print(f"  [{chapter.num:02d}] {chapter.title} — skipped (already done)")
            continue

        print(f"  [{chapter.num:02d}] {chapter.title} (pp{chapter.start_page+1}-{chapter.end_page+1})")

        print("    Extracting...", end=" ", flush=True)
        content = extract_chapter_content(doc, chapter, IMAGES_DIR)
        print(f"ok ({len(content)} chars)")

        print("    Translating title...", end=" ", flush=True)
        translated_title = translate_text(chapter.title)
        translated_titles[str(chapter.num)] = translated_title
        print(f"ok → {translated_title!r}")

        print("    Translating content...")
        translated_content = translate_chapter_content(content)

        write_chapter_md(chapter, translated_title, translated_content, DOCS_DIR)
        done.append(chapter.num)
        save_progress(done, translated_titles)
        print(f"    Saved cap{chapter.num:02d}-{chapter.slug}.md")

    doc.close()

    # Convert string keys back to int for index/nav functions
    int_titles = {int(k): v for k, v in translated_titles.items()}
    generate_index_md(chapters, int_titles, DOCS_DIR)
    write_mkdocs_yml(chapters, int_titles)
    print("\nDone! Run: python3.12 -m mkdocs serve")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Dry-run with chapters 1–2 to verify resume works**

```bash
cd ~/development/xpeng-g6-manual
# First remove any cap01 created in task 4 test so we start clean
rm -f docs/cap01-bienvenida.md docs/index.md mkdocs.yml
python3.12 scripts/convert.py
# After it finishes chapter 1, Ctrl+C to simulate interruption, then re-run
# The second run should skip chapter 1 and continue from chapter 2
```

Expected on re-run: `[01] Hello, XPENG friend — skipped (already done)`.

- [ ] **Step 3: Commit**

```bash
cd ~/development/xpeng-g6-manual
git add scripts/convert.py
git commit -m "feat: main orchestrator with progress tracking and resume support"
```

---

## Task 6: Run full conversion

- [ ] **Step 1: Run the full pipeline**

```bash
cd ~/development/xpeng-g6-manual
python3.12 scripts/convert.py
```

This will take 15–45 minutes (16 chapters × multiple translation chunks each). The progress file saves after each chapter so it can be safely interrupted and resumed.

Expected output ends with: `Done! Run: python3.12 -m mkdocs serve`

- [ ] **Step 2: Verify all 16 chapter files exist**

```bash
ls docs/cap*.md | wc -l
```

Expected: `16`

- [ ] **Step 3: Preview locally**

```bash
cd ~/development/xpeng-g6-manual
python3.12 -m mkdocs serve
```

Open `http://127.0.0.1:8000` in a browser. Check:
- Sidebar shows all 16 chapters
- Spanish content is readable
- Images display inline
- Search works (try "cinturón" or "frenos")

Press Ctrl+C when done.

- [ ] **Step 4: Commit all generated content**

```bash
cd ~/development/xpeng-g6-manual
git add docs/ mkdocs.yml
git commit -m "feat: add converted Spanish manual content (16 chapters)"
```

---

## Task 7: GitHub Actions deploy

**Files:**
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 1: Create the workflow file**

Create `~/development/xpeng-g6-manual/.github/workflows/deploy.yml`:

```yaml
name: Deploy MkDocs to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install MkDocs Material
        run: pip install mkdocs-material

      - name: Build and deploy
        run: mkdocs gh-deploy --force
```

- [ ] **Step 2: Create the GitHub repository**

```bash
cd ~/development/xpeng-g6-manual
gh repo create xpeng-g6-manual --public --source=. --remote=origin --push
```

Expected: repo created at `https://github.com/<tu-usuario>/xpeng-g6-manual`.

- [ ] **Step 3: Enable GitHub Pages**

```bash
GH_USER=$(gh api user -q .login)
gh api repos/$GH_USER/xpeng-g6-manual/pages \
  --method POST \
  -f source='{"branch":"gh-pages","path":"/"}' 2>/dev/null || \
  echo "Pages may already be enabled or will be enabled by first deploy"
```

Alternatively: go to GitHub repo → Settings → Pages → Source: Deploy from branch → `gh-pages` / `/ (root)`.

- [ ] **Step 4: Push workflow and verify CI**

```bash
cd ~/development/xpeng-g6-manual
git add .github/
git commit -m "ci: add GitHub Actions deploy to GitHub Pages"
git push origin main
```

Then:

```bash
gh run watch
```

Expected: workflow completes successfully, `gh-pages` branch created.

- [ ] **Step 5: Verify the live site**

```bash
gh browse
```

Open `https://<tu-usuario>.github.io/xpeng-g6-manual/` in a browser. Verify the site loads with the Spanish manual content and images.

- [ ] **Step 6: Test Claude WebFetch**

In Claude Code, run:
```
fetch https://<tu-usuario>.github.io/xpeng-g6-manual/
```

Expected: Claude reads the index page, sees all 16 chapter links, can navigate to any chapter.
