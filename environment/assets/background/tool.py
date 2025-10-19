from PIL import Image
import random
import math

# --- Config ---
TILE_SIZE = 150
TARGET_WIDTH = 1920
TARGET_HEIGHT = 1080
SPRITE_FILES = ["sprite1.png", "sprite2.png", "sprite3.png"]
OUTPUT_FILE = "background.png"

# --- Load sprites ---
sprites = [Image.open(f).convert("RGBA") for f in SPRITE_FILES]

# --- Determine grid size ---
cols = math.ceil(TARGET_WIDTH / TILE_SIZE)
rows = math.ceil(TARGET_HEIGHT / TILE_SIZE)

# --- Generate full-tile grid background ---
full_width = cols * TILE_SIZE
full_height = rows * TILE_SIZE
bg = Image.new("RGBA", (full_width, full_height), (0, 0, 0, 0))

for y in range(rows):
    for x in range(cols):
        sprite = random.choice(sprites)
        pos = (x * TILE_SIZE, y * TILE_SIZE)
        bg.paste(sprite, pos, sprite)

# --- Crop to exact 1920x1080 while keeping center ---
left = (full_width - TARGET_WIDTH) // 2
top = (full_height - TARGET_HEIGHT) // 2
right = left + TARGET_WIDTH
bottom = top + TARGET_HEIGHT

bg = bg.crop((left, top, right, bottom))
bg = bg.convert("RGB")  # Remove alpha channel

# --- Save result ---
bg.save(OUTPUT_FILE, "PNG")
print(f"✅ Generated seamless {TARGET_WIDTH}x{TARGET_HEIGHT} background: {OUTPUT_FILE}")
