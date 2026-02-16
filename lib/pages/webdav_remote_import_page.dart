import 'package:flutter/material.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/sync/webdav_sync_service.dart';
import 'package:xxread/widgets/side_toast.dart';

class WebDavRemoteImportPage extends StatefulWidget {
  const WebDavRemoteImportPage({super.key});

  @override
  State<WebDavRemoteImportPage> createState() => _WebDavRemoteImportPageState();
}

class _WebDavRemoteImportPageState extends State<WebDavRemoteImportPage> {
  final _service = WebDavSyncService();

  List<Book> _remoteBooks = const <Book>[];
  final Set<String> _selectedKeys = <String>{};
  bool _isLoading = true;
  bool _isImporting = false;
  String _error = '';
  String _progress = '';

  @override
  void initState() {
    super.initState();
    _loadRemoteBooks();
  }

  String _keyOf(Book book) {
    return '${book.id ?? ''}|${book.filePath}|${book.title}|${book.author}|${book.importDate.millisecondsSinceEpoch}';
  }

  Future<void> _loadRemoteBooks() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final books = await _service.listRemoteBooksForImport();
      if (!mounted) return;
      setState(() {
        _remoteBooks = books;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importSelected() async {
    if (_selectedKeys.isEmpty) {
      showSideToast(context, '请先选择要导入的书籍');
      return;
    }
    if (_isImporting) {
      return;
    }

    setState(() {
      _isImporting = true;
      _progress = '准备导入...';
    });

    int imported = 0;
    try {
      final selected = _remoteBooks
          .where((book) => _selectedKeys.contains(_keyOf(book)))
          .toList();
      for (int i = 0; i < selected.length; i++) {
        if (!mounted) return;
        setState(() {
          _progress = '导入 ${i + 1}/${selected.length}: ${selected[i].title}';
        });
        final inserted = await _service.importRemoteBook(selected[i]);
        if (inserted != null) {
          imported++;
        }
      }

      if (!mounted) return;
      LibraryEventBus().notifyLibraryChanged();
      showSideToast(context, '导入完成：$imported 本');
      Navigator.pop(context, imported);
    } catch (e) {
      if (!mounted) return;
      showSideToast(context, '导入失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _progress = '';
        });
      }
    }
  }

  void _toggleAll(bool selected) {
    setState(() {
      if (selected) {
        _selectedKeys
          ..clear()
          ..addAll(_remoteBooks.map(_keyOf));
      } else {
        _selectedKeys.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        _remoteBooks.isNotEmpty && _selectedKeys.length == _remoteBooks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV 远端导入'),
        actions: [
          IconButton(
            onPressed: _isLoading || _isImporting ? null : _loadRemoteBooks,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isImporting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _progress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_error.isNotEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('加载失败：$_error'),
                ),
              ),
            )
          else if (_remoteBooks.isEmpty && !_isLoading)
            const Expanded(
              child: Center(
                child: Text('远端没有可导入书籍'),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: allSelected,
                    onChanged: _isImporting
                        ? null
                        : (value) => _toggleAll(value ?? false),
                    title: Text(
                        '全选（${_selectedKeys.length}/${_remoteBooks.length}）'),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _remoteBooks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final book = _remoteBooks[index];
                        final key = _keyOf(book);
                        final selected = _selectedKeys.contains(key);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: _isImporting
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value ?? false) {
                                      _selectedKeys.add(key);
                                    } else {
                                      _selectedKeys.remove(key);
                                    }
                                  });
                                },
                          title: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${book.author} · ${book.format.toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: const Icon(Icons.menu_book_rounded),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isImporting || _remoteBooks.isEmpty
                      ? null
                      : _importSelected,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    _isImporting ? '导入中...' : '导入选中书籍',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
