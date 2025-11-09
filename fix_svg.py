#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复Markdown中的SVG显示问题
将代码块中的SVG转换为直接嵌入的SVG
"""

import re

def fix_svg_display(input_file, output_file):
    """
    修复SVG显示问题
    - 移除 ```svg 和 ``` 标记
    - 让SVG直接嵌入到Markdown中
    """
    print(f"读取文件: {input_file}")
    
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 统计原始SVG代码块数量
    original_count = len(re.findall(r'```svg\s*\n', content))
    print(f"找到 {original_count} 个SVG代码块")
    
    # 移除 ```svg 开始标记
    content = re.sub(r'```svg\s*\n', '\n', content)
    
    # 移除SVG结束后的 ``` 标记（只移除紧跟</svg>后的）
    content = re.sub(r'(</svg>)\s*\n```\s*\n', r'\1\n\n', content)
    
    # 保存修改后的文件
    print(f"保存到: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"完成！已修复 {original_count} 个SVG图表")
    print(f"\n现在可以用Typora打开 {output_file} 查看效果了！")

if __name__ == '__main__':
    input_file = '软著-用户使用手册.md'
    output_file = '软著-用户使用手册-已修复.md'
    
    try:
        fix_svg_display(input_file, output_file)
    except FileNotFoundError:
        print(f"错误：找不到文件 {input_file}")
        print("请确保在正确的目录下运行此脚本")
    except Exception as e:
        print(f"错误：{e}")

