import 'package:flutter/material.dart';import 'package:flutter/material.dart';import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../models/highlight.dart';import 'package:flutter/services.dart';import 'package:flutter/services.dart';

import '../models/note.dart';

import '../services/highlight_dao.dart';import '../models/highlight.dart';import '../models/highlight.dart';

import '../services/note_dao.dart';

import '../models/note.dart';import '../models/note.dart';

class AnimatedTextSelectionToolbar extends StatefulWidget {

  final String selectedText;import '../models/book.dart';import '../services/highlight_dao.dart';

  final int bookId;

  final int pageNumber;import '../models/chapter.dart';import '../services/note_dao.dart';

  final String chapterTitle;

  final VoidCallback onCopy;import '../services/highlight_dao.dart';

  final VoidCallback onClose;

import '../services/note_dao.dart';class AnimatedTextSelectionToolbar extends StatefulWidget {

  const AnimatedTextSelectionToolbar({

    super.key,  final String selectedText;

    required this.selectedText,

    required this.bookId,class AnimatedTextSelectionToolbar extends StatefulWidget {  final int bookId;

    required this.pageNumber,

    required this.chapterTitle,  final String selectedText;  final int pageNumber;

    required this.onCopy,

    required this.onClose,  final int bookId;  final String chapterTitle;

  });

  final int pageNumber;  final VoidCallback onCancel;

  @override

  State<AnimatedTextSelectionToolbar> createState() => _AnimatedTextSelectionToolbarState();  final String chapterTitle;  final Function(Color) onHighlight;

}

  final VoidCallback onCopy;  final Function(String) onNote;

class _AnimatedTextSelectionToolbarState extends State<AnimatedTextSelectionToolbar>

    with TickerProviderStateMixin {  final VoidCallback onClose;

  late AnimationController _animationController;

  late Animation<double> _scaleAnimation;  const AnimatedTextSelectionToolbar({

  late Animation<double> _opacityAnimation;

    const AnimatedTextSelectionToolbar({    super.key,

  final HighlightDao _highlightDao = HighlightDao();

  final NoteDao _noteDao = NoteDao();    super.key,    required this.selectedText,

  

  bool _showColorPicker = false;    required this.selectedText,    required this.bookId,

  bool _showNoteInput = false;

  Color? _selectedHighlightColor;    required this.bookId,    required this.pageNumber,

  final TextEditingController _noteController = TextEditingController();

    required this.pageNumber,    required this.chapterTitle,

  @override

  void initState() {    required this.chapterTitle,    required this.onCancel,

    super.initState();

    _animationController = AnimationController(    required this.onCopy,    required this.onHighlight,

      duration: const Duration(milliseconds: 300),

      vsync: this,    required this.onClose,    required this.onNote,

    );

      });  });

    _scaleAnimation = Tween<double>(

      begin: 0.0,

      end: 1.0,

    ).animate(CurvedAnimation(  @override  @override

      parent: _animationController,

      curve: Curves.elasticOut,  State<AnimatedTextSelectionToolbar> createState() => _AnimatedTextSelectionToolbarState();  State<AnimatedTextSelectionToolbar> createState() => _AnimatedTextSelectionToolbarState();

    ));

    }}

    _opacityAnimation = Tween<double>(

      begin: 0.0,

      end: 1.0,

    ).animate(CurvedAnimation(class _AnimatedTextSelectionToolbarState extends State<AnimatedTextSelectionToolbar>class _AnimatedTextSelectionToolbarState extends State<AnimatedTextSelectionToolbar>

      parent: _animationController,

      curve: Curves.easeInOut,    with TickerProviderStateMixin {    with TickerProviderStateMixin {

    ));

      late AnimationController _animationController;  late AnimationController _slideController;

    _animationController.forward();

  }  late Animation<double> _scaleAnimation;  late AnimationController _scaleController;



  @override  late Animation<double> _opacityAnimation;  late Animation<Offset> _slideAnimation;

  void dispose() {

    _animationController.dispose();    late Animation<double> _scaleAnimation;

    _noteController.dispose();

    super.dispose();  final HighlightDao _highlightDao = HighlightDao();  

  }

  final NoteDao _noteDao = NoteDao();  bool _showColorPicker = false;

  void _toggleColorPicker() {

    setState(() {    bool _showNoteDialog = false;

      _showColorPicker = !_showColorPicker;

      _showNoteInput = false;  bool _showColorPicker = false;  final HighlightDao _highlightDao = HighlightDao();

    });

  }  bool _showNoteInput = false;  final NoteDao _noteDao = NoteDao();



  void _toggleNoteInput() {  Color? _selectedHighlightColor;

    setState(() {

      _showNoteInput = !_showNoteInput;  final TextEditingController _noteController = TextEditingController();  @override

      _showColorPicker = false;

    });  void initState() {

  }

  @override    super.initState();

  Future<void> _createHighlight(Color color) async {

    try {  void initState() {    

      final highlight = Highlight(

        bookId: widget.bookId,    super.initState();    _slideController = AnimationController(

        content: widget.selectedText,

        pageNumber: widget.pageNumber,    _animationController = AnimationController(      duration: const Duration(milliseconds: 300),

        chapterTitle: widget.chapterTitle,

        color: color.value,      duration: const Duration(milliseconds: 300),      vsync: this,

        createdAt: DateTime.now(),

      );      vsync: this,    );

      

      await _highlightDao.insertHighlight(highlight);    );    

      

      if (mounted) {        _scaleController = AnimationController(

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(    _scaleAnimation = Tween<double>(      duration: const Duration(milliseconds: 200),

            content: const Text('高亮已保存'),

            backgroundColor: color,      begin: 0.0,      vsync: this,

            duration: const Duration(seconds: 2),

          ),      end: 1.0,    );

        );

      }    ).animate(CurvedAnimation(    

      

      _closeWithAnimation();      parent: _animationController,    _slideAnimation = Tween<Offset>(

    } catch (e) {

      if (mounted) {      curve: Curves.elasticOut,      begin: const Offset(0, 1),

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(    ));      end: Offset.zero,

            content: Text('保存高亮失败'),

            backgroundColor: Colors.red,        ).animate(CurvedAnimation(

          ),

        );    _opacityAnimation = Tween<double>(      parent: _slideController,

      }

    }      begin: 0.0,      curve: Curves.easeOutCubic,

  }

      end: 1.0,    ));

  Future<void> _createNote() async {

    if (_noteController.text.trim().isEmpty) {    ).animate(CurvedAnimation(    

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('请输入笔记内容')),      parent: _animationController,    _scaleAnimation = Tween<double>(

      );

      return;      curve: Curves.easeInOut,      begin: 0.0,

    }

    ));      end: 1.0,

    try {

      final note = Note(        ).animate(CurvedAnimation(

        bookId: widget.bookId,

        content: _noteController.text.trim(),    _animationController.forward();      parent: _scaleController,

        pageNumber: widget.pageNumber,

        chapterTitle: widget.chapterTitle,  }      curve: Curves.elasticOut,

        selectedText: widget.selectedText,

        createdAt: DateTime.now(),    ));

      );

        @override    

      await _noteDao.insertNote(note);

        void dispose() {    // 启动入场动画

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(    _animationController.dispose();    _slideController.forward();

          const SnackBar(

            content: Text('笔记已保存'),    _noteController.dispose();    _scaleController.forward();

            backgroundColor: Colors.green,

          ),    super.dispose();  }

        );

      }  }

      

      _closeWithAnimation();  @override

    } catch (e) {

      if (mounted) {  void _toggleColorPicker() {  void dispose() {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(    setState(() {    _slideController.dispose();

            content: Text('保存笔记失败'),

            backgroundColor: Colors.red,      _showColorPicker = !_showColorPicker;    _scaleController.dispose();

          ),

        );      _showNoteInput = false;    super.dispose();

      }

    }    });  }

  }

  }

  void _copyToClipboard() {

    Clipboard.setData(ClipboardData(text: widget.selectedText));  Future<void> _animateExit() async {

    widget.onCopy();

      void _toggleNoteInput() {    await Future.wait([

    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(    setState(() {      _slideController.reverse(),

        content: Text('文本已复制到剪贴板'),

        duration: Duration(seconds: 2),      _showNoteInput = !_showNoteInput;      _scaleController.reverse(),

      ),

    );      _showColorPicker = false;    ]);

    

    _closeWithAnimation();    });  }

  }

  }

  void _closeWithAnimation() {

    _animationController.reverse().then((_) {  Future<void> _handleCopy() async {

      widget.onClose();

    });  Future<void> _createHighlight(Color color) async {    await Clipboard.setData(ClipboardData(text: widget.selectedText));

  }

    try {    if (mounted) {

  @override

  Widget build(BuildContext context) {      final highlight = Highlight(      ScaffoldMessenger.of(context).showSnackBar(

    return AnimatedBuilder(

      animation: _animationController,        bookId: widget.bookId,        SnackBar(

      builder: (context, child) {

        return Transform.scale(        content: widget.selectedText,          content: const Text('已复制到剪贴板'),

          scale: _scaleAnimation.value,

          child: Opacity(        pageNumber: widget.pageNumber,          duration: const Duration(seconds: 2),

            opacity: _opacityAnimation.value,

            child: Material(        chapterTitle: widget.chapterTitle,          behavior: SnackBarBehavior.floating,

              elevation: 8,

              borderRadius: BorderRadius.circular(16),        color: color.value,          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

              color: Theme.of(context).colorScheme.surface,

              child: Container(        createdAt: DateTime.now(),        ),

                padding: const EdgeInsets.all(12),

                constraints: const BoxConstraints(maxWidth: 300),      );      );

                child: Column(

                  mainAxisSize: MainAxisSize.min,          }

                  children: [

                    // 主工具栏      await _highlightDao.insertHighlight(highlight);    await _animateExit();

                    Row(

                      mainAxisSize: MainAxisSize.min,          widget.onCancel();

                      children: [

                        _buildToolbarButton(      if (mounted) {  }

                          icon: Icons.highlight_alt,

                          label: '高亮',        ScaffoldMessenger.of(context).showSnackBar(

                          onTap: _toggleColorPicker,

                          isActive: _showColorPicker,          SnackBar(  Future<void> _handleHighlight(Color color) async {

                        ),

                        const SizedBox(width: 8),            content: const Text('高亮已保存'),    try {

                        _buildToolbarButton(

                          icon: Icons.note_add,            backgroundColor: color,      final highlight = Highlight(

                          label: '笔记',

                          onTap: _toggleNoteInput,            duration: const Duration(seconds: 2),        bookId: widget.bookId,

                          isActive: _showNoteInput,

                        ),          ),        pageNumber: widget.pageNumber,

                        const SizedBox(width: 8),

                        _buildToolbarButton(        );        selectedText: widget.selectedText,

                          icon: Icons.copy,

                          label: '复制',      }        startOffset: 0, // TODO: 从实际选择获取

                          onTap: _copyToClipboard,

                        ),              endOffset: widget.selectedText.length,

                        const SizedBox(width: 8),

                        _buildToolbarButton(      _closeWithAnimation();        color: color,

                          icon: Icons.close,

                          label: '关闭',    } catch (e) {      );

                          onTap: _closeWithAnimation,

                        ),      if (mounted) {      

                      ],

                    ),        ScaffoldMessenger.of(context).showSnackBar(      await _highlightDao.insertHighlight(highlight);

                    

                    // 颜色选择器          const SnackBar(      widget.onHighlight(color);

                    if (_showColorPicker) ...[

                      const SizedBox(height: 12),            content: Text('保存高亮失败'),      

                      _buildColorPicker(),

                    ],            backgroundColor: Colors.red,      if (mounted) {

                    

                    // 笔记输入          ),        ScaffoldMessenger.of(context).showSnackBar(

                    if (_showNoteInput) ...[

                      const SizedBox(height: 12),        );          SnackBar(

                      _buildNoteInput(),

                    ],      }            content: const Text('高亮已保存'),

                  ],

                ),    }            duration: const Duration(seconds: 2),

              ),

            ),  }            behavior: SnackBarBehavior.floating,

          ),

        );            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      },

    );  Future<void> _createNote() async {          ),

  }

    if (_noteController.text.trim().isEmpty) {        );

  Widget _buildToolbarButton({

    required IconData icon,      ScaffoldMessenger.of(context).showSnackBar(      }

    required String label,

    required VoidCallback onTap,        const SnackBar(content: Text('请输入笔记内容')),    } catch (e) {

    bool isActive = false,

  }) {      );      if (mounted) {

    return GestureDetector(

      onTap: onTap,      return;        ScaffoldMessenger.of(context).showSnackBar(

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 200),    }          SnackBar(

        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),

        decoration: BoxDecoration(            content: Text('保存高亮失败: $e'),

          color: isActive

              ? Theme.of(context).colorScheme.primaryContainer    try {            duration: const Duration(seconds: 2),

              : Colors.transparent,

          borderRadius: BorderRadius.circular(8),      final note = Note(            behavior: SnackBarBehavior.floating,

          border: isActive

              ? Border.all(        bookId: widget.bookId,            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                  color: Theme.of(context).colorScheme.primary,

                  width: 1,        content: _noteController.text.trim(),          ),

                )

              : null,        pageNumber: widget.pageNumber,        );

        ),

        child: Column(        chapterTitle: widget.chapterTitle,      }

          mainAxisSize: MainAxisSize.min,

          children: [        selectedText: widget.selectedText,    }

            Icon(

              icon,        createdAt: DateTime.now(),    

              size: 20,

              color: isActive      );    await _animateExit();

                  ? Theme.of(context).colorScheme.primary

                  : Theme.of(context).colorScheme.onSurface,          widget.onCancel();

            ),

            const SizedBox(height: 4),      await _noteDao.insertNote(note);  }

            Text(

              label,      

              style: Theme.of(context).textTheme.bodySmall?.copyWith(

                    color: isActive      if (mounted) {  Future<void> _handleNote(String noteText) async {

                        ? Theme.of(context).colorScheme.primary

                        : Theme.of(context).colorScheme.onSurface,        ScaffoldMessenger.of(context).showSnackBar(    try {

                  ),

            ),          const SnackBar(      final note = Note(

          ],

        ),            content: Text('笔记已保存'),        bookId: widget.bookId,

      ),

    );            backgroundColor: Colors.green,        pageNumber: widget.pageNumber,

  }

          ),        selectedText: widget.selectedText,

  Widget _buildColorPicker() {

    return Container(        );        noteText: noteText,

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(      }      );

        color: Theme.of(context).colorScheme.surfaceVariant,

        borderRadius: BorderRadius.circular(12),            

      ),

      child: Column(      _closeWithAnimation();      await _noteDao.insertNote(note);

        mainAxisSize: MainAxisSize.min,

        children: [    } catch (e) {      widget.onNote(noteText);

          Text(

            '选择高亮颜色',      if (mounted) {      

            style: Theme.of(context).textTheme.titleSmall,

          ),        ScaffoldMessenger.of(context).showSnackBar(      if (mounted) {

          const SizedBox(height: 8),

          Wrap(          const SnackBar(        ScaffoldMessenger.of(context).showSnackBar(

            spacing: 8,

            runSpacing: 8,            content: Text('保存笔记失败'),          SnackBar(

            children: Highlight.highlightColors.map((color) {

              final isSelected = _selectedHighlightColor == color;            backgroundColor: Colors.red,            content: const Text('笔记已保存'),

              return GestureDetector(

                onTap: () => _createHighlight(color),          ),            duration: const Duration(seconds: 2),

                child: AnimatedContainer(

                  duration: const Duration(milliseconds: 200),        );            behavior: SnackBarBehavior.floating,

                  width: 32,

                  height: 32,      }            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                  decoration: BoxDecoration(

                    color: color,    }          ),

                    shape: BoxShape.circle,

                    border: Border.all(  }        );

                      color: isSelected

                          ? Theme.of(context).colorScheme.outline      }

                          : Colors.transparent,

                      width: 2,  void _copyToClipboard() {    } catch (e) {

                    ),

                  ),    Clipboard.setData(ClipboardData(text: widget.selectedText));      if (mounted) {

                  child: isSelected

                      ? Icon(    widget.onCopy();        ScaffoldMessenger.of(context).showSnackBar(

                          Icons.check,

                          color: _getContrastColor(color),              SnackBar(

                          size: 16,

                        )    ScaffoldMessenger.of(context).showSnackBar(            content: Text('保存笔记失败: $e'),

                      : null,

                ),      const SnackBar(            duration: const Duration(seconds: 2),

              );

            }).toList(),        content: Text('文本已复制到剪贴板'),            behavior: SnackBarBehavior.floating,

          ),

        ],        duration: Duration(seconds: 2),            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      ),

    );      ),          ),

  }

    );        );

  Widget _buildNoteInput() {

    return Container(          }

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(    _closeWithAnimation();    }

        color: Theme.of(context).colorScheme.surfaceVariant,

        borderRadius: BorderRadius.circular(12),  }    

      ),

      child: Column(    await _animateExit();

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,  void _closeWithAnimation() {    widget.onCancel();

        children: [

          Text(    _animationController.reverse().then((_) {  }

            '添加笔记',

            style: Theme.of(context).textTheme.titleSmall,      widget.onClose();

          ),

          const SizedBox(height: 8),    });  @override

          Container(

            padding: const EdgeInsets.all(8),  }  Widget build(BuildContext context) {

            decoration: BoxDecoration(

              color: Theme.of(context).colorScheme.surface,    return SlideTransition(

              borderRadius: BorderRadius.circular(8),

              border: Border.all(  @override      position: _slideAnimation,

                color: Theme.of(context).colorScheme.outline,

              ),  Widget build(BuildContext context) {      child: ScaleTransition(

            ),

            child: Text(    return AnimatedBuilder(        scale: _scaleAnimation,

              '"${widget.selectedText}"',

              style: Theme.of(context).textTheme.bodySmall?.copyWith(      animation: _animationController,        child: Material(

                    fontStyle: FontStyle.italic,

                    color: Theme.of(context).colorScheme.onSurfaceVariant,      builder: (context, child) {          elevation: 12,

                  ),

              maxLines: 2,        return Transform.scale(          borderRadius: BorderRadius.circular(16),

              overflow: TextOverflow.ellipsis,

            ),          scale: _scaleAnimation.value,          color: Theme.of(context).colorScheme.surface,

          ),

          const SizedBox(height: 8),          child: Opacity(          shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.3),

          TextField(

            controller: _noteController,            opacity: _opacityAnimation.value,          child: Container(

            decoration: InputDecoration(

              hintText: '在此输入您的笔记...',            child: Material(            padding: const EdgeInsets.all(16),

              border: OutlineInputBorder(

                borderRadius: BorderRadius.circular(8),              elevation: 8,            child: Column(

              ),

              contentPadding: const EdgeInsets.all(12),              borderRadius: BorderRadius.circular(16),              mainAxisSize: MainAxisSize.min,

            ),

            maxLines: 3,              color: Theme.of(context).colorScheme.surface,              children: [

            minLines: 2,

          ),              child: Container(                // 选中的文本预览

          const SizedBox(height: 12),

          Row(                padding: const EdgeInsets.all(12),                Container(

            mainAxisAlignment: MainAxisAlignment.end,

            children: [                constraints: const BoxConstraints(maxWidth: 300),                  constraints: const BoxConstraints(maxWidth: 280, maxHeight: 80),

              TextButton(

                onPressed: () {                child: Column(                  padding: const EdgeInsets.all(12),

                  setState(() {

                    _showNoteInput = false;                  mainAxisSize: MainAxisSize.min,                  margin: const EdgeInsets.only(bottom: 16),

                  });

                },                  children: [                  decoration: BoxDecoration(

                child: const Text('取消'),

              ),                    // 主工具栏                    color: Theme.of(context).colorScheme.surfaceContainerHighest,

              const SizedBox(width: 8),

              ElevatedButton(                    Row(                    borderRadius: BorderRadius.circular(12),

                onPressed: _createNote,

                child: const Text('保存'),                      mainAxisSize: MainAxisSize.min,                    border: Border.all(

              ),

            ],                      children: [                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),

          ),

        ],                        _AnimatedToolbarButton(                    ),

      ),

    );                          icon: Icons.highlight_alt,                  ),

  }

                          label: '高亮',                  child: Text(

  Color _getContrastColor(Color color) {

    final luminance = color.computeLuminance();                          onTap: _toggleColorPicker,                    widget.selectedText.length > 60 

    return luminance > 0.5 ? Colors.black : Colors.white;

  }                          isActive: _showColorPicker,                        ? '${widget.selectedText.substring(0, 60)}...'

}
                        ),                        : widget.selectedText,

                        const SizedBox(width: 8),                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                        _AnimatedToolbarButton(                      height: 1.4,

                          icon: Icons.note_add,                    ),

                          label: '笔记',                    maxLines: 3,

                          onTap: _toggleNoteInput,                    overflow: TextOverflow.ellipsis,

                          isActive: _showNoteInput,                  ),

                        ),                ),

                        const SizedBox(width: 8),                

                        _AnimatedToolbarButton(                if (!_showColorPicker && !_showNoteDialog) ...[

                          icon: Icons.copy,                  // 主操作按钮

                          label: '复制',                  Row(

                          onTap: _copyToClipboard,                    mainAxisSize: MainAxisSize.min,

                        ),                    children: [

                        const SizedBox(width: 8),                      _AnimatedToolbarButton(

                        _AnimatedToolbarButton(                        icon: Icons.highlight_outlined,

                          icon: Icons.close,                        label: '高亮',

                          label: '关闭',                        color: Colors.amber,

                          onTap: _closeWithAnimation,                        onTap: () => setState(() => _showColorPicker = true),

                        ),                        delay: 0,

                      ],                      ),

                    ),                      const SizedBox(width: 12),

                                          _AnimatedToolbarButton(

                    // 颜色选择器                        icon: Icons.note_add_outlined,

                    AnimatedContainer(                        label: '笔记',

                      duration: const Duration(milliseconds: 300),                        color: Colors.blue,

                      height: _showColorPicker ? null : 0,                        onTap: () => setState(() => _showNoteDialog = true),

                      child: _showColorPicker                        delay: 100,

                          ? AnimatedHighlightColorPicker(                      ),

                              selectedColor: _selectedHighlightColor,                      const SizedBox(width: 12),

                              onColorSelected: (color) {                      _AnimatedToolbarButton(

                                setState(() {                        icon: Icons.copy_outlined,

                                  _selectedHighlightColor = color;                        label: '复制',

                                });                        color: Colors.green,

                                _createHighlight(color);                        onTap: _handleCopy,

                              },                        delay: 200,

                            )                      ),

                          : null,                      const SizedBox(width: 12),

                    ),                      _AnimatedToolbarButton(

                                            icon: Icons.close_outlined,

                    // 笔记输入                        label: '取消',

                    AnimatedContainer(                        color: Colors.red,

                      duration: const Duration(milliseconds: 300),                        onTap: () async {

                      height: _showNoteInput ? null : 0,                          await _animateExit();

                      child: _showNoteInput                          widget.onCancel();

                          ? AnimatedNoteInput(                        },

                              controller: _noteController,                        delay: 300,

                              selectedText: widget.selectedText,                      ),

                              onSave: _createNote,                    ],

                              onCancel: () {                  ),

                                setState(() {                ],

                                  _showNoteInput = false;                

                                });                if (_showColorPicker) ...[

                              },                  AnimatedHighlightColorPicker(

                            )                    onColorSelected: _handleHighlight,

                          : null,                    onCancel: () => setState(() => _showColorPicker = false),

                    ),                  ),

                  ],                ],

                ),                

              ),                if (_showNoteDialog) ...[

            ),                  AnimatedNoteInput(

          ),                    onNoteSubmitted: _handleNote,

        );                    onCancel: () => setState(() => _showNoteDialog = false),

      },                  ),

    );                ],

  }              ],

}            ),

          ),

