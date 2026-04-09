"""Convert the solid cross 'custom.png' to a stroked outline matching the
other icons (which are line drawings, not filled shapes)."""

from PIL import Image

PATH = r"C:\Users\Florence\workspace\workout_app\assets\icons\custom.png"
STROKE = 6  # outline thickness in px

img = Image.open(PATH).convert("RGBA")
w, h = img.size
src = img.load()

# Build solid mask from alpha.
solid = [[src[x, y][3] > 30 for x in range(w)] for y in range(h)]

def is_edge(x, y):
    if not solid[y][x]:
        return False
    # Edge pixel = solid pixel with at least one non-solid neighbor within STROKE
    for dy in range(-STROKE, STROKE + 1):
        for dx in range(-STROKE, STROKE + 1):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                if not solid[ny][nx]:
                    return True
            else:
                return True
    return False

out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
op = out.load()
for y in range(h):
    for x in range(w):
        if is_edge(x, y):
            r, g, b, a = src[x, y]
            op[x, y] = (r, g, b, a)

out.save(PATH)
print(f"wrote outlined {PATH}")
