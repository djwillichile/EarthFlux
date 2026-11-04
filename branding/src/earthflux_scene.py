"""Shared geometry of the EarthFlux logos (hex sticker, icon and wordmark).

The landscape is drawn in a 520 x 600 coordinate system: a crop hill with
diagonal rows, a forest mound with a broadleaf tree and a conifer, a bare-soil
hill, a water flux (latent heat, ET) rising from the crops, a heat flux
(sensible heat) rising from the dry soil, a large sun and a land band whose
lower edge follows the curvature of the Earth.
"""
import math, os
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

FONT = os.environ.get("EARTHFLUX_FONT", "/usr/share/fonts/opentype/inter/Inter-Bold.otf")
C = dict(border="#01303A", bg="#01515E", sun="#FFBE35", water="#9CE8FC", heat="#F5793B",
         crop="#98C850", crop_row="#3C9145", forest="#1E6B40", ochre="#BA894E", ochre_line="#9A6B38",
         rim="#7CBC53", tree1="#80C65A", tree2="#4F9E4A", trunk="#6E4F2E", earth="#FFFFFD", flux="#FC9C38")
EARTH = (260, 1010, 610)   # ground bottom: arc convex upwards (Earth curvature), apex y = 400
CROP = (150, 572, 244)     # crop hill (left), top y = 328
FOREST = (338, 548, 196)   # forest mound (middle-right), top y = 352
SOIL = (444, 540, 182)     # bare soil hill (right, in front), top y = 358
SUN = (470, 98, 70)

def circle(c, fill, extra=""):
    return f'<circle cx="{c[0]}" cy="{c[1]}" r="{c[2]}" fill="{fill}" {extra}/>'

def hexagon(cx, cy, r):
    return " ".join(f"{cx+r*math.cos(math.radians(a)):.2f},{cy+r*math.sin(math.radians(a)):.2f}"
                    for a in (-90, -30, 30, 90, 150, 210))

def text_paths(text, size, baseline, x_center=None, x_left=None):
    """Glyph outlines of `text` (one SVG path per character) and the total width."""
    f = TTFont(FONT); gs = f.getGlyphSet(); cmap = f.getBestCmap(); s = size / f["head"].unitsPerEm
    names = [cmap[ord(ch)] for ch in text]; width = sum(f["hmtx"][n][0] for n in names) * s
    x = x_left if x_left is not None else x_center - width / 2; out = []
    for n in names:
        pen = SVGPathPen(gs); gs[n].draw(TransformPen(pen, (s, 0, 0, -s, x, baseline)))
        out.append(pen.getCommands()); x += f["hmtx"][n][0] * s
    return out, width

def sun():
    sx, sy, sr = SUN
    rays = "".join(
        f'<line x1="{sx+(sr+15)*math.cos(a):.1f}" y1="{sy+(sr+15)*math.sin(a):.1f}" x2="{sx+(sr+38)*math.cos(a):.1f}" '
        f'y2="{sy+(sr+38)*math.sin(a):.1f}" stroke="{C["sun"]}" stroke-width="10" stroke-linecap="round"/>'
        for a in (math.radians(k * 30 + 15) for k in range(12)))
    return circle(SUN, C["sun"]) + rays

def _arrow(stem, head, col):
    return (f'<path d="{stem}" fill="none" stroke="{col}" stroke-width="24"/>'
            f'<polygon points="{head}" fill="{col}" stroke="{col}" stroke-width="9" stroke-linejoin="round"/>')

def _conifer(x, base, s, col):
    t1 = f"{x},{base-118*s:.1f} {x+33*s:.1f},{base-72*s:.1f} {x-33*s:.1f},{base-72*s:.1f}"
    t2 = f"{x},{base-94*s:.1f} {x+43*s:.1f},{base-38*s:.1f} {x-43*s:.1f},{base-38*s:.1f}"
    return (f'<rect x="{x-6*s:.1f}" y="{base-42*s:.1f}" width="{12*s:.1f}" height="{46*s:.1f}" fill="{C["trunk"]}"/>'
            f'<polygon points="{t1}" fill="{col}" stroke="{col}" stroke-width="5" stroke-linejoin="round"/>'
            f'<polygon points="{t2}" fill="{col}" stroke="{col}" stroke-width="5" stroke-linejoin="round"/>')

def _broadleaf(x, base, s, col):
    crown = "".join(circle((round(x+dx*s, 1), round(base+dy*s, 1), round(r*s, 1)), col)
                    for dx, dy, r in ((0, -96, 34), (-24, -74, 27), (24, -74, 27), (0, -62, 30)))
    return f'<rect x="{x-6.5*s:.1f}" y="{base-60*s:.1f}" width="{13*s:.1f}" height="{64*s:.1f}" rx="3" fill="{C["trunk"]}"/>' + crown

def defs(prefix="ef"):
    e = EARTH
    return (f'<clipPath id="{prefix}-land"><path clip-rule="evenodd" d="M -10 -10 H 530 V 610 H -10 Z '
            f'M {e[0]-e[2]} {e[1]} a {e[2]} {e[2]} 0 1 0 {2*e[2]} 0 a {e[2]} {e[2]} 0 1 0 {-2*e[2]} 0 Z"/></clipPath>'
            f'<clipPath id="{prefix}-crop">{circle(CROP, "#000")}</clipPath>')

def landscape(prefix="ef", fill_ground=False, bg=None):
    """Fluxes, trees, hills and the Earth rim. `fill_ground` paints the area
    below the Earth curvature (used when there is no text below it)."""
    bg = bg or C["bg"]
    water = _arrow("M 190 352 C 166 318, 170 290, 188 264 C 206 238, 214 214, 208 176", "208,126 240,180 176,180", C["water"])
    heat = _arrow("M 442 398 C 422 378, 422 362, 435 346 C 448 330, 448 314, 435 298 C 424 284, 424 274, 428 266",
                  "428,220 456,270 400,270", C["heat"])
    trees = _broadleaf(300, 362, 0.92, C["tree1"]) + _conifer(356, 360, 0.95, C["tree2"])
    rows = "".join(f'<path d="M {x0} 300 C {x0+34} 336, {x0+60} 372, {x0+70} 440" fill="none" stroke="{C["crop_row"]}" stroke-width="15"/>'
                   for x0 in (-20, 30, 80, 130, 180, 230))
    return (water + trees + heat +
            f'<g clip-path="url(#{prefix}-land)">'
            + circle(FOREST, C["forest"])
            + circle(CROP, C["crop"], f'stroke="{bg}" stroke-width="6" paint-order="stroke"')
            + f'<g clip-path="url(#{prefix}-crop)">{rows}</g>'
            + circle(SOIL, C["ochre"], f'stroke="{bg}" stroke-width="6" paint-order="stroke"')
            + f'<circle cx="{SOIL[0]}" cy="{SOIL[1]}" r="{SOIL[2]-24}" fill="none" stroke="{C["ochre_line"]}" stroke-width="7"/>'
            + '</g>'
            + (circle(EARTH, C["forest"]) if fill_ground else "")
            + f'<circle cx="{EARTH[0]}" cy="{EARTH[1]}" r="{EARTH[2]}" fill="none" stroke="{C["rim"]}" stroke-width="11"/>')
