"""Verify the rendered CP2 report contract, including scientific qualifications."""
from html.parser import HTMLParser
from pathlib import Path
import csv
import re


class Report(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.links, self.images, self.words = set(), [], [], []
        self.hidden = 0
        self.capture = None
        self.captions = {"caption": [], "figcaption": []}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag in ("script", "style"):
            self.hidden += 1
        if tag == "a" and attrs.get("href", "").startswith("#"):
            self.links.append(attrs["href"][1:])
        if tag == "img":
            self.images.append(attrs.get("src", ""))
        if tag in self.captions:
            self.capture = tag
            self.captions[tag].append("")
        if tag in ("script", "link"):
            for attribute in ("src", "href"):
                resource = attrs.get(attribute, "")
                assert not resource or resource.startswith("data:"), "External resource"

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.hidden -= 1
        if tag == self.capture:
            self.capture = None

    def handle_data(self, data):
        if not self.hidden:
            self.words.append(data)
        if self.capture:
            self.captions[self.capture][-1] += data


report = Report()
report.feed(Path("output/checkpoint2.html").read_text())
text = re.sub(r"\s+", " ", " ".join(report.words))
with Path("output/cp2_oof_predictions.csv").open() as saved:
    for stay in csv.DictReader(saved):
        assert not re.search(r"(?<![\w.])" + re.escape(stay["RecordID"]) + r"(?![\w.])", text), "Individual patient ID in report"
assert "Bowen Zhang (bz147)" in text
assert text.index("AI-use statement") < text.index("2.1 Modeling table")
for required in (
    "ChatGPT", "OpenAI Codex", "Automated checks", "generated code required debugging",
    "one row per stay", "48-hour observation window", "184", "3733", "520",
    "quasi-complete separation", "despite convergence checks passing",
    "one death near zero and two survivors near one", "frozen model and AUROC",
    "reliable clinical risks", "coronary care unit (CCU)", "cardiac surgery recovery unit (CSRU)",
    "medical intensive care unit (MICU)", "surgical intensive care unit (SICU)",
    "alkaline phosphatase (ALP)", "alanine aminotransferase (ALT)",
    "aspartate aminotransferase (AST)", "standard deviation (SD)",
):
    assert required in text, required
for forbidden in (
    r"AI-assisted draft", r"draft for Bowen", r"Bowen must", r"student must review",
    r"student review pending", r"pending interpretation review", r"review pending",
    r"READY_FOR_STUDENT_REVIEW", r"report candidate", r"review status",
    r"remain(?:s)? pending", r"personal review (?:has|is)",
):
    assert not re.search(forbidden, text, re.I), forbidden
assert len(report.images) == 7 and all(src.startswith("data:image/") for src in report.images)
assert len(report.captions["caption"]) == 21
assert [int(re.search(r"Table (\d+)\.", s)[1]) for s in report.captions["caption"]] == list(range(1, 22))
assert len(report.captions["figcaption"]) == 7
assert [int(re.search(r"Figure\s+(\d+)", s)[1]) for s in report.captions["figcaption"]] == list(range(1, 8))
assert len(report.links) >= 10 and all(not link or link in report.ids for link in report.links)
print("CP2 rendered report passed: 21 numbered tables, 7 embedded figures, navigation, disclosure, glossary and GAM caveat.")
