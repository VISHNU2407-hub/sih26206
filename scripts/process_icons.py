#!/usr/bin/env python3
"""
Process SATS app icons: Replace the dark blue circular background
with pure white (#FFFFFF) while preserving the green shield logo.

Strategy:
  1. Identify blue-ish background pixels: Hue 200-300°, Value < 30%, Saturation > 30%
  2. Also identify any dark blue anti-aliased pixels near the shield boundary
  3. Replace those pixels with white (255, 255, 255, 255)
  4. Keep green shield pixels and transparent pixels untouched
"""

from PIL import Image
import colorsys
import os
import sys

def is_dark_blue(r, g, b, a):
    """Check if a pixel is part of the dark blue background."""
    if a < 10:
        return False  # Transparent
    
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    h_deg = h * 360
    s_pct = s * 100
    v_pct = v * 100
    
    # Dark blue/purple: hue 200-300°, low value/brightness, decent saturation
    is_blue_hue = 200 <= h_deg <= 300
    is_dark = v_pct < 30
    is_saturated = s_pct > 20
    
    return is_blue_hue and is_dark and is_saturated


def is_partially_blue_background(r, g, b, a):
    """Check if a semi-transparent pixel is an anti-aliased edge of the blue background."""
    if a < 10:
        return False
    if a > 200:
        return False  # Already handled by is_dark_blue
    
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    h_deg = h * 360
    v_pct = v * 100
    
    # Anti-aliased blue edges: slightly transparent, blue-ish hue, dark
    return 200 <= h_deg <= 300 and v_pct < 40


def process_image(input_path, output_path=None):
    """Process a single icon image, replacing dark blue background with white."""
    if output_path is None:
        output_path = input_path
    
    img = Image.open(input_path)
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    w, h = img.size
    pixels = img.load()
    
    modified_count = 0
    partially_modified = 0
    
    for x in range(w):
        for y in range(h):
            r, g, b, a = pixels[x, y]
            
            if is_dark_blue(r, g, b, a):
                # Replace with white
                pixels[x, y] = (255, 255, 255, 255)
                modified_count += 1
            elif is_partially_blue_background(r, g, b, a):
                # Blend toward white while preserving transparency
                # For anti-aliased pixels: make them white with same alpha
                alpha_frac = a / 255.0
                new_r = int(255 * (1 - alpha_frac) + r * alpha_frac)
                new_g = int(255 * (1 - alpha_frac) + g * alpha_frac)
                new_b = int(255 * (1 - alpha_frac) + b * alpha_frac)
                
                # Actually, for better blending, just make the pixel have a white base
                # with the same alpha. Since it will be on a white background, 
                # this ensures smooth edges.
                pixels[x, y] = (255, 255, 255, a)
                partially_modified += 1
    
    img.save(output_path, 'PNG')
    return modified_count, partially_modified


def main():
    # Root project directory
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    # All icon files to process
    icon_files = [
        # Main asset (used in splash & auth screens)
        os.path.join(root, 'assets', 'images', 'sats_logo.png'),
    ]
    
    # Android mipmap icons
    for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
        icon_files.append(
            os.path.join(root, 'android', 'app', 'src', 'main', 'res',
                        f'mipmap-{density}', 'ic_launcher.png')
        )
    
    # iOS AppIcons
    ios_icons_dir = os.path.join(
        root, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'
    )
    if os.path.isdir(ios_icons_dir):
        for fname in os.listdir(ios_icons_dir):
            if fname.endswith('.png'):
                icon_files.append(os.path.join(ios_icons_dir, fname))
    
    # macOS AppIcons
    macos_icons_dir = os.path.join(
        root, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'
    )
    if os.path.isdir(macos_icons_dir):
        for fname in os.listdir(macos_icons_dir):
            if fname.endswith('.png'):
                icon_files.append(os.path.join(macos_icons_dir, fname))
    
    total_modified = 0
    total_partial = 0
    processed = 0
    
    for icon_path in icon_files:
        if not os.path.isfile(icon_path):
            print(f'SKIP (not found): {os.path.relpath(icon_path, root)}')
            continue
        
        try:
            mod, part = process_image(icon_path)
            total_modified += mod
            total_partial += part
            processed += 1
            rel_path = os.path.relpath(icon_path, root)
            print(f'  OK  {rel_path:60s}  dark_blue={mod:6d}  edge={part:6d}')
        except Exception as e:
            print(f'FAIL {os.path.relpath(icon_path, root):60s}  {e}')
    
    print(f'\nProcessed {processed} icon files')
    print(f'Total background pixels changed to white: {total_modified}')
    print(f'Total edge pixels blended: {total_partial}')

if __name__ == '__main__':
    main()
