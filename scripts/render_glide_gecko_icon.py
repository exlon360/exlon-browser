#!/usr/bin/env python3
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ICON_FILES = {
    "AppIcon20x20@1x~ipad.png": 20,
    "AppIcon20x20@2x.png": 40,
    "AppIcon20x20@2x~ipad.png": 40,
    "AppIcon20x20@3x.png": 60,
    "AppIcon29x29@1x~ipad.png": 29,
    "AppIcon29x29@2x.png": 58,
    "AppIcon29x29@2x~ipad.png": 58,
    "AppIcon29x29@3x.png": 87,
    "AppIcon40x40@1x~ipad.png": 40,
    "AppIcon40x40@2x.png": 80,
    "AppIcon40x40@2x~ipad.png": 80,
    "AppIcon40x40@3x.png": 120,
    "AppIcon60x60@2x.png": 120,
    "AppIcon60x60@3x.png": 180,
    "AppIcon76x76@1x~ipad.png": 76,
    "AppIcon76x76@2x~ipad.png": 152,
    "AppIcon83.5x83.5@2x~ipad.png": 167,
}


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Avenir Next Condensed.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    )
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default()


def draw_arc_gradient(
    draw: ImageDraw.ImageDraw,
    bbox: tuple[int, int, int, int],
    start: int,
    end: int,
    width: int,
    color_a: tuple[int, int, int, int],
    color_b: tuple[int, int, int, int],
) -> None:
    steps = max(1, abs(end - start))
    for index in range(steps):
        t = index / max(1, steps - 1)
        color = tuple(
            round(color_a[channel] * (1 - t) + color_b[channel] * t)
            for channel in range(4)
        )
        draw.arc(bbox, start + index, start + index + 1, fill=color, width=width)


def render(source: Path) -> Image.Image:
    base = Image.open(source).convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    center = (758, 746)
    radius = 154
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
        fill=(0, 0, 0, 145),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    base = Image.alpha_composite(base, shadow)

    badge_bounds = (
        center[0] - radius,
        center[1] - radius,
        center[0] + radius,
        center[1] + radius,
    )
    draw.ellipse(badge_bounds, fill=(9, 17, 32, 246), outline=(180, 209, 255, 210), width=8)

    arc_bounds = (
        center[0] - radius + 30,
        center[1] - radius + 30,
        center[0] + radius - 30,
        center[1] + radius - 30,
    )
    draw_arc_gradient(draw, arc_bounds, -42, 160, 32, (255, 169, 69, 255), (255, 226, 94, 255))
    draw_arc_gradient(draw, arc_bounds, 156, 320, 32, (132, 159, 255, 255), (128, 211, 255, 255))

    inner_radius = radius - 94
    draw.ellipse(
        (
            center[0] - inner_radius,
            center[1] - inner_radius,
            center[0] + inner_radius,
            center[1] + inner_radius,
        ),
        fill=(16, 28, 48, 255),
    )

    label_font = font(118)
    label = "G"
    text_bbox = draw.textbbox((0, 0), label, font=label_font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    draw.text(
        (center[0] - text_width / 2, center[1] - text_height / 2 - 12),
        label,
        font=label_font,
        fill=(248, 252, 255, 255),
    )

    highlight = Image.new("RGBA", base.size, (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.arc(
        (170, 540, 898, 850),
        190,
        356,
        fill=(255, 255, 255, 52),
        width=26,
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(3))

    merged = Image.alpha_composite(base, highlight)
    return Image.alpha_composite(merged, overlay)


def save_icon(master: Image.Image, output_dir: Path, preview: Path | None) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for file_name, size in ICON_FILES.items():
        master.resize((size, size), Image.Resampling.LANCZOS).save(output_dir / file_name)
    if preview:
        preview.parent.mkdir(parents=True, exist_ok=True)
        master.save(preview)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()

    save_icon(render(args.source), args.output_dir, args.preview)


if __name__ == "__main__":
    main()
