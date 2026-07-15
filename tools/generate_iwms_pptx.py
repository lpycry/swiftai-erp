from __future__ import annotations

import html
import zipfile
from pathlib import Path


OUT = Path("docs/iWMS_Intelligent_Picking_Assignment_Upgrade.pptx")
SLIDE_W = 13.333333
SLIDE_H = 7.5
EMU = 914400

COLORS = {
    "navy": "17324D",
    "blue": "2F6BFF",
    "cyan": "17A2B8",
    "green": "22A06B",
    "amber": "F59E0B",
    "red": "D64545",
    "ink": "1F2937",
    "muted": "6B7280",
    "light": "F4F7FB",
    "panel": "FFFFFF",
    "line": "D7DEE8",
    "dark": "0B1320",
}


def e(v: float) -> int:
    return int(round(v * EMU))


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def text_runs(text: str, size: int = 18, color: str = COLORS["ink"], bold: bool = False):
    b = "<a:b/>" if bold else ""
    return (
        f'<a:r><a:rPr lang="en-US" sz="{size * 100}">{b}'
        f'<a:solidFill><a:srgbClr val="{color}"/></a:solidFill></a:rPr>'
        f"<a:t>{esc(text)}</a:t></a:r>"
    )


def para(text: str, size: int = 18, color: str = COLORS["ink"], bold: bool = False, lvl: int = 0):
    mar = 320000 + lvl * 240000
    indent = -180000 if lvl else 0
    bullet = '<a:buChar char="•"/>' if lvl or text.startswith("• ") else '<a:buNone/>'
    if text.startswith("• "):
        text = text[2:]
    return (
        f'<a:p><a:pPr marL="{mar}" indent="{indent}">{bullet}</a:pPr>'
        f"{text_runs(text, size=size, color=color, bold=bold)}"
        "</a:p>"
    )


