#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从Markdown中提取SVG并保存为独立文件
然后修改Markdown为图片引用
"""

import re
import os

def extract_and_convert_svg(input_file, output_file):
    """
    提取SVG并转换为图片引用
    """
    print(f"读取文件: {input_file}")
    
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 创建diagrams目录
    if not os.path.exists('diagrams'):
        os.makedirs('diagrams')
        print("创建 diagrams 目录")
    
    # 查找所有SVG
    svg_pattern = r'(<svg[^>]*>.*?</svg>)'
    svgs = re.findall(svg_pattern, content, re.DOTALL)
    
    print(f"找到 {len(svgs)} 个SVG图表")
    
    # 为每个SVG创建文件并替换
    for i, svg_code in enumerate(svgs, 1):
        # 保存SVG文件
        svg_filename = f"diagrams/diagram_{i}.svg"
        with open(svg_filename, 'w', encoding='utf-8') as f:
            f.write(svg_code)
        print(f"保存: {svg_filename}")
        
        # 在Markdown中替换为图片引用
        img_tag = f'![系统设计图{i}](./{svg_filename})\n'
        content = content.replace(svg_code, img_tag, 1)
    
    # 保存修改后的Markdown
    print(f"\n保存到: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n✅ 完成!")
    print(f"   - 提取了 {len(svgs)} 个SVG文件到 diagrams/ 目录")
    print(f"   - 创建了新文档: {output_file}")
    print(f"\n现在用Typora打开 {output_file}，SVG会显示为图片！")

if __name__ == '__main__':
    input_file = '软著-用户使用手册-已修复.md'
    output_file = '软著-用户使用手册-终稿.md'
    
    try:
        extract_and_convert_svg(input_file, output_file)
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()

