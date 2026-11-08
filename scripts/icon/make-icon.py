#!/usr/bin/env python3
"""Ecosystem icon generator: macOS 26 "Tahoe" Liquid Glass style, light mode.

    python3 scripts/icon/make-icon.py scripts/icon/tether.json Tether/AppIcon.icon

House style (shared by every app):
  • light frosted plate (system-light fill) — the system adds the glass rim, depth and shadow
  • a glyph made of a few chunky, colourful "gel" pieces, each its own glass layer
  • each piece gets a subtle top-light gradient + soft highlight so it reads as 3D even on older macOS

Spec JSON:
  {
    "pieces": [                          // front → back
      {"name": "body", "color": "#1E88FF", "d": "<svg path data on a 1024 canvas>",
       "evenodd": false, "opacity": 1.0}
    ]
  }
"""
import json, os, sys

spec_path, out = sys.argv[1], sys.argv[2]
spec = json.load(open(spec_path))
assets = os.path.join(out, "Assets")
os.makedirs(assets, exist_ok=True)
for f in os.listdir(assets):
    os.remove(os.path.join(assets, f))

def shade(hex_color, amount):
    """Lighten (amount > 0) or darken (amount < 0) a #RRGGBB colour."""
    h = hex_color.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    if amount >= 0:
        r, g, b = (round(c + (255 - c) * amount) for c in (r, g, b))
    else:
        r, g, b = (round(c * (1 + amount)) for c in (r, g, b))
    return f"#{r:02X}{g:02X}{b:02X}"

layers = []
for p in spec["pieces"]:
    c = p["color"]
    rule = ' fill-rule="evenodd"' if p.get("evenodd") else ""
    opacity = p.get("opacity", 1.0)
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
  <linearGradient id="base" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{shade(c, 0.14)}"/>
    <stop offset="0.55" stop-color="{c}"/>
    <stop offset="1" stop-color="{shade(c, -0.08)}"/>
  </linearGradient>
  <radialGradient id="hi" cx="0.35" cy="0.18" r="0.55">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.3"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
  <clipPath id="clip"><path{rule} d="{p['d']}"/></clipPath>
</defs>
<g opacity="{opacity}">
  <path{rule} fill="url(#base)" d="{p['d']}"/>
  <rect clip-path="url(#clip)" x="0" y="0" width="1024" height="1024" fill="url(#hi)"/>
</g>
</svg>"""
    name = f"{p['name']}.svg"
    with open(os.path.join(assets, name), "w") as f:
        f.write(svg)
    layers.append({"image-name": name, "name": p["name"]})

# One glass group per piece so each reads as a separate gel shape, like the Tahoe icons.
groups = [{
    "name": l["name"],
    "layers": [l],
    "shadow": {"kind": "layer-color", "opacity": 0.5},
    "translucency": {"enabled": False, "value": 0},
    "specular": True,
} for l in layers]

icon = {
    "fill": "system-light",
    "groups": groups,
    "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
}
with open(os.path.join(out, "icon.json"), "w") as f:
    json.dump(icon, f, indent=2)
print("wrote", out, "with", len(layers), "pieces")
