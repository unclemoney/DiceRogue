"""
Generate dice face textures for values 7-20.
Uses the existing dieWhite_borderBlank.png as a base and draws numerals on top.
Matches the anti-aliased grayscale style of existing pip faces.
"""
from PIL import Image, ImageDraw, ImageFont
import os

ART_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "Resources", "Art", "Dice")
BLANK_PATH = os.path.join(ART_DIR, "dieWhite_borderBlank.png")

# The pip color is a dark gray (~76,76,76) with anti-aliased lighter grays
PIP_COLOR = (76, 76, 76, 255)

# Font - Arial Bold for clean, readable numerals
FONT_PATH = "C:/Windows/Fonts/arialbd.ttf"

# Single digit: size 36 for prominence (fits in 42x42 inner area)
# Double digit: size 30 to fit both chars comfortably
FONT_SIZE_SINGLE = 36
FONT_SIZE_DOUBLE = 30


def generate_face(value: int) -> Image.Image:
    """Generate a die face with the given numeral value."""
    base = Image.open(BLANK_PATH).copy()
    draw = ImageDraw.Draw(base)
    
    text = str(value)
    is_double = value >= 10
    font_size = FONT_SIZE_DOUBLE if is_double else FONT_SIZE_SINGLE
    font = ImageFont.truetype(FONT_PATH, font_size)
    
    # Get text bounding box for centering
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    
    # Center in the die face (68x68 image, content area ~13-54)
    center_x = 34
    center_y = 34
    x = center_x - text_w // 2
    y = center_y - text_h // 2 - bbox[1]  # Adjust for font ascent
    
    # Draw the numeral
    draw.text((x, y), text, fill=PIP_COLOR, font=font)
    
    return base


def main():
    os.makedirs(ART_DIR, exist_ok=True)
    
    for value in range(7, 21):
        face = generate_face(value)
        filename = f"dieWhite_border{value}.png"
        filepath = os.path.join(ART_DIR, filename)
        face.save(filepath)
        print(f"Generated: {filename} ({face.size[0]}x{face.size[1]})")
    
    print(f"\nDone! Generated 14 dice face textures in {ART_DIR}")


if __name__ == "__main__":
    main()
