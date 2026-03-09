import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bookplace/services/supabase_service.dart';

const _genres = [
  'Fiction','Non-Fiction','Mystery','Romance','Sci-Fi',
  'Fantasy','Biography','History','Self-Help','Horror','Thriller',
];

class _PageData {
  final TextEditingController controller = TextEditingController();
  Uint8List? photoBytes;
  String? photoName;
  String? uploadedPhotoUrl;

  void dispose() => controller.dispose();
}

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});
  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _title    = TextEditingController();
  final _author   = TextEditingController();
  final _review   = TextEditingController();
  final _coverUrl = TextEditingController();
  final _quote    = TextEditingController();

  final List<_PageData> _pages = [_PageData()];
  String? _genre;
  int _rating = 5;
  bool _loading = false;

  // Cover photo
  Uint8List? _coverBytes;
  String?    _coverFileName;
  String?    _uploadedCoverUrl;
  final _picker = ImagePicker();

  @override
  void dispose() {
    for (final p in _pages) p.dispose();
    _title.dispose(); _author.dispose(); _review.dispose();
    _coverUrl.dispose(); _quote.dispose();
    super.dispose();
  }

  // ── Photo helpers ─────────────────────────────────────

  Future<void> _pickCover(ImageSource source) async {
    final f = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() { _coverBytes = b; _coverFileName = f.name; _uploadedCoverUrl = null; _coverUrl.clear(); });
  }

  Future<void> _pickPagePhoto(int index, ImageSource source) async {
    final f = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1000);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() { _pages[index].photoBytes = b; _pages[index].photoName = f.name; });
  }

  void _showCoverPicker() => _showPhotoPicker(
    onCamera: () => _pickCover(ImageSource.camera),
    onGallery: () => _pickCover(ImageSource.gallery),
    onRemove: (_coverBytes != null || _uploadedCoverUrl != null)
        ? () => setState(() { _coverBytes = null; _uploadedCoverUrl = null; })
        : null,
  );

  void _showPagePhotoPicker(int i) => _showPhotoPicker(
    onCamera: () => _pickPagePhoto(i, ImageSource.camera),
    onGallery: () => _pickPagePhoto(i, ImageSource.gallery),
    onRemove: _pages[i].photoBytes != null
        ? () => setState(() { _pages[i].photoBytes = null; _pages[i].photoName = null; })
        : null,
  );

  void _showPhotoPicker({
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    VoidCallback? onRemove,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Choose Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF6B6B)),
                  title: const Text('Camera', style: TextStyle(color: Colors.white)),
                  onTap: () { Navigator.pop(context); onCamera(); },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF4ECDC4)),
                title: const Text('Gallery', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); onGallery(); },
              ),
              if (onRemove != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(context); onRemove(); },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _author.text.trim().isEmpty || _review.text.trim().isEmpty) {
      _showError('Fill in title, author and review'); return;
    }
    if (!_pages.any((p) => p.controller.text.trim().isNotEmpty || p.photoBytes != null)) {
      _showError('Add at least one page with text or photo'); return;
    }
    setState(() => _loading = true);
    try {
      // Upload cover
      String? coverUrl = _uploadedCoverUrl ?? (_coverUrl.text.trim().isEmpty ? null : _coverUrl.text.trim());
      if (_coverBytes != null && _uploadedCoverUrl == null) {
        coverUrl = await svc.uploadCoverPhoto(fileBytes: _coverBytes!, fileName: _coverFileName!);
      }

      // Upload page photos
      final pageTexts = <String>[];
      final pagePhotoUrls = <String?>[];
      for (final p in _pages) {
        pageTexts.add(p.controller.text.trim());
        if (p.photoBytes != null && p.uploadedPhotoUrl == null) {
          p.uploadedPhotoUrl = await svc.uploadCoverPhoto(fileBytes: p.photoBytes!, fileName: p.photoName!);
        }
        pagePhotoUrls.add(p.uploadedPhotoUrl);
      }

      await svc.createBookPost(
        title: _title.text.trim(),
        author: _author.text.trim(),
        review: _review.text.trim(),
        rating: _rating,
        pages: pageTexts,
        pagePhotoUrls: pagePhotoUrls,
        coverUrl: coverUrl,
        genre: _genre,
        quote: _quote.text.trim().isEmpty ? null : _quote.text.trim(),
      );

      // Reset
      _title.clear(); _author.clear(); _review.clear(); _coverUrl.clear(); _quote.clear();
      for (final p in _pages) p.dispose();
      setState(() {
        _pages.clear(); _pages.add(_PageData());
        _genre = null; _rating = 5;
        _coverBytes = null; _coverFileName = null; _uploadedCoverUrl = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📚 Book posted!'), backgroundColor: Color(0xFF4ECDC4)),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Share a Book', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Book Title *'),
            _field(_title, 'e.g. The Midnight Library'),
            const SizedBox(height: 14),
            _label('Author *'),
            _field(_author, 'e.g. Matt Haig'),
            const SizedBox(height: 14),

            // Cover photo
            _label('Cover Photo'),
            _PhotoPicker(
              bytes: _coverBytes,
              onTap: _showCoverPicker,
              height: 160,
              placeholder: 'Tap to add cover photo',
            ),
            const SizedBox(height: 10),
            Row(children: const [
              Expanded(child: Divider(color: Colors.white12)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or paste URL', style: TextStyle(color: Colors.white24, fontSize: 11))),
              Expanded(child: Divider(color: Colors.white12)),
            ]),
            const SizedBox(height: 10),
            _field(_coverUrl, 'https://cover-image-url...'),
            const SizedBox(height: 14),

            _label('Genre'),
            _GenreDropdown(value: _genre, onChanged: (v) => setState(() => _genre = v)),
            const SizedBox(height: 14),
            _label('Rating'),
            _StarPicker(rating: _rating, onChanged: (v) => setState(() => _rating = v)),
            const SizedBox(height: 14),
            _label('Your Review *'),
            TextField(controller: _review, maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('What did you think?')),
            const SizedBox(height: 14),
            _label('Favourite Quote'),
            _field(_quote, 'A line that stayed with you…'),

            // ── Pages ────────────────────────────────
            const SizedBox(height: 24),
            Row(children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFFFF6B6B), size: 18),
              const SizedBox(width: 8),
              const Text('Book Pages *', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Text('${_pages.length}/4', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text('Each page can have text, a photo, or both',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            const SizedBox(height: 14),

            ...List.generate(_pages.length, (i) => _PageEditor(
              index: i,
              data: _pages[i],
              canRemove: _pages.length > 1,
              onRemove: () => setState(() { _pages[i].dispose(); _pages.removeAt(i); }),
              onPickPhoto: () => _showPagePhotoPicker(i),
              onChanged: () => setState(() {}),
            )),

            if (_pages.length < 4)
              GestureDetector(
                onTap: () => setState(() => _pages.add(_PageData())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFFF6B6B).withOpacity(0.04),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Color(0xFFFF6B6B), size: 18),
                      SizedBox(width: 6),
                      Text('Add Page', style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                ),
                child: TextButton(
                  onPressed: _loading ? null : _submit,
                  style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Post Book', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(t, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _field(TextEditingController c, String hint) => TextField(
    controller: c, style: const TextStyle(color: Colors.white),
    decoration: _inputDeco(hint),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: Colors.white24),
    filled: true, fillColor: const Color(0xFF1A1A1A),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
  );
}

// ── Page Editor Widget ────────────────────────────────────────────────────────

class _PageEditor extends StatelessWidget {
  final int index;
  final _PageData data;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPickPhoto;
  final VoidCallback onChanged;

  const _PageEditor({
    required this.index,
    required this.data,
    required this.canRemove,
    required this.onRemove,
    required this.onPickPhoto,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Page ${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.close, color: Colors.red, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Text field
          TextField(
            controller: data.controller,
            maxLines: 6,
            maxLength: 1500,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Page text (optional if you add a photo)…',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true, fillColor: const Color(0xFF1A1A1A),
              counterStyle: const TextStyle(color: Colors.white24, fontSize: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
            ),
          ),
          const SizedBox(height: 10),

          // Photo for this page
          _PhotoPicker(
            bytes: data.photoBytes,
            onTap: onPickPhoto,
            height: 110,
            placeholder: 'Add a photo for this page (optional)',
          ),
        ],
      ),
    );
  }
}

// ── Reusable Photo Picker ─────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onTap;
  final double height;
  final String placeholder;

  const _PhotoPicker({
    required this.bytes,
    required this.onTap,
    required this.height,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bytes != null ? const Color(0xFFFF6B6B) : Colors.white12),
          image: bytes != null ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover) : null,
        ),
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded, color: Colors.white38, size: 28),
                  const SizedBox(height: 6),
                  Text(placeholder, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit, color: Colors.white, size: 12),
                    SizedBox(width: 3),
                    Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                ),
              ),
      ),
    );
  }
}

class _GenreDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _GenreDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value, dropdownColor: const Color(0xFF1A1A1A),
      style: const TextStyle(color: Colors.white),
      hint: const Text('Select genre', style: TextStyle(color: Colors.white24)),
      decoration: InputDecoration(
        filled: true, fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
      onChanged: onChanged,
    );
  }
}

class _StarPicker extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  const _StarPicker({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) => GestureDetector(
        onTap: () => onChanged(i + 1),
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(i < rating ? Icons.star : Icons.star_border,
              color: const Color(0xFFFFD700), size: 28),
        ),
      )),
    );
  }
}