class _AnimatedToolbarButton extends StatefulWidget {        ),

  final IconData icon;      ),

  final String label;    );

  final VoidCallback onTap;  }

  final bool isActive;}



  const _AnimatedToolbarButton({class _AnimatedToolbarButton extends StatefulWidget {

    required this.icon,  final IconData icon;

    required this.label,  final String label;

    required this.onTap,  final Color color;

    this.isActive = false,  final VoidCallback onTap;

  });  final int delay;



  @override  const _AnimatedToolbarButton({

  State<_AnimatedToolbarButton> createState() => _AnimatedToolbarButtonState();    required this.icon,

}    required this.label,

    required this.color,

class _AnimatedToolbarButtonState extends State<_AnimatedToolbarButton>    required this.onTap,

    with SingleTickerProviderStateMixin {    this.delay = 0,

  late AnimationController _controller;  });

  late Animation<double> _scaleAnimation;

  bool _isPressed = false;  @override

  State<_AnimatedToolbarButton> createState() => _AnimatedToolbarButtonState();

  @override}

  void initState() {

    super.initState();class _AnimatedToolbarButtonState extends State<_AnimatedToolbarButton>

    _controller = AnimationController(    with SingleTickerProviderStateMixin {

      duration: const Duration(milliseconds: 150),  late AnimationController _controller;

      vsync: this,  late Animation<double> _scaleAnimation;

    );  late Animation<double> _opacityAnimation;

    _scaleAnimation = Tween<double>(

      begin: 1.0,  @override

      end: 0.95,  void initState() {

    ).animate(CurvedAnimation(    super.initState();

      parent: _controller,    _controller = AnimationController(

      curve: Curves.easeInOut,      duration: const Duration(milliseconds: 400),

    ));      vsync: this,

  }    );

    

  @override    _scaleAnimation = Tween<double>(

  void dispose() {      begin: 0.0,

    _controller.dispose();      end: 1.0,

    super.dispose();    ).animate(CurvedAnimation(

  }      parent: _controller,

      curve: Curves.elasticOut,

  void _onTapDown(TapDownDetails details) {    ));

    setState(() {    

      _isPressed = true;    _opacityAnimation = Tween<double>(

    });      begin: 0.0,

    _controller.forward();      end: 1.0,

  }    ).animate(CurvedAnimation(

      parent: _controller,

  void _onTapUp(TapUpDetails details) {      curve: Curves.easeOut,

    setState(() {    ));

      _isPressed = false;    

    });    // 延迟启动动画

    _controller.reverse();    Future.delayed(Duration(milliseconds: widget.delay), () {

    widget.onTap();      if (mounted) {

  }        _controller.forward();

      }

  void _onTapCancel() {    });

    setState(() {  }

      _isPressed = false;

    });  @override

    _controller.reverse();  void dispose() {

  }    _controller.dispose();

    super.dispose();

  @override  }

  Widget build(BuildContext context) {

    return AnimatedBuilder(  @override

      animation: _scaleAnimation,  Widget build(BuildContext context) {

      builder: (context, child) {    return AnimatedBuilder(

        return Transform.scale(      animation: _controller,

          scale: _scaleAnimation.value,      builder: (context, child) {

          child: GestureDetector(        return Transform.scale(

            onTapDown: _onTapDown,          scale: _scaleAnimation.value,

            onTapUp: _onTapUp,          child: Opacity(

            onTapCancel: _onTapCancel,            opacity: _opacityAnimation.value,

            child: AnimatedContainer(            child: Material(

              duration: const Duration(milliseconds: 200),              color: Colors.transparent,

              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),              child: InkWell(

              decoration: BoxDecoration(                onTap: widget.onTap,

                color: widget.isActive                borderRadius: BorderRadius.circular(12),

                    ? Theme.of(context).colorScheme.primaryContainer                child: Container(

                    : _isPressed                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),

                        ? Theme.of(context).colorScheme.surfaceVariant                  decoration: BoxDecoration(

                        : Colors.transparent,                    color: widget.color.withOpacity(0.1),

                borderRadius: BorderRadius.circular(8),                    borderRadius: BorderRadius.circular(12),

                border: widget.isActive                    border: Border.all(

                    ? Border.all(                      color: widget.color.withOpacity(0.3),

                        color: Theme.of(context).colorScheme.primary,                    ),

                        width: 1,                  ),

                      )                  child: Column(

                    : null,                    mainAxisSize: MainAxisSize.min,

              ),                    children: [

              child: Column(                      Icon(

                mainAxisSize: MainAxisSize.min,                        widget.icon,

                children: [                        size: 24,

                  Icon(                        color: widget.color,

                    widget.icon,                      ),

                    size: 20,                      const SizedBox(height: 6),

                    color: widget.isActive                      Text(

                        ? Theme.of(context).colorScheme.primary                        widget.label,

                        : Theme.of(context).colorScheme.onSurface,                        style: Theme.of(context).textTheme.labelSmall?.copyWith(

                  ),                          color: widget.color,

                  const SizedBox(height: 4),                          fontWeight: FontWeight.w600,

                  Text(                        ),

                    widget.label,                      ),

                    style: Theme.of(context).textTheme.bodySmall?.copyWith(                    ],

                          color: widget.isActive                  ),

                              ? Theme.of(context).colorScheme.primary                ),

                              : Theme.of(context).colorScheme.onSurface,              ),

                        ),            ),

                  ),          ),

                ],        );

              ),      },

            ),    );

          ),  }

        );}

      },

    );class AnimatedHighlightColorPicker extends StatefulWidget {

  }  final Function(Color) onColorSelected;

}  final VoidCallback onCancel;



