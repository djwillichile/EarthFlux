"""Generate the EarthFlux hex logo (SVG master) from simple geometry.

Usage: python3 make-hex.py OUTPUT.svg [--icon]
  --icon  variant without the package name, for favicons and small sizes.
Requires fontTools and the Inter Bold font (path in FONT); text is converted
to outlines so the SVG does not depend on installed fonts.
"""
import math, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
import os
FONT = os.environ.get("EARTHFLUX_FONT", "/usr/share/fonts/opentype/inter/Inter-Bold.otf")
ICON = "--icon" in sys.argv
C = dict(border="#01303A", bg="#01515E", sun="#FFBE35", water="#9CE8FC", heat="#F5793B",
         crop="#98C850", crop_row="#3C9145", forest="#1E6B40", ochre="#BA894E", ochre_line="#9A6B38",
         rim="#7CBC53", tree1="#80C65A", tree2="#4F9E4A", trunk="#6E4F2E", earth="#FFFFFD", flux="#FC9C38")
def text_paths(text, size, x_center, baseline):
    f = TTFont(FONT); gs = f.getGlyphSet(); cmap = f.getBestCmap(); s = size / f["head"].unitsPerEm
    names = [cmap[ord(ch)] for ch in text]; x = x_center - sum(f["hmtx"][n][0] for n in names) * s / 2; out = []
    for n in names:
        pen = SVGPathPen(gs); gs[n].draw(TransformPen(pen, (s, 0, 0, -s, x, baseline))); out.append(pen.getCommands()); x += f["hmtx"][n][0] * s
    return out
def hexagon(cx, cy, r):
    return " ".join(f"{cx+r*math.cos(math.radians(a)):.2f},{cy+r*math.sin(math.radians(a)):.2f}" for a in (-90,-30,30,90,150,210))
circle = lambda c, fill, extra="": f'<circle cx="{c[0]}" cy="{c[1]}" r="{c[2]}" fill="{fill}" {extra}/>'
W, H, cx, cy, R = 520, 600, 260, 300, 300
EARTH = (260, 1010, 610)          # ground bottom: arc convex upwards (Earth curvature), apex y = 400
CROP = (150, 572, 244)            # crop hill (left), top y = 328
FOREST = (338, 548, 196)          # forest mound (middle-right), top y = 352
SOIL = (444, 540, 182)            # bare soil hill (right, in front), top y = 358
sx, sy, sr = 470, 98, 70
sun = [circle((sx, sy, sr), C["sun"])] + [
    f'<line x1="{sx+(sr+15)*math.cos(a):.1f}" y1="{sy+(sr+15)*math.sin(a):.1f}" x2="{sx+(sr+38)*math.cos(a):.1f}" '
    f'y2="{sy+(sr+38)*math.sin(a):.1f}" stroke="{C["sun"]}" stroke-width="10" stroke-linecap="round"/>'
    for a in (math.radians(k * 30 + 15) for k in range(12))]
def arrow(stem, head, col):
    return (f'<path d="{stem}" fill="none" stroke="{col}" stroke-width="24"/>'
            f'<polygon points="{head}" fill="{col}" stroke="{col}" stroke-width="9" stroke-linejoin="round"/>')
water = arrow("M 190 352 C 166 318, 170 290, 188 264 C 206 238, 214 214, 208 176", "208,126 240,180 176,180", C["water"])
heat = arrow("M 442 398 C 422 378, 422 362, 435 346 C 448 330, 448 314, 435 298 C 424 284, 424 274, 428 266",
             "428,220 456,270 400,270", C["heat"])
def conifer(x, base, s, col):
    t1 = f"{x},{base-118*s:.1f} {x+33*s:.1f},{base-72*s:.1f} {x-33*s:.1f},{base-72*s:.1f}"
    t2 = f"{x},{base-94*s:.1f} {x+43*s:.1f},{base-38*s:.1f} {x-43*s:.1f},{base-38*s:.1f}"
    return (f'<rect x="{x-6*s:.1f}" y="{base-42*s:.1f}" width="{12*s:.1f}" height="{46*s:.1f}" fill="{C["trunk"]}"/>'
            f'<polygon points="{t1}" fill="{col}" stroke="{col}" stroke-width="5" stroke-linejoin="round"/>'
            f'<polygon points="{t2}" fill="{col}" stroke="{col}" stroke-width="5" stroke-linejoin="round"/>')
def broadleaf(x, base, s, col):
    crown = "".join(circle((round(x+dx*s,1), round(base+dy*s,1), round(r*s,1)), col)
                    for dx, dy, r in ((0, -96, 34), (-24, -74, 27), (24, -74, 27), (0, -62, 30)))
    return f'<rect x="{x-6.5*s:.1f}" y="{base-60*s:.1f}" width="{13*s:.1f}" height="{64*s:.1f}" rx="3" fill="{C["trunk"]}"/>' + crown
trees = broadleaf(300, 362, 0.92, C["tree1"]) + conifer(356, 360, 0.95, C["tree2"])
rows = "".join(f'<path d="M {x0} 300 C {x0+34} 336, {x0+60} 372, {x0+70} 440" fill="none" stroke="{C["crop_row"]}" stroke-width="15"/>'
               for x0 in (-20, 30, 80, 130, 180, 230))
if ICON:
    text = ""
else:
    glyphs = text_paths("EarthFlux", 64, 260, 486)
    text = "".join(f'<path d="{d}" fill="{C["earth"] if i < 5 else C["flux"]}"/>' for i, d in enumerate(glyphs))
inner = hexagon(cx, cy, R * 0.915)
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-labelledby="t">
  <title id="t">EarthFlux</title>
  <defs>
    <clipPath id="inner"><polygon points="{inner}"/></clipPath>
    <clipPath id="land"><path clip-rule="evenodd" d="M -10 -10 H 530 V 610 H -10 Z M {EARTH[0]-EARTH[2]} {EARTH[1]} a {EARTH[2]} {EARTH[2]} 0 1 0 {2*EARTH[2]} 0 a {EARTH[2]} {EARTH[2]} 0 1 0 {-2*EARTH[2]} 0 Z"/></clipPath>
    <clipPath id="crop">{circle(CROP, "#000")}</clipPath>
  </defs>
  <polygon points="{hexagon(cx, cy, R-6)}" fill="{C["border"]}" stroke="{C["border"]}" stroke-width="12" stroke-linejoin="round"/>
  <polygon points="{inner}" fill="{C["bg"]}" stroke="{C["bg"]}" stroke-width="6" stroke-linejoin="round"/>
  <g clip-path="url(#inner)">
    {''.join(sun)}
    <g transform="{'translate(0 56)' if ICON else ''}">
    {water}
    {trees}
    {heat}
    <g clip-path="url(#land)">
      {circle(FOREST, C["forest"])}
      {circle(CROP, C["crop"], f'stroke="{C["bg"]}" stroke-width="6" paint-order="stroke"')}
      <g clip-path="url(#crop)">{rows}</g>
      {circle(SOIL, C["ochre"], f'stroke="{C["bg"]}" stroke-width="6" paint-order="stroke"')}
      <circle cx="{SOIL[0]}" cy="{SOIL[1]}" r="{SOIL[2]-24}" fill="none" stroke="{C["ochre_line"]}" stroke-width="7"/>
    </g>
    {circle(EARTH, C["forest"]) if ICON else ""}
    <circle cx="{EARTH[0]}" cy="{EARTH[1]}" r="{EARTH[2]}" fill="none" stroke="{C["rim"]}" stroke-width="11"/>
    </g>
    {text}
  </g>
</svg>
'''
open(sys.argv[1], "w").write(svg)
