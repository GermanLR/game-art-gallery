import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ===============================
/// Real API: Wikimedia Commons (MediaWiki API)
/// - Не тестовый.
/// - Не требует API key.
/// - Для web нужен origin=* (CORS).
/// ===============================

class GalleryItem {
  final int pageId;
  final String title;
  final String pageUrl;
  final String? thumbnailUrl;

  const GalleryItem({
    required this.pageId,
    required this.title,
    required this.pageUrl,
    required this.thumbnailUrl,
  });

  factory GalleryItem.fromPageJson(int pageId, Map<String, dynamic> page) {
    final title = (page['title'] ?? 'Untitled') as String;
    final pageUrl = (page['fullurl'] ?? '') as String;

    String? thumb;
    final thumbnail = page['thumbnail'];
    if (thumbnail is Map<String, dynamic>) {
      final src = thumbnail['source'];
      if (src is String && src.isNotEmpty) thumb = src;
    }

    return GalleryItem(
      pageId: pageId,
      title: title,
      pageUrl: pageUrl,
      thumbnailUrl: thumb,
    );
  }
}

Future<List<GalleryItem>> fetchGallery({required String query}) async {
  // generator=search + prop=pageimages|info (inprop=url) + pithumbsize
  // origin=* важно для web-режима (Edge/Chrome)
  final uri = Uri.parse(
    'https://commons.wikimedia.org/w/api.php'
    '?action=query'
    '&format=json'
    '&generator=search'
    '&gsrsearch=${Uri.encodeComponent(query)}'
    '&gsrlimit=24'
    '&prop=pageimages|info'
    '&inprop=url'
    '&pithumbsize=500'
    '&origin=*',
  );

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw Exception('API error: ${response.statusCode}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final pages = (data['query']?['pages']) as Map<String, dynamic>?;

  if (pages == null) return [];

  final items = <GalleryItem>[];
  for (final entry in pages.entries) {
    final pageId = int.tryParse(entry.key) ?? 0;
    final page = entry.value as Map<String, dynamic>;
    items.add(GalleryItem.fromPageJson(pageId, page));
  }

  // чтобы порядок был стабильнее
  items.sort((a, b) => a.title.compareTo(b.title));
  return items;
}

/// ===============================
/// App
/// ===============================

void main() => runApp(const GameArtGalleryApp());

class GameArtGalleryApp extends StatelessWidget {
  const GameArtGalleryApp({super.key});

  static const bg = Color(0xFF0B0B10);
  static const card = Color(0xFF141424);
  static const accent = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Game Art Gallery',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      routes: {
        '/': (_) => const HomeScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/details') {
          final item = settings.arguments as GalleryItem;
          return MaterialPageRoute(builder: (_) => DetailsScreen(item: item));
        }
        return null;
      },
    );
  }
}

