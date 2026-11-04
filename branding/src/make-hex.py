"""Generate the EarthFlux hex logo (SVG master) from simple geometry.

Usage: python3 make-hex.py OUTPUT.svg [--icon]
  --icon  variant without the package name, for favicons and small sizes.
Requires fontTools and the Inter Bold font (EARTHFLUX_FONT); text is converted
to outlines so the SVG does not depend on installed fonts.
"""
import sys
from earthflux_scene import C, hexagon, text_paths, sun, defs, landscape

ICON = "--icon" in sys.argv
W, H, cx, cy, R = 520, 600, 260, 300, 300
inner = hexagon(cx, cy, R * 0.915)
if ICON:
    text = ""
else:
    glyphs, _ = text_paths("EarthFlux", 64, 486, x_center=260)
    text = "".join(f'<path d="{d}" fill="{C["earth"] if i < 5 else C["flux"]}"/>' for i, d in enumerate(glyphs))
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-labelledby="t">
  <title id="t">EarthFlux</title>
  <defs>
    <clipPath id="inner"><polygon points="{inner}"/></clipPath>
    {defs()}
  </defs>
  <polygon points="{hexagon(cx, cy, R-6)}" fill="{C["border"]}" stroke="{C["border"]}" stroke-width="12" stroke-linejoin="round"/>
  <polygon points="{inner}" fill="{C["bg"]}" stroke="{C["bg"]}" stroke-width="6" stroke-linejoin="round"/>
  <g clip-path="url(#inner)">
    {sun()}
    <g transform="{'translate(0 56)' if ICON else ''}">{landscape(fill_ground=ICON)}</g>
    {text}
  </g>
</svg>
'''
open(sys.argv[1], "w").write(svg)
