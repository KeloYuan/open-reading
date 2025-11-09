#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import os

def extract_and_convert_svg(input_file, output_file):
    print(f"Reading: {input_file}")
    
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Create diagrams directory
    if not os.path.exists('diagrams'):
        os.makedirs('diagrams')
        print("Created diagrams directory")
    
    # Find all SVG
    svg_pattern = r'(<svg[^>]*>.*?</svg>)'
    svgs = re.findall(svg_pattern, content, re.DOTALL)
    
    print(f"Found {len(svgs)} SVG diagrams")
    
    # Save each SVG and replace with image reference
    for i, svg_code in enumerate(svgs, 1):
        # Save SVG file
        svg_filename = f"diagrams/diagram_{i}.svg"
        with open(svg_filename, 'w', encoding='utf-8') as f:
            f.write(svg_code)
        print(f"Saved: {svg_filename}")
        
        # Replace with image tag in Markdown
        img_tag = f'\n![系统设计图{i}](diagrams/diagram_{i}.svg)\n'
        content = content.replace(svg_code, img_tag, 1)
    
    # Save modified Markdown
    print(f"\nSaving to: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\nDone!")
    print(f"   - Extracted {len(svgs)} SVG files to diagrams/")
    print(f"   - Created: {output_file}")

if __name__ == '__main__':
    input_file = '软著-用户使用手册-已修复.md'
    output_file = '软著-用户使用手册-终稿.md'
    
    try:
        extract_and_convert_svg(input_file, output_file)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

