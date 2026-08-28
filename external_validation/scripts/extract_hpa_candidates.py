#!/usr/bin/env python3
"""
Extract balanced 4-tier HPA DAB-IHC benchmark images from XML metadata and download them.
"""

import xml.etree.ElementTree as ET
from pathlib import Path
import csv
import ssl
import urllib.request
import sys
import time

def main():
    root = Path(__file__).resolve().parents[2]
    cache_dir = root / ".external_validation_cache" / "HPA"
    img_dir = cache_dir / "images"
    manifest_dir = root / "external_validation" / "manifests"
    img_dir.mkdir(parents=True, exist_ok=True)
    manifest_dir.mkdir(parents=True, exist_ok=True)

    genes = ["ESR1", "EPCAM", "KRT20", "PAX8"]
    tier_order = ["Not detected", "Low", "Medium", "High"]

    selected_records = []
    
    # SSL context ignoring cert verification for downloading images from HPA CDN
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    print("=== 1. Parsing HPA XML Files ===")
    for g in genes:
        xf = cache_dir / f"{g}.xml"
        if not xf.exists():
            print(f"Error: XML file {xf} not found!", file=sys.stderr)
            sys.exit(1)
            
        tree = ET.parse(xf)
        root_el = tree.getroot()
        
        candidates_by_tier = {t: [] for t in tier_order}
        
        for ab in root_el.findall(".//antibody"):
            ab_id = ab.get("id", "")
            for te in ab.findall("tissueExpression"):
                for data in te.findall("data"):
                    tissue = data.find("tissue").text if data.find("tissue") is not None else ""
                    for patient in data.findall("patient"):
                        patient_id = patient.find("patientId").text if patient.find("patientId") is not None else ""
                        staining = ""
                        intensity = ""
                        for lvl in patient.findall("level"):
                            t = lvl.get("type", "")
                            if t == "staining": staining = lvl.text
                            elif t == "intensity": intensity = lvl.text
                            elif not t: staining = lvl.text
                        
                        qty = patient.find("quantity").text if patient.find("quantity") is not None else ""
                        loc = patient.find("location").text if patient.find("location") is not None else ""
                        
                        # Find valid JPEG image URL
                        img_url = ""
                        for img in patient.findall(".//image"):
                            u = img.find("imageUrl")
                            if u is not None and u.text and u.text.endswith(".jpg"):
                                img_url = u.text
                                break
                        
                        if staining in candidates_by_tier and img_url:
                            candidates_by_tier[staining].append({
                                "gene": g,
                                "antibody_id": ab_id,
                                "patient_id": patient_id,
                                "tissue": tissue,
                                "gt_staining": staining,
                                "gt_tier_num": tier_order.index(staining),
                                "gt_intensity": intensity,
                                "gt_quantity": qty,
                                "subcellular_location": loc,
                                "image_url": img_url
                            })
                            
        print(f"Gene {g}:")
        for t in tier_order:
            cands = candidates_by_tier[t]
            seen_urls = set()
            chosen = []
            for c in cands:
                if c["image_url"] not in seen_urls:
                    seen_urls.add(c["image_url"])
                    chosen.append(c)
                    if len(chosen) == 4:
                        break
            print(f"  Tier '{t}': {len(cands)} available -> {len(chosen)} selected")
            selected_records.extend(chosen)

    print(f"\nTotal selected images: {len(selected_records)}")

    # Add image_id and filename
    for i, r in enumerate(selected_records, 1):
        tier_short = r["gt_staining"].replace(" ", "_").lower()
        r["image_id"] = f"HPA_{r['gene']}_{tier_short}_{r['patient_id']}_{i:02d}"
        r["local_filename"] = f"{r['image_id']}.jpg"

    # Write manifest
    manifest_path = manifest_dir / "hpa_ihc_dataset_manifest.csv"
    fieldnames = [
        "image_id", "gene", "antibody_id", "patient_id", "tissue",
        "subcellular_location", "gt_staining", "gt_tier_num", "gt_intensity",
        "gt_quantity", "local_filename", "image_url"
    ]
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for r in selected_records:
            writer.writerow(r)
    print(f"Manifest written to: {manifest_path}")

    # Download images
    print("\n=== 2. Downloading HPA Images ===")
    downloaded = 0
    cached = 0
    for r in selected_records:
        dest = img_dir / r["local_filename"]
        if dest.exists() and dest.stat().st_size > 1000:
            cached += 1
            continue
        try:
            req = urllib.request.Request(r["image_url"], headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
                data = resp.read()
                dest.write_bytes(data)
                downloaded += 1
                if downloaded % 10 == 0 or downloaded == len(selected_records):
                    print(f"  Downloaded {downloaded}/{len(selected_records)} images...")
                time.sleep(0.05)
        except Exception as e:
            print(f"  Error downloading {r['image_url']}: {e}", file=sys.stderr)

    print(f"Download complete: {downloaded} newly downloaded, {cached} previously cached in {img_dir}.")

if __name__ == "__main__":
    main()