class AnimatedHighlightColorPicker extends StatefulWidget {  const AnimatedHighlightColorPicker({

  final Color? selectedColor;    super.key,

  final Function(Color) onColorSelected;    required this.onColorSelected,

    required this.onCancel,

  const AnimatedHighlightColorPicker({  });

    super.key,

    this.selectedColor,  @override

    required this.onColorSelected,  State<AnimatedHighlightColorPicker> createState() => _AnimatedHighlightColorPickerState();

  });}



  @overrideclass _AnimatedHighlightColorPickerState extends State<AnimatedHighlightColorPicker>

  State<AnimatedHighlightColorPicker> createState() => _AnimatedHighlightColorPickerState();    with TickerProviderStateMixin {

}  late AnimationController _slideController;

  late Animation<Offset> _slideAnimation;

class _AnimatedHighlightColorPickerState extends State<AnimatedHighlightColorPicker>  Color? _selectedColor;

    with SingleTickerProviderStateMixin {

  late AnimationController _controller;  @override

  late Animation<double> _slideAnimation;  void initState() {

    super.initState();

  @override    _slideController = AnimationController(

  void initState() {      duration: const Duration(milliseconds: 300),

    super.initState();      vsync: this,

    _controller = AnimationController(    );

      duration: const Duration(milliseconds: 300),    

      vsync: this,    _slideAnimation = Tween<Offset>(

    );      begin: const Offset(0, 1),

    _slideAnimation = Tween<double>(      end: Offset.zero,

      begin: 0.0,    ).animate(CurvedAnimation(

      end: 1.0,      parent: _slideController,

    ).animate(CurvedAnimation(      curve: Curves.easeOutCubic,

      parent: _controller,    ));

      curve: Curves.easeOut,    

    ));    _slideController.forward();

    _controller.forward();  }

  }

  @override

  @override  void dispose() {

  void dispose() {    _slideController.dispose();

    _controller.dispose();    super.dispose();

    super.dispose();  }

  }

  @override

  @override  Widget build(BuildContext context) {

  Widget build(BuildContext context) {    return SlideTransition(

    return AnimatedBuilder(      position: _slideAnimation,

      animation: _slideAnimation,      child: Column(

      builder: (context, child) {        mainAxisSize: MainAxisSize.min,

        return Transform.translate(        children: [

          offset: Offset(0, 20 * (1 - _slideAnimation.value)),          Text(

          child: Opacity(            '选择高亮颜色',

            opacity: _slideAnimation.value,            style: Theme.of(context).textTheme.titleSmall?.copyWith(

            child: Container(              fontWeight: FontWeight.w600,

              margin: const EdgeInsets.only(top: 12),            ),

              padding: const EdgeInsets.all(12),          ),

              decoration: BoxDecoration(          const SizedBox(height: 16),

                color: Theme.of(context).colorScheme.surfaceVariant,          Wrap(

                borderRadius: BorderRadius.circular(12),            spacing: 12,

              ),            runSpacing: 12,

              child: Column(            children: Highlight.highlightColors.asMap().entries.map((entry) {

                mainAxisSize: MainAxisSize.min,              final index = entry.key;

                children: [              final color = entry.value;

                  Text(              

                    '选择高亮颜色',              return GestureDetector(

                    style: Theme.of(context).textTheme.titleSmall,                onTap: () {

                  ),                  setState(() => _selectedColor = color);

                  const SizedBox(height: 8),                  widget.onColorSelected(color);

                  Wrap(                },

                    spacing: 8,                child: AnimatedContainer(

                    runSpacing: 8,                  duration: Duration(milliseconds: 200 + index * 50),

                    children: Highlight.highlightColors.map((color) {                  curve: Curves.elasticOut,

                      final isSelected = widget.selectedColor == color;                  width: 48,

                      return GestureDetector(                  height: 48,

                        onTap: () => widget.onColorSelected(color),                  decoration: BoxDecoration(

                        child: AnimatedContainer(                    color: color,

                          duration: const Duration(milliseconds: 200),                    shape: BoxShape.circle,

                          width: 32,                    border: Border.all(

                          height: 32,                      color: _selectedColor == color

                          decoration: BoxDecoration(                          ? Theme.of(context).colorScheme.primary

                            color: color,                          : Colors.grey.shade300,

                            shape: BoxShape.circle,                      width: _selectedColor == color ? 3 : 1,

                            border: Border.all(                    ),

                              color: isSelected                    boxShadow: [

                                  ? Theme.of(context).colorScheme.outline                      BoxShadow(

                                  : Colors.transparent,                        color: color.withOpacity(0.4),

                              width: 2,                        blurRadius: _selectedColor == color ? 8 : 4,

                            ),                        spreadRadius: _selectedColor == color ? 1 : 0,

                            boxShadow: isSelected                      ),

                                ? [                    ],

                                    BoxShadow(                  ),

                                      color: color.withOpacity(0.5),                  child: _selectedColor == color

                                      blurRadius: 8,                      ? Icon(

                                      offset: const Offset(0, 2),                          Icons.check,

                                    ),                          color: _getContrastColor(color),

                                  ]                          size: 24,

                                : null,                        )

                          ),                      : null,

                          child: isSelected                ),

                              ? Icon(              );

                                  Icons.check,            }).toList(),

                                  color: _getContrastColor(color),          ),

                                  size: 16,          const SizedBox(height: 16),

                                )          TextButton(

                              : null,            onPressed: widget.onCancel,

                        ),            child: const Text('取消'),

                      );          ),

                    }).toList(),        ],

                  ),      ),

                ],    );

              ),  }

            ),

          ),  Color _getContrastColor(Color color) {

        );    // 计算对比色（黑色或白色）

      },    final luminance = color.computeLuminance();

    );    return luminance > 0.5 ? Colors.black : Colors.white;

  }  }

}

  Color _getContrastColor(Color color) {

    // 计算对比色以确保图标可见class AnimatedNoteInput extends StatefulWidget {

    final luminance = color.computeLuminance();  final Function(String) onNoteSubmitted;

    return luminance > 0.5 ? Colors.black : Colors.white;  final VoidCallback onCancel;

  }

}  const AnimatedNoteInput({

    super.key,

class AnimatedNoteInput extends StatefulWidget {    required this.onNoteSubmitted,

  final TextEditingController controller;    required this.onCancel,

  final String selectedText;  });

  final VoidCallback onSave;

  final VoidCallback onCancel;  @override

  State<AnimatedNoteInput> createState() => _AnimatedNoteInputState();

  const AnimatedNoteInput({}

    super.key,

    required this.controller,class _AnimatedNoteInputState extends State<AnimatedNoteInput>

    required this.selectedText,    with TickerProviderStateMixin {

    required this.onSave,  late AnimationController _slideController;

    required this.onCancel,  late Animation<Offset> _slideAnimation;

  });  final TextEditingController _noteController = TextEditingController();

  final FocusNode _focusNode = FocusNode();

  @override

  State<AnimatedNoteInput> createState() => _AnimatedNoteInputState();  @override

}  void initState() {

    super.initState();

class _AnimatedNoteInputState extends State<AnimatedNoteInput>    _slideController = AnimationController(

    with SingleTickerProviderStateMixin {      duration: const Duration(milliseconds: 300),

  late AnimationController _controller;      vsync: this,

  late Animation<double> _slideAnimation;    );

    

  @override    _slideAnimation = Tween<Offset>(

  void initState() {      begin: const Offset(0, 1),

    super.initState();      end: Offset.zero,

    _controller = AnimationController(    ).animate(CurvedAnimation(

      duration: const Duration(milliseconds: 300),      parent: _slideController,

      vsync: this,      curve: Curves.easeOutCubic,

    );    ));

    _slideAnimation = Tween<double>(    

      begin: 0.0,    _slideController.forward();

      end: 1.0,    

    ).animate(CurvedAnimation(    // 自动聚焦到输入框

      parent: _controller,    Future.delayed(const Duration(milliseconds: 300), () {

      curve: Curves.easeOut,      _focusNode.requestFocus();

    ));    });

    _controller.forward();  }

  }

  @override

  @override  void dispose() {

  void dispose() {    _slideController.dispose();

    _controller.dispose();    _noteController.dispose();

    super.dispose();    _focusNode.dispose();

  }    super.dispose();

  }

  @override

  Widget build(BuildContext context) {  void _submitNote() {

    return AnimatedBuilder(    final noteText = _noteController.text.trim();

      animation: _slideAnimation,    if (noteText.isNotEmpty) {

      builder: (context, child) {      widget.onNoteSubmitted(noteText);

        return Transform.translate(    } else {

          offset: Offset(0, 20 * (1 - _slideAnimation.value)),      widget.onCancel();

          child: Opacity(    }

            opacity: _slideAnimation.value,  }

            child: Container(

              margin: const EdgeInsets.only(top: 12),  @override

              padding: const EdgeInsets.all(12),  Widget build(BuildContext context) {

              decoration: BoxDecoration(    return SlideTransition(

                color: Theme.of(context).colorScheme.surfaceVariant,      position: _slideAnimation,

                borderRadius: BorderRadius.circular(12),      child: Column(

              ),        mainAxisSize: MainAxisSize.min,

              child: Column(        crossAxisAlignment: CrossAxisAlignment.start,

                mainAxisSize: MainAxisSize.min,        children: [

                crossAxisAlignment: CrossAxisAlignment.start,          Text(

                children: [            '添加笔记',

                  Text(            style: Theme.of(context).textTheme.titleSmall?.copyWith(

                    '添加笔记',              fontWeight: FontWeight.w600,

                    style: Theme.of(context).textTheme.titleSmall,            ),

                  ),          ),

                  const SizedBox(height: 8),          const SizedBox(height: 12),

                  Container(          Container(

                    padding: const EdgeInsets.all(8),            padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(            decoration: BoxDecoration(

                      color: Theme.of(context).colorScheme.surface,              color: Theme.of(context).colorScheme.surfaceContainerHighest,

                      borderRadius: BorderRadius.circular(8),              borderRadius: BorderRadius.circular(12),

                      border: Border.all(              border: Border.all(

                        color: Theme.of(context).colorScheme.outline,                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),

                      ),              ),

                    ),            ),

                    child: Text(            child: TextField(

                      '"${widget.selectedText}"',              controller: _noteController,

                      style: Theme.of(context).textTheme.bodySmall?.copyWith(              focusNode: _focusNode,

                            fontStyle: FontStyle.italic,              maxLines: 3,

                            color: Theme.of(context).colorScheme.onSurfaceVariant,              decoration: const InputDecoration(

                          ),                hintText: '输入你的笔记...',

                      maxLines: 2,                border: InputBorder.none,

                      overflow: TextOverflow.ellipsis,                isDense: true,

                    ),              ),

                  ),              style: Theme.of(context).textTheme.bodyMedium,

                  const SizedBox(height: 8),              onSubmitted: (_) => _submitNote(),

                  TextField(            ),

                    controller: widget.controller,          ),

                    decoration: InputDecoration(          const SizedBox(height: 12),

                      hintText: '在此输入您的笔记...',          Row(

                      border: OutlineInputBorder(            mainAxisAlignment: MainAxisAlignment.end,

                        borderRadius: BorderRadius.circular(8),            children: [

                      ),              TextButton(

                      contentPadding: const EdgeInsets.all(12),                onPressed: widget.onCancel,

                    ),                child: const Text('取消'),

                    maxLines: 3,              ),

                    minLines: 2,              const SizedBox(width: 8),

                  ),              FilledButton(

                  const SizedBox(height: 12),                onPressed: _submitNote,

                  Row(                child: const Text('保存'),

                    mainAxisAlignment: MainAxisAlignment.end,              ),

                    children: [            ],

                      TextButton(          ),

                        onPressed: widget.onCancel,        ],

                        child: const Text('取消'),      ),

                      ),    );

                      const SizedBox(width: 8),  }

                      ElevatedButton(}

                        onPressed: widget.onSave,

                        child: const Text('保存'),// 保留原有的组件以保持兼容性

                      ),class TextSelectionToolbar extends StatelessWidget {

                    ],  final String selectedText;

                  ),  final VoidCallback onHighlight;

                ],  final VoidCallback onNote;

              ),  final VoidCallback onCopy;

            ),  final VoidCallback onCancel;

          ),  final List<Color> highlightColors;

        );

      },  const TextSelectionToolbar({

    );    super.key,

  }    required this.selectedText,

}    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
    required this.onCancel,
    this.highlightColors = Highlight.highlightColors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选中的文本预览
            Container(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 60),
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selectedText.length > 50 
                    ? '${selectedText.substring(0, 50)}...'
                    : selectedText,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolbarButton(
                  icon: Icons.highlight_outlined,
                  label: '高亮',
                  onTap: onHighlight,
                ),
                const SizedBox(width: 8),
                _ToolbarButton(
                  icon: Icons.note_add_outlined,
                  label: '笔记',
                  onTap: onNote,
                ),
                const SizedBox(width: 8),
                _ToolbarButton(
                  icon: Icons.copy_outlined,
                  label: '复制',
                  onTap: onCopy,
                ),
                const SizedBox(width: 8),
                _ToolbarButton(
                  icon: Icons.close_outlined,
                  label: '取消',
                  onTap: onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class HighlightColorPicker extends StatelessWidget {
  final List<Color> colors;
  final Color? selectedColor;
  final Function(Color) onColorSelected;

  const HighlightColorPicker({
    super.key,
    this.colors = Highlight.highlightColors,
    this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择高亮颜色',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((color) => GestureDetector(
                onTap: () => onColorSelected(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selectedColor == color
                        ? Border.all(color: Colors.black, width: 2)
                        : Border.all(color: Colors.grey.shade300),
                  ),
                  child: selectedColor == color
                      ? const Icon(Icons.check, color: Colors.black, size: 20)
                      : null,
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}