/// ===============================
/// HOME (Grid + Search + Create/Upload)
/// ===============================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<GalleryItem>> futureItems;

  final TextEditingController searchCtrl =
      TextEditingController(text: 'pixel art sprite');

  @override
  void initState() {
    super.initState();
    futureItems = fetchGallery(query: searchCtrl.text);
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      futureItems = fetchGallery(query: searchCtrl.text.trim().isEmpty
          ? 'pixel art sprite'
          : searchCtrl.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Art Gallery'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // По ТЗ на Home должна быть кнопка Create/Upload.
          // Тут делаем демонстрацию перехода на Profile (или можно было бы на экран создания).
          Navigator.pushNamed(context, '/profile');
        },
        icon: const Icon(Icons.add),
        label: const Text('Create / Upload'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          decoration: const InputDecoration(
                            hintText: 'Поиск: pixel art sprite…',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _search,
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Данные загружаются из реального API: Wikimedia Commons (MediaWiki API).',
                    style: TextStyle(color: Colors.white.withOpacity(0.70)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Works',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.95),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<GalleryItem>>(
                future: futureItems,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorBox(text: snapshot.error.toString(), onRetry: _search);
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    );
                  }

                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return _EmptyBox(onRetry: _search);
                  }

                  return GridView.builder(
                    itemCount: items.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _ArtCard(
                        item: item,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/details',
                          arguments: item,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// DETAILS (Preview + metadata + Edit fields + buttons)
/// ===============================

class DetailsScreen extends StatefulWidget {
  final GalleryItem item;
  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late final TextEditingController titleCtrl;
  late final TextEditingController tagsCtrl;
  late final TextEditingController descCtrl;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.item.title);

    // теги/описание — пользовательские поля (по ТЗ)
    tagsCtrl = TextEditingController(text: '#pixelart #sprite #gameart');
    descCtrl = TextEditingController(
      text: 'Описание работы. Можно хранить метаданные, версии и заметки.',
    );
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    tagsCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showSnack('Share: ссылка скопирована (демо)'),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: ListView(
          children: [
            _PreviewCard(thumbnailUrl: item.thumbnailUrl, fallbackTitle: item.title),
            const SizedBox(height: 14),

            _SectionTitle('Metadata'),
            _MetaRow(label: 'Source', value: 'Wikimedia Commons'),
            _MetaRow(label: 'Page URL', value: item.pageUrl.isEmpty ? '(нет)' : item.pageUrl),
            _MetaRow(label: 'Page ID', value: item.pageId.toString()),
            const SizedBox(height: 16),

            _SectionTitle('Edit fields'),
            const SizedBox(height: 8),
            _Labeled(label: 'Название работы', child: TextField(controller: titleCtrl)),
            const SizedBox(height: 10),
            _Labeled(label: 'Теги', child: TextField(controller: tagsCtrl)),
            const SizedBox(height: 10),
            _Labeled(
              label: 'Описание',
              child: TextField(controller: descCtrl, maxLines: 4),
            ),
            const SizedBox(height: 16),

            // Кнопки (Create / Edit / Share / Back)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSnack('Edit: сохранено (демо)'),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _showSnack('Share: ссылка скопирована (демо)'),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
            const SizedBox(height: 14),

            _SectionTitle('Comments (demo)'),
            const SizedBox(height: 8),
            const _Comment(author: 'PixelNewbie', text: 'Круто! Стиль прям атмосферный.'),
            const _Comment(author: 'IndieDev', text: 'Можно сгруппировать по проектам — будет удобно.'),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// PROFILE (student info + collections)
/// ===============================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Из твоего описания:
    const fio = 'Амангельды Нурислам Берикулы';
    const group = '9-3-ПО-22';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: ListView(
          children: [
            _HeaderCard(
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.06),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Icon(Icons.person, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          fio,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Группа: $group',
                          style: TextStyle(color: Colors.white.withOpacity(0.70)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionTitle('Collections (in progress)'),
            const SizedBox(height: 8),
            _Tile(
              icon: Icons.grid_view_rounded,
              title: 'My Works',
              subtitle: 'Коллекция работ + метки + версии (концепт)',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.folder_open,
              title: 'Projects',
              subtitle: 'Группировка по проектам',
              onTap: () {},
            ),
            _Tile(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'Настройки профиля (в процессе)',
              onTap: () {},
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// UI components
/// ===============================

class _HeaderCard extends StatelessWidget {
  final Widget child;
  const _HeaderCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: child,
    );
  }
}

class _ArtCard extends StatelessWidget {
  final GalleryItem item;
  final VoidCallback onTap;

  const _ArtCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // preview image
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.05),
                    child: item.thumbnailUrl == null
                        ? _FallbackPreview(title: item.title)
                        : Image.network(
                            item.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _FallbackPreview(title: item.title),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 3),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white.withOpacity(0.75)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackPreview extends StatelessWidget {
  final String title;
  const _FallbackPreview({required this.title});

  @override
  Widget build(BuildContext context) {
    final ch = title.isNotEmpty ? title.trim()[0].toUpperCase() : 'A';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C3AED), Color(0xFF0E7CFF)],
        ),
      ),
      child: Center(
        child: Text(
          ch,
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.25),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String fallbackTitle;

  const _PreviewCard({required this.thumbnailUrl, required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF141424),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: thumbnailUrl == null
            ? _FallbackPreview(title: fallbackTitle)
            : Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _FallbackPreview(title: fallbackTitle),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: Colors.white.withOpacity(0.95),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final faded = Colors.white.withOpacity(0.65);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: faded, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _Comment extends StatelessWidget {
  final String author;
  final String text;
  const _Comment({required this.author, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(author, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.25)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.65))),
        trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorBox({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 34),
            const SizedBox(height: 10),
            const Text(
              'Ошибка загрузки данных API',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.72)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyBox({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 34),
            const SizedBox(height: 10),
            const Text(
              'Ничего не найдено',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуй другой запрос (например: "sprite sheet", "pixel art character").',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.72)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Search again'),
            ),
          ],
        ),
      ),
    );
  }
}
