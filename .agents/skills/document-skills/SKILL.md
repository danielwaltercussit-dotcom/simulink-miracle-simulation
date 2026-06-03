---
name: document-skills
description: Document manipulation toolkit for DOCX, PDF, PPTX, and XLSX files. Create, edit, extract, and convert documents programmatically.
---


# Document Skills

## Overview

Comprehensive toolkit for creating, editing, and manipulating documents across multiple formats including Word (DOCX), PDF, PowerPoint (PPTX), and Excel (XLSX). Use this agent for professional document processing, text extraction, tracked changes, and content manipulation.

## When to Use This Agent

Use this agent when:
- Creating or editing Word documents (.docx)
- Extracting text or tables from PDFs
- Merging, splitting, or manipulating PDF files
- Creating or modifying PowerPoint presentations
- Reading or writing Excel spreadsheets
- Converting between document formats
- Implementing tracked changes in documents
- Extracting data from document files

---

## DOCX - Word Documents

### Overview

A .docx file is a ZIP archive containing XML files and resources. Create, edit, or analyze Word documents using text extraction, raw XML access, or redlining workflows.

### Reading and Analyzing Content

#### Text Extraction
```bash
# Convert document to markdown with tracked changes
pandoc --track-changes=all path-to-file.docx -o output.md
# Options: --track-changes=accept/reject/all
```

#### Raw XML Access
```bash
# Unpack a file
python ooxml/scripts/unpack.py <office_file> <output_directory>
```

**Key file structures:**
- `word/document.xml` - Main document contents
- `word/comments.xml` - Comments referenced in document.xml
- `word/media/` - Embedded images and media files
- Tracked changes use `<w:ins>` (insertions) and `<w:del>` (deletions) tags

### Creating New Word Documents

Use **docx-js** for creating documents from scratch:

1. Read `docx-js.md` for detailed syntax and examples
2. Create JavaScript/TypeScript file using Document, Paragraph, TextRun components
3. Export as .docx using Packer.toBuffer()

### Editing Existing Documents

Use the **Document library** (Python) for editing:

1. Read `ooxml.md` for the Document library API
2. Unpack: `python ooxml/scripts/unpack.py <office_file> <output_directory>`
3. Create Python script using the Document library
4. Pack: `python ooxml/scripts/pack.py <input_directory> <office_file>`

### Redlining Workflow for Document Review

**CRITICAL**: For complete tracked changes, implement ALL changes systematically.

**Batching Strategy**: Group related changes into batches of 3-10 changes.

**Principle: Minimal, Precise Edits**
- Only mark text that actually changes
- Break replacements into: [unchanged text] + [deletion] + [insertion] + [unchanged text]
- Preserve the original run's RSID for unchanged text

**Workflow:**
1. Convert to markdown: `pandoc --track-changes=all path-to-file.docx -o current.md`
2. Identify and group changes (by section, type, or proximity)
3. Read `ooxml.md` and unpack document
4. Implement changes in batches
5. Pack: `python ooxml/scripts/pack.py unpacked reviewed-document.docx`
6. Verify: `pandoc --track-changes=all reviewed-document.docx -o verification.md`

### Converting DOCX to Images

```bash
# Convert DOCX to PDF
soffice --headless --convert-to pdf document.docx

# Convert PDF pages to JPEG
pdftoppm -jpeg -r 150 document.pdf page
```

---

## PDF - Document Processing

### Quick Start

```python
from pypdf import PdfReader, PdfWriter

# Read a PDF
reader = PdfReader("document.pdf")
print(f"Pages: {len(reader.pages)}")

# Extract text
text = ""
for page in reader.pages:
    text += page.extract_text()
```

### Common Operations

#### Merge PDFs
```python
from pypdf import PdfWriter, PdfReader

writer = PdfWriter()
for pdf_file in ["doc1.pdf", "doc2.pdf", "doc3.pdf"]:
    reader = PdfReader(pdf_file)
    for page in reader.pages:
        writer.add_page(page)

with open("merged.pdf", "wb") as output:
    writer.write(output)
```

#### Split PDF
```python
reader = PdfReader("input.pdf")
for i, page in enumerate(reader.pages):
    writer = PdfWriter()
    writer.add_page(page)
    with open(f"page_{i+1}.pdf", "wb") as output:
        writer.write(output)
```

#### Extract Text with Layout
```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    for page in pdf.pages:
        text = page.extract_text()
        print(text)
```

#### Extract Tables
```python
with pdfplumber.open("document.pdf") as pdf:
    for i, page in enumerate(pdf.pages):
        tables = page.extract_tables()
        for j, table in enumerate(tables):
            print(f"Table {j+1} on page {i+1}:")
            for row in table:
                print(row)
```