class Slide:
    def __init__(self, title: str, section: str | None = None):
        self.title = title
        self.section = section
        self.shapes: list[str] = []
        self.sid = 1

    def next_id(self):
        self.sid += 1
        return self.sid

    def txbox(self, x, y, w, h, paragraphs, fill=None, line=None, radius=False, margins=True):
        sid = self.next_id()
        prst = "roundRect" if radius else "rect"
        fill_xml = (
            f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>' if fill else "<a:noFill/>"
        )
        line_xml = (
            f'<a:ln w="9525"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill></a:ln>'
            if line
            else '<a:ln><a:noFill/></a:ln>'
        )
        body = "".join(paragraphs) if isinstance(paragraphs, list) else paragraphs
        inset = 'lIns="144000" tIns="90000" rIns="144000" bIns="90000"' if margins else ""
        self.shapes.append(
            f"""
            <p:sp>
              <p:nvSpPr><p:cNvPr id="{sid}" name="Text {sid}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
              <p:spPr><a:xfrm><a:off x="{e(x)}" y="{e(y)}"/><a:ext cx="{e(w)}" cy="{e(h)}"/></a:xfrm>
                <a:prstGeom prst="{prst}"><a:avLst/></a:prstGeom>{fill_xml}{line_xml}</p:spPr>
              <p:txBody><a:bodyPr wrap="square" {inset}/><a:lstStyle/>{body}</p:txBody>
            </p:sp>"""
        )

    def rect(self, x, y, w, h, fill, line=None, radius=True):
        self.txbox(x, y, w, h, [para("", 1)], fill=fill, line=line, radius=radius, margins=False)

    def line(self, x1, y1, x2, y2, color=COLORS["line"], width=2):
        sid = self.next_id()
        self.shapes.append(
            f"""
            <p:cxnSp>
              <p:nvCxnSpPr><p:cNvPr id="{sid}" name="Line {sid}"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>
              <p:spPr><a:xfrm><a:off x="{e(min(x1,x2))}" y="{e(min(y1,y2))}"/><a:ext cx="{e(abs(x2-x1))}" cy="{e(abs(y2-y1))}"/></a:xfrm>
              <a:prstGeom prst="line"><a:avLst/></a:prstGeom><a:ln w="{width*12700}"><a:solidFill><a:srgbClr val="{color}"/></a:solidFill></a:ln></p:spPr>
            </p:cxnSp>"""
        )

    def header(self):
        if self.section:
            self.txbox(0.55, 0.28, 1.35, 0.28, [para(self.section.upper(), 8, COLORS["blue"], True)], fill="EAF0FF", radius=True)
        self.txbox(0.55, 0.55, 9.9, 0.55, [para(self.title, 25, COLORS["navy"], True)], margins=False)
        self.line(0.55, 1.18, 12.75, 1.18, "D8E1EE", 1)

    def xml(self):
        self.header()
        return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="F8FAFD"/></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree>
    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
    {''.join(self.shapes)}
  </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>"""


def title_slide():
    s = Slide("", None)
    s.rect(0, 0, SLIDE_W, SLIDE_H, "F7FAFE", radius=False)
    s.rect(0, 0, 0.22, SLIDE_H, COLORS["blue"], radius=False)
    s.txbox(0.7, 0.72, 2.3, 0.36, [para("IWMS UPGRADE", 10, COLORS["blue"], True)], fill="EAF0FF", radius=True)
    s.txbox(0.7, 1.35, 10.8, 1.2, [para("Intelligent Auto-Picking and Precision Workforce Assignment", 32, COLORS["navy"], True)], margins=False)
    s.txbox(0.7, 2.68, 10.7, 0.68, [para("Implementation roadmap integrating rotation cycles, multi-work-order collaboration, and dynamic item interception", 18, COLORS["muted"])], margins=False)
    s.txbox(0.7, 4.55, 4.1, 1.05, [para("Presenter", 10, COLORS["muted"], True), para("Project Management Team / [Your Name]", 17, COLORS["ink"], True)], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(5.0, 4.55, 3.4, 1.05, [para("Audience", 10, COLORS["muted"], True), para("Warehouse Operations & Key Stakeholders", 16, COLORS["ink"], True)], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(8.6, 4.55, 2.4, 1.05, [para("Date", 10, COLORS["muted"], True), para("Next Week", 17, COLORS["ink"], True)], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(10.85, 6.62, 1.8, 0.25, [para("AASC | iWMS", 9, COLORS["muted"])], margins=False)
    return s


def build_slides():
    slides = [title_slide()]

    s = Slide("1. Auto PK Creation & Multi-Dimensional Priority", "Auto PK")
    s.txbox(0.7, 1.45, 3.4, 1.9, [para("Trigger Sources", 15, COLORS["navy"], True), para("SAP DN creation: real-time capture", 12), para("iCTOS WO release: seamless manufacturing handoff", 12), para("Scheduled wave release: hourly or custom batch windows", 12)], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(4.35, 1.45, 3.95, 1.9, [para("Core Logic Updates", 15, COLORS["navy"], True), para("Assess kitting due date, order quantity, P/N, bin location, and estimated pick time", 12), para("Dynamic bin correction after S/N or Rev# changes", 12), para("RF guidance updates in real time without manual intervention", 12)], fill="FFFFFF", line="D8E1EE", radius=True)
    x0, y0 = 8.55, 1.45
    s.txbox(x0, y0, 3.7, 0.38, [para("Priority Matrix", 14, "FFFFFF", True)], fill=COLORS["navy"], radius=True)
    rows = [("P1", "Same-day shipment / customer expedite", COLORS["red"]), ("P2", "Air shipment", COLORS["amber"]), ("P3", "Standard shipment / near kitting due date", COLORS["blue"]), ("P4", "Future schedule and replenishment", COLORS["green"])]
    for i, (p, desc, col) in enumerate(rows):
        yy = y0 + 0.48 + i * 0.58
        s.txbox(x0, yy, 0.55, 0.42, [para(p, 13, "FFFFFF", True)], fill=col, radius=True)
        s.txbox(x0 + 0.68, yy, 3.0, 0.42, [para(desc, 11, COLORS["ink"])], fill="FFFFFF", line="E2E8F0", radius=True)
    s.txbox(0.7, 4.15, 11.55, 1.25, [para("Operational Result", 14, COLORS["navy"], True), para("The system creates the right PK list at the right moment, classifies urgency consistently, and keeps bin guidance synchronized when sales order attributes change after creation.", 15)], fill="EDF7FF", line="C7DFFC", radius=True)
    slides.append(s)

    s = Slide("Field Discussion: Triggering & Dynamic Updates", "Validation")
    s.txbox(0.85, 1.55, 5.3, 3.9, [para("Dynamic Interception Timing", 18, COLORS["navy"], True), para("When a PK is already in process and SAP changes S/N or Rev#, what is the red-line timing for RF voice/pop-up interception?", 15), para("Example decision point: after the picker scans the bin, should the system force an update, block the scan, or require supervisor approval?", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(6.55, 1.55, 5.3, 3.9, [para("Kitting Due Date Weighting", 18, COLORS["navy"], True), para("How should urgency be quantified for daily orders?", 15), para("If a P3 order enters a 2-hour countdown before kitting due time, should it automatically escalate to P1?", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    slides.append(s)

    s = Slide('2. Intelligent Picker Assignment & "Job Rotation" Matrix', "Assignment")
    s.txbox(0.7, 1.45, 3.5, 3.5, [para("Job Rotation Pool", 16, COLORS["navy"], True), para("Add a bi-monthly rotation configuration table in the iWMS backend.", 12), para("Supervisors import the latest cross-training roster every two months.", 12), para("The algorithm locks pickers into the active strategy pool for the current cycle.", 12)], fill="FFFFFF", line="D8E1EE", radius=True)
    pools = [("Daily Pool", "Default: 1 picker", COLORS["blue"]), ("Large-Qty Pool", "Dynamic: 1-2 pickers", COLORS["amber"]), ("iCTO/BTO Pool", "Dynamic: 2-3 pickers", COLORS["green"])]
    for i, (name, desc, col) in enumerate(pools):
        y = 1.55 + i * 0.95
        s.txbox(4.55, y, 2.3, 0.52, [para(name, 13, "FFFFFF", True)], fill=col, radius=True)
        s.txbox(7.05, y, 3.2, 0.52, [para(desc, 13, COLORS["ink"])], fill="FFFFFF", line="D8E1EE", radius=True)
        s.line(6.85, y + 0.26, 7.05, y + 0.26, "A8B3C3")
    s.txbox(4.55, 4.55, 6.55, 0.95, [para("Workload Score = Open PKs x 30% + Open Lines x 30% + Estimated Remaining Pick Time x 40%", 16, COLORS["navy"], True)], fill="EDF7FF", line="C7DFFC", radius=True)
    s.txbox(0.7, 5.65, 11.25, 0.65, [para("Assignment Rule: for each new order, iWMS selects the lowest workload-score candidate within the matching rotation pool.", 15, COLORS["ink"], True)], fill="F8FBFF", line="D8E1EE", radius=True)
    slides.append(s)

    s = Slide("Field Discussion: Flexible Pool Switching & Rotation Boundaries", "Validation")
    s.txbox(0.85, 1.55, 5.3, 3.9, [para("Cross-Pool Support", 18, COLORS["navy"], True), para("When iCTO backlog is severe, should the automated assignment engine be allowed to break the bi-monthly pool boundary?", 15), para("Decision needed: if every iCTO picker exceeds 100% load, can the system borrow capacity from the Daily Pool?", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(6.55, 1.55, 5.3, 3.9, [para("Smooth Rotation Transition", 18, COLORS["navy"], True), para("On the handover day every two months, how long should the old-order digestion period last?", 15), para("Should supervisors have a one-click option to carry unfinished tasks into the next cycle?", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    slides.append(s)

    s = Slide("3. iCTO/BTO Multi-WO Collaboration & Parallel Assignment", "Co-Picking")
    s.txbox(0.7, 1.45, 3.55, 3.7, [para("System Approach", 16, COLORS["navy"], True), para("Break the traditional one-order-one-picker constraint for complex iCTO/BTO orders.", 12), para("Identify project type and WO correlation automatically.", 12), para("Bind 4-7 highly related WOs into one picking task package.", 12)], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(4.65, 1.6, 3.45, 0.65, [para("4-7 related iCTO WOs", 15, "FFFFFF", True)], fill=COLORS["navy"], radius=True)
    s.line(6.38, 2.25, 6.38, 3.0, "A8B3C3", 2)
    s.txbox(4.65, 3.0, 3.45, 0.65, [para("One task package", 15, COLORS["navy"], True)], fill="EDF7FF", line="C7DFFC", radius=True)
    s.line(6.38, 3.65, 5.35, 4.45, "A8B3C3", 2)
    s.line(6.38, 3.65, 7.4, 4.45, "A8B3C3", 2)
    s.txbox(3.9, 4.45, 2.9, 0.65, [para("Picker A: Zones A-C", 13, "FFFFFF", True)], fill=COLORS["blue"], radius=True)
    s.txbox(6.95, 4.45, 2.9, 0.65, [para("Picker B: Zones D-F", 13, "FFFFFF", True)], fill=COLORS["green"], radius=True)
    s.txbox(9.65, 1.45, 2.5, 3.7, [para("Business Value", 16, COLORS["navy"], True), para("Improves pick speed for large or complex assembly WOs.", 12), para("Protects production schedule from warehouse material-prep delays.", 12)], fill="FFFFFF", line="D8E1EE", radius=True)
    slides.append(s)

    s = Slide("Field Discussion: Error-Proofing Parallel Picking", "Validation")
    s.txbox(0.85, 1.55, 5.3, 3.9, [para("Anti-Collision Rule", 18, COLORS["navy"], True), para("When two pickers work on the same 4-7 WO package, how should the system prevent duplicate scans?", 15), para("Options: physical bin-zone separation, system-locked item ownership, or first-scan-wins with live RF status.", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(6.55, 1.55, 5.3, 3.9, [para("Task Package Split Limit", 18, COLORS["navy"], True), para("What is the current manual judgment for how many WOs should be grouped for two people?", 15), para("Is a fixed 4-7 WO range flexible enough, or should the limit depend on line count, zones, and estimated pick time?", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    slides.append(s)

    s = Slide("4. Warehouse Zone Ownership", "Zone Routing")
    zones = [("Racks A-C", "Dedicated Picker A", COLORS["blue"]), ("Racks D-F", "Dedicated Picker B", COLORS["green"]), ("Bulk Area", "Dedicated Picker C", COLORS["amber"]), ("CTOS Area", "Dedicated Picker D", COLORS["cyan"])]
    for i, (z, owner, col) in enumerate(zones):
        x = 0.75 + (i % 2) * 3.45
        y = 1.45 + (i // 2) * 1.25
        s.txbox(x, y, 3.0, 0.45, [para(z, 14, "FFFFFF", True)], fill=col, radius=True)
        s.txbox(x, y + 0.48, 3.0, 0.45, [para(owner, 13, COLORS["ink"])], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(7.55, 1.45, 4.6, 2.85, [para("Hard Routing Rules", 16, COLORS["navy"], True), para("Single-zone order: assign directly to the zone owner.", 12), para("Cross-zone order: compare owner workload first.", 12), para("If zone owners are overloaded, assign end-to-end picking to the lowest workload-score picker across the floor.", 12)], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(0.75, 4.75, 11.4, 0.85, [para("Strategic Value: reduce non-value-added walking distance by 35%+ and increase lines picked per labor hour.", 17, COLORS["navy"], True)], fill="EDF7FF", line="C7DFFC", radius=True)
    slides.append(s)

    s = Slide("Field Discussion: Multi-Zone Fulfillment Strategy", "Validation")
    s.txbox(0.85, 1.55, 5.3, 3.9, [para("Staging Buffer", 18, COLORS["navy"], True), para("For a large order containing both rack and Bulk Area materials, where should the split parts be merged and staged?", 15), para("Decision needed: name the exact physical buffer location and ownership handoff rule.", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(6.55, 1.55, 5.3, 3.9, [para("Uneven Zone Workload", 18, COLORS["navy"], True), para("If Bulk Area has no workload while Racks A-C is overloaded, how quickly can idle zone owners be reassigned?", 15), para("Define the threshold and supervisor visibility needed for fast support.", 13, COLORS["muted"])], fill="FFFFFF", line="D8E1EE", radius=True)
    slides.append(s)

    s = Slide("5. Dynamic Workload Rebalancing", "Rebalancing")
    s.txbox(0.75, 1.45, 3.9, 1.2, [para("Circuit-Breaker Trigger", 16, COLORS["navy"], True), para("When a picker exceeds a 120% real-time workload score, iWMS locks the receiving queue for new PK tasks.", 13)], fill="FFFFFF", line="D8E1EE", radius=True)
    examples = [("Picker A", "Leave / absent", "Available capacity: 0%", COLORS["red"]), ("Picker B", "Large-order streak", "Current load: 95%", COLORS["amber"]), ("Picker C", "Standby / light load", "Current load: 40%", COLORS["green"])]
    for i, (name, state, cap, col) in enumerate(examples):
        y = 3.0 + i * 0.78
        s.txbox(0.8, y, 1.5, 0.45, [para(name, 12, "FFFFFF", True)], fill=col, radius=True)
        s.txbox(2.45, y, 3.35, 0.45, [para(f"{state} | {cap}", 12)], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(6.55, 2.0, 4.8, 2.4, [para("System Decision", 20, COLORS["navy"], True), para("Bypass A and B, then route the newly released wave directly to Picker C.", 18), para("Result: fewer bottlenecks, clearer exceptions, and balanced floor execution.", 13, COLORS["muted"])], fill="EDF7FF", line="C7DFFC", radius=True)
    slides.append(s)

    s = Slide("6. KPI Dashboard Visibility", "Dashboard")
    cards = [("Labor Productivity", "Picker utilization (%)\nPicks per hour\nLines per hour", COLORS["blue"]), ("Time Control", "Average cycle time\nNear-due / overdue PK alerts", COLORS["red"]), ("Floor Balance", "Workload balancing index\nQueue health by pool", COLORS["green"]), ("Cross-Training Impact", "Cycle-specific SLA rate by employee and order pool", COLORS["amber"])]
    for i, (title, body, col) in enumerate(cards):
        x = 0.8 + (i % 2) * 5.75
        y = 1.55 + (i // 2) * 1.85
        s.txbox(x, y, 5.05, 1.35, [para(title, 16, col, True)] + [para(t, 12) for t in body.split("\n")], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(0.8, 5.55, 10.9, 0.55, [para("Integrated with Jonhan Wu's visual management architecture for real-time supervisor floor boards.", 15, COLORS["navy"], True)], fill="EDF7FF", line="C7DFFC", radius=True)
    slides.append(s)

    s = Slide("AASC Intelligent Rollout Roadmap", "Roadmap")
    phases = [("Phase 1", "Quick Win", ["Auto-create Picking List (PK)", "Basic rotation pool by Daily / Large-Qty / iCTO", "Auto-sync S/N and Rev# bin changes"], COLORS["green"]),
              ("Phase 2", "Core Milestone", ["Activate two-person co-picking", "Enable Milpitas/Tustin zone ownership routing", "Deploy 120% workload circuit breaker"], COLORS["blue"]),
              ("Phase 3", "Long-Term Vision", ["AI-driven waves by zone + carrier + deadline", "Labor forecasting and dynamic scheduling recommendations"], COLORS["amber"])]
    for i, (phase, name, items, col) in enumerate(phases):
        x = 0.75 + i * 4.05
        s.txbox(x, 1.55, 3.55, 0.5, [para(f"{phase}: {name}", 13, "FFFFFF", True)], fill=col, radius=True)
        marks = ["[x]", "[ ]", "[ ]"][i]
        s.txbox(x, 2.15, 3.55, 3.1, [para(f"{marks} {it}", 12) for it in items], fill="FFFFFF", line="D8E1EE", radius=True)
    s.txbox(0.75, 5.75, 11.6, 0.52, [para("Transition Strategy: stabilize rules first, deepen assignment precision second, then move toward predictive warehouse orchestration.", 14, COLORS["navy"], True)], fill="EDF7FF", line="C7DFFC", radius=True)
    slides.append(s)

    return slides


def write_package(slides):
    OUT.parent.mkdir(parents=True, exist_ok=True)
    content_types = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
                     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
                     '<Default Extension="xml" ContentType="application/xml"/>',
                     '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
                     '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>',
                     '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
                     '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>']
    for i in range(1, len(slides)+1):
        content_types.append(f'<Override PartName="/ppt/slides/slide{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>')
    content_types.append("</Types>")
    pres_sld_ids = "\n".join([f'<p:sldId id="{255+i}" r:id="rId{i}"/>' for i in range(1, len(slides)+1)])
    pres_rels = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">']
    for i in range(1, len(slides)+1):
        pres_rels.append(f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i}.xml"/>')
    pres_rels.append(f'<Relationship Id="rId{len(slides)+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/></Relationships>')
    presentation = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId{len(slides)+1}"/></p:sldMasterIdLst><p:sldIdLst>{pres_sld_ids}</p:sldIdLst>
<p:sldSz cx="{e(SLIDE_W)}" cy="{e(SLIDE_H)}" type="wide"/><p:notesSz cx="6858000" cy="9144000"/><p:defaultTextStyle><a:defPPr><a:defRPr lang="en-US"/></a:defPPr></p:defaultTextStyle></p:presentation>'''
    root_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>'''
    blank_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>'''
    layout_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>'''
    master_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>'''
    master = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="1" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>'''
    layout = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>'''
    theme = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="iWMS Professional"><a:themeElements><a:clrScheme name="iWMS"><a:dk1><a:srgbClr val="0B1320"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="17324D"/></a:dk2><a:lt2><a:srgbClr val="F8FAFD"/></a:lt2><a:accent1><a:srgbClr val="2F6BFF"/></a:accent1><a:accent2><a:srgbClr val="22A06B"/></a:accent2><a:accent3><a:srgbClr val="F59E0B"/></a:accent3><a:accent4><a:srgbClr val="D64545"/></a:accent4><a:accent5><a:srgbClr val="17A2B8"/></a:accent5><a:accent6><a:srgbClr val="6B7280"/></a:accent6><a:hlink><a:srgbClr val="2F6BFF"/></a:hlink><a:folHlink><a:srgbClr val="6B7280"/></a:folHlink></a:clrScheme><a:fontScheme name="Aptos"><a:majorFont><a:latin typeface="Aptos Display"/></a:majorFont><a:minorFont><a:latin typeface="Aptos"/></a:minorFont></a:fontScheme><a:fmtScheme name="default"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>'''
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", "".join(content_types))
        z.writestr("_rels/.rels", root_rels)
        z.writestr("ppt/presentation.xml", presentation)
        z.writestr("ppt/_rels/presentation.xml.rels", "".join(pres_rels))
        z.writestr("ppt/slideMasters/slideMaster1.xml", master)
        z.writestr("ppt/slideMasters/_rels/slideMaster1.xml.rels", master_rels)
        z.writestr("ppt/slideLayouts/slideLayout1.xml", layout)
        z.writestr("ppt/slideLayouts/_rels/slideLayout1.xml.rels", layout_rels)
        z.writestr("ppt/theme/theme1.xml", theme)
        for i, slide in enumerate(slides, 1):
            z.writestr(f"ppt/slides/slide{i}.xml", slide.xml())
            z.writestr(f"ppt/slides/_rels/slide{i}.xml.rels", blank_rels)


if __name__ == "__main__":
    deck = build_slides()
    write_package(deck)
    print(f"Created {OUT} with {len(deck)} slides")
