"""Generate the EarthFlux horizontal logo (wordmark) from the shared geometry.

Usage: python3 make-wordmark.py OUTPUT.svg [--light | --transparent]
  --light        version for light backgrounds (dark text, transparent background).
  --transparent  dark-background colours without the background rectangle, for
                 pages that already have a dark background (README in dark mode).
The symbol is the landscape of the hex logo inside a circular emblem; the name
uses Inter Bold converted to outlines ("Earth" warm white, "Flux" light blue).
"""
import sys
from earthflux_scene import C, circle, text_paths, sun, defs, landscape

LIGHT = "--light" in sys.argv
TRANSPARENT = LIGHT or "--transparent" in sys.argv
BG, EARTH_TXT, FLUX_TXT = ("none", "#01303A", "#087E9C") if LIGHT else ("#012C35", "#F8F8F4", "#5CD0E8")
W, H = 1720, 540
EMBLEM = (260, 278, 228)                  # emblem circle in landscape coordinates
OFFSET = (36, -8)                         # places the emblem in the canvas
size, baseline, x0 = 220, 350, 590
glyphs, width = text_paths("EarthFlux", size, baseline, x_left=x0)
text = "".join(f'<path d="{d}" fill="{EARTH_TXT if i < 5 else FLUX_TXT}"/>' for i, d in enumerate(glyphs))
background = "" if TRANSPARENT else f'<rect width="{W}" height="{H}" fill="{BG}"/>'
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-labelledby="t">
  <title id="t">EarthFlux</title>
  <defs>
    <clipPath id="emblem">{circle(EMBLEM, "#000")}</clipPath>
    {defs()}
  </defs>
  {background}
  <g transform="translate({OFFSET[0]} {OFFSET[1]})">
    {circle(EMBLEM, C["bg"])}
    <g clip-path="url(#emblem)">
      {sun()}
      {landscape(fill_ground=True)}
    </g>
  </g>
  {text}
</svg>
'''
open(sys.argv[1], "w").write(svg)
print(f"text from x={x0} to x={x0 + width:.0f} (canvas width {W})")