#### Create PDFs
```python
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

c = canvas.Canvas("hello.pdf", pagesize=letter)
width, height = letter

c.drawString(100, height - 100, "Hello World!")
c.save()
```

### Command-Line Tools

```bash
# Extract text
pdftotext input.pdf output.txt

# Merge with qpdf
qpdf --empty --pages file1.pdf file2.pdf -- merged.pdf

# Split pages
qpdf input.pdf --pages . 1-5 -- pages1-5.pdf

# Extract images
pdfimages -j input.pdf output_prefix
```

---

## PPTX - PowerPoint Presentations

### Overview

.pptx files are ZIP archives containing XML files for slides, layouts, themes, and media.

### Text Extraction

```bash
# Convert to markdown
pandoc presentation.pptx -o output.md
```

### Creating Presentations

Use **pptxgenjs** (JavaScript):

```bash
# Install
npm install pptxgenjs

# Create presentation
node create_presentation.js
```

Example:
```javascript
const PptxGenJS = require("pptxgenjs");
const pptx = new PptxGenJS();

const slide = pptx.addSlide();
slide.addText("Hello World", { x: 1, y: 1, fontSize: 18 });
slide.addShape(pptx.ShapeType.rect, { x: 1, y: 2, w: 5, h: 3 });

pptx.writeFile({ fileName: "presentation.pptx" });
```

### Editing Presentations

Use **python-pptx**:

```python
from pptx import Presentation

# Load presentation
prs = Presentation('existing.pptx')

# Add slide
blank_slide_layout = prs.slide_layouts[6]
slide = prs.slides.add_slide(blank_slide_layout)

# Add text
title = slide.shapes.title
title.text = "New Slide Title"

prs.save('modified.pptx')
```

### Raw XML Editing

For complex edits, unpack and edit XML directly:

```bash
# Unpack
python ooxml/scripts/unpack.py presentation.pptx unpacked/

# Edit ppt/slides/slide1.xml, ppt/presentation.xml, etc.

# Pack
python ooxml/scripts/pack.py unpacked/ presentation.pptx
```

---

## XLSX - Excel Spreadsheets

### Reading Excel Files

```python
import pandas as pd

# Read entire sheet
df = pd.read_excel('file.xlsx')

# Read specific sheet
df = pd.read_excel('file.xlsx', sheet_name='Sheet1')

# Read specific columns
df = pd.read_excel('file.xlsx', usecols=['A', 'B', 'C'])
```

### Writing Excel Files

```python
import pandas as pd

# Create DataFrame
df = pd.DataFrame({
    'Name': ['Alice', 'Bob', 'Charlie'],
    'Age': [25, 30, 35],
    'City': ['NYC', 'LA', 'Chicago']
})

# Write to Excel
df.to_excel('output.xlsx', index=False)

# Multiple sheets
with pd.ExcelWriter('output.xlsx') as writer:
    df1.to_excel(writer, sheet_name='Sheet1')
    df2.to_excel(writer, sheet_name='Sheet2')
```

### Advanced Excel Operations

```python
from openpyxl import load_workbook
from openpyxl.styles import Font, PatternFill

# Load workbook
wb = load_workbook('file.xlsx')
ws = wb.active

# Modify cells
ws['A1'] = 'New Value'
ws['A1'].font = Font(bold=True)
ws['A1'].fill = PatternFill(start_color='FFFF00', end_color='FFFF00', fill_type='solid')

# Add formula
ws['B10'] = '=SUM(B1:B9)'

# Save
wb.save('modified.xlsx')
```

---

## Quick Reference

| Format | Task | Best Tool |
|--------|------|-----------|
| DOCX | Create new | docx-js (JavaScript) |
| DOCX | Edit existing | Document library (Python) |
| DOCX | Extract text | pandoc |
| DOCX | Tracked changes | Redlining workflow |
| PDF | Extract text | pdfplumber |
| PDF | Extract tables | pdfplumber |
| PDF | Merge/split | pypdf or qpdf |
| PDF | Create | reportlab |
| PPTX | Create new | pptxgenjs |
| PPTX | Edit | python-pptx |
| PPTX | Extract | pandoc |
| XLSX | Read/Write | pandas |
| XLSX | Advanced edits | openpyxl |

## Dependencies

```bash
# DOCX
npm install -g docx
pip install defusedxml

# PDF
pip install pypdf pdfplumber reportlab
apt-get install pandoc poppler-utils qpdf

# PPTX
npm install pptxgenjs
pip install python-pptx

# XLSX
pip install pandas openpyxl
```
