"""Split the source icon sheet into 7 individual transparent PNGs.

We auto-detect each icon by finding connected bright (cyan) regions in the
source image, then filter out the small text-label regions and keep the
8 large glyph regions, mapping them by position to the right name.
"""

from PIL import Image
import os

SRC = r"C:\Users\Florence\Pictures\Minimalist fitness category icons.png"
OUT_DIR = r"C:\Users\Florence\workspace\workout_app\assets\icons"
os.makedirs(OUT_DIR, exist_ok=True)

src = Image.open(SRC).convert("RGBA")
W, H = src.size
px = src.load()

# Build a binary "bright" mask
LUM_THRESHOLD = 80
bright = [[False] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        r, g, b, _ = px[x, y]
        if 0.2126 * r + 0.7152 * g + 0.0722 * b > LUM_THRESHOLD:
            bright[y][x] = True

# Connected-component labeling (4-connectivity, iterative flood-fill)
labels = [[0] * W for _ in range(H)]
components = []  # list of (minx, miny, maxx, maxy, area)
next_label = 0
for sy in range(H):
    for sx in range(W):
        if not bright[sy][sx] or labels[sy][sx] != 0:
            continue
        next_label += 1
        stack = [(sx, sy)]
        minx = maxx = sx
        miny = maxy = sy
        area = 0
        while stack:
            x, y = stack.pop()
            if x < 0 or y < 0 or x >= W or y >= H:
                continue
            if not bright[y][x] or labels[y][x] != 0:
                continue
            labels[y][x] = next_label
            area += 1
            if x < minx: minx = x
            if x > maxx: maxx = x
            if y < miny: miny = y
            if y > maxy: maxy = y
            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        components.append((minx, miny, maxx, maxy, area))

# Merge components whose bounding boxes are close (icons made of disjoint strokes).
def merged_bbox(boxes):
    minx = min(b[0] for b in boxes)
    miny = min(b[1] for b in boxes)
    maxx = max(b[2] for b in boxes)
    maxy = max(b[3] for b in boxes)
    return (minx, miny, maxx, maxy)

# Drop very small noise.
comps = [c for c in components if c[4] >= 30]

# Greedy spatial clustering: merge components whose bboxes are within `gap` px.
def boxes_overlap_or_close(a, b, gap=25):
    return not (a[2] + gap < b[0] or b[2] + gap < a[0] or a[3] + gap < b[1] or b[3] + gap < a[1])

clusters = []
for c in comps:
    placed = False
    for cl in clusters:
        if any(boxes_overlap_or_close(c, m) for m in cl):
            cl.append(c)
            placed = True
            break
    if not placed:
        clusters.append([c])

# Repeat until stable (clusters can transitively merge).
changed = True
while changed:
    changed = False
    new_clusters = []
    for cl in clusters:
        merged_into = None
        for nc in new_clusters:
            if any(boxes_overlap_or_close(a, b) for a in cl for b in nc):
                nc.extend(cl)
                merged_into = nc
                changed = True
                break
        if merged_into is None:
            new_clusters.append(cl[:])
    clusters = new_clusters

cluster_boxes = [merged_bbox(cl) for cl in clusters]

# Each cluster has a bbox. Glyphs are large (>=100 px in either dim AND >=80
# in the other), labels are short wide strips with small max-dim.
def is_glyph(b):
    w = b[2] - b[0]
    h = b[3] - b[1]
    return max(w, h) >= 100 and min(w, h) >= 60
glyphs = [b for b in cluster_boxes if is_glyph(b)]

# Sort top-to-bottom then left-to-right and group into rows.
glyphs.sort(key=lambda b: (b[1], b[0]))
rows = []
ROW_GAP = 80
for g in glyphs:
    if not rows or g[1] - rows[-1][-1][1] > ROW_GAP:
        rows.append([g])
    else:
        rows[-1].append(g)
for r in rows:
    r.sort(key=lambda b: b[0])

print(f"Found {len(glyphs)} glyph clusters in {len(rows)} rows:")
for i, r in enumerate(rows):
    print(f"  row {i}: {[(b[0], b[1], b[2]-b[0], b[3]-b[1]) for b in r]}")

# Expected layout:
#   row 0: arms, back, chest
#   row 1: abs, legs, cardio
#   row 2: bodyweight, plank-Custom (skip)
#   row 3: cross-Custom
NAMES = [
    ["arms", "back", "chest"],
    ["abs", "legs", "cardio"],
    ["bodyweight", None],  # second one is the plank we skip
    ["custom"],
]

assert len(rows) == len(NAMES), f"row count mismatch: {len(rows)} vs {len(NAMES)}"

def to_transparent(img):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if lum < 60:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, min(255, int(lum * 1.6)))
    return img

PAD = 14
for row, names in zip(rows, NAMES):
    for box, name in zip(row, names):
        if name is None:
            continue
        l, t, r, b = box
        l = max(0, l - PAD)
        t = max(0, t - PAD)
        r = min(W, r + PAD)
        b = min(H, b + PAD)
        crop = src.crop((l, t, r, b))
        crop = to_transparent(crop)
        # Square it so all icons render at the same physical size.
        cw, ch = crop.size
        side = max(cw, ch)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(crop, ((side - cw) // 2, (side - ch) // 2))
        out = os.path.join(OUT_DIR, f"{name}.png")
        square.save(out)
        print(f"wrote {out}  ({side}x{side})")

print("done")
