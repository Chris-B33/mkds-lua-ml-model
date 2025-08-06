from PIL import Image

WIDTH, HEIGHT = 256, 192
INPUT_FILE = "mkds-lua-ml-model/data/cur_frame.dat"
OUTPUT_FILE = "frame.png"

def bgr555_to_rgb888(pixel):
    r = (pixel & 0x1F)
    g = (pixel >> 5) & 0x1F
    b = (pixel >> 10) & 0x1F
    r = (r << 3) | (r >> 2)
    g = (g << 3) | (g >> 2)
    b = (b << 3) | (b >> 2)
    return (r, g, b)

with open(INPUT_FILE, "rb") as f:
    raw = f.read()

img = Image.new("RGB", (WIDTH, HEIGHT))
pixels = img.load()

for y in range(HEIGHT):
    for x in range(WIDTH):
        i = (y * WIDTH + x) * 2
        pixel = raw[i] | (raw[i+1] << 8)
        pixels[x, y] = bgr555_to_rgb888(pixel)

img.save(OUTPUT_FILE)
print(f"Saved screenshot as {OUTPUT_FILE}")