#!/usr/bin/env python3
"""Extrait spec.groups des PrometheusRule vers des fichiers de règles natifs (pour promtool)."""
import pathlib
import sys
import yaml

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
for f in src.glob("*.yaml"):
    for doc in yaml.safe_load_all(f.read_text()):
        if doc and doc.get("kind") == "PrometheusRule":
            out = dst / f"{f.stem}.rules.yaml"
            out.write_text(yaml.safe_dump({"groups": doc["spec"]["groups"]}, allow_unicode=True))
            print(f"extrait : {out}")
