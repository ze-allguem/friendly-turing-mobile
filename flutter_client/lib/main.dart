import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class ConfigManager {
  static String _serverUrl = 'http://192.168.100.5:8000';

  static String get serverUrl => _serverUrl;

  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/config.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data['server_url'] != null) {
          _serverUrl = data['server_url'];
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar config: $e');
    }
  }

  static Future<void> saveServerUrl(String url) async {
    _serverUrl = url;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/config.json');
      await file.writeAsString(jsonEncode({'server_url': url}));
    } catch (e) {
      debugPrint('Erro ao salvar config: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigManager.init();
  runApp(const LuminaReaderApp());
}

class LuminaReaderApp extends StatelessWidget {
  const LuminaReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumina Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // slate-50
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0050D6), // brand blue
          secondary: Color(0xFF3B82F6), // light blue
          surface: Color(0xFFFFFFFF), // white
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF),
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF0F172A),
          elevation: 1,
          iconTheme: IconThemeData(color: Color(0xFF64748B)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

String get baseUrl {
  return ConfigManager.serverUrl;
}

// Voice configuration options
class VoiceOption {
  final String id;
  final String name;
  final String provider;
  final String lang;

  const VoiceOption({
    required this.id,
    required this.name,
    required this.provider,
    required this.lang,
  });
}

const List<VoiceOption> defaultVoicesList = [
  VoiceOption(id: 'pt-BR-FranciscaNeural', name: 'Francisca (Feminina)', provider: 'edge', lang: 'pt-BR'),
  VoiceOption(id: 'pt-BR-AntonioNeural', name: 'Antônio (Masculino)', provider: 'edge', lang: 'pt-BR'),
];

// Reading Themes configuration
class ReadingTheme {
  final String name;
  final Color backgroundColor;
  final Color cardBackgroundColor;
  final Color textColor;
  final Color borderColor;
  final Color accentColor;
  final Color bannerColor;
  final Color bannerTextColor;

  const ReadingTheme({
    required this.name,
    required this.backgroundColor,
    required this.cardBackgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.accentColor,
    required this.bannerColor,
    required this.bannerTextColor,
  });
}

const List<ReadingTheme> readingThemes = [
  ReadingTheme(
    name: 'Claro',
    backgroundColor: Color(0xFFF8FAFC), // slate-50
    cardBackgroundColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF0F172A), // slate-900
    borderColor: Color(0xFFE2E8F0), // slate-200
    accentColor: Color(0xFF0050D6), // brand blue
    bannerColor: Color(0xFFEEF2FF), // soft indigo
    bannerTextColor: Color(0xFF0050D6),
  ),
  ReadingTheme(
    name: 'Sépia',
    backgroundColor: Color(0xFFF4ECD8),
    cardBackgroundColor: Color(0xFFFDFBF7),
    textColor: Color(0xFF433422),
    borderColor: Color(0xFFE4D5B7),
    accentColor: Color(0xFF8B5A2B),
    bannerColor: Color(0xFFEFE6C9),
    bannerTextColor: Color(0xFF5C3A21),
  ),
  ReadingTheme(
    name: 'Noturno',
    backgroundColor: Color(0xFF0F172A), // slate-900
    cardBackgroundColor: Color(0xFF1E293B), // slate-800
    textColor: Color(0xFFF1F5F9), // slate-100
    borderColor: Color(0xFF334155), // slate-700
    accentColor: Color(0xFF3B82F6), // light blue
    bannerColor: Color(0xFF1E1B4B), // dark indigo
    bannerTextColor: Color(0xFF818CF8),
  ),
  ReadingTheme(
    name: 'Verde',
    backgroundColor: Color(0xFFE8F0E8),
    cardBackgroundColor: Color(0xFFF3F7F3),
    textColor: Color(0xFF1A331E),
    borderColor: Color(0xFFC2D6C2),
    accentColor: Color(0xFF2E7D32),
    bannerColor: Color(0xFFD4E6D4),
    bannerTextColor: Color(0xFF1B5E20),
  ),
];

// Models
enum BlockType { title, normal, definition, warning, quote, bordered }

class ReadingBlock {
  final String html;
  final String rawText;
  final BlockType type;
  final String? badge;

  ReadingBlock({
    required this.html,
    required this.rawText,
    required this.type,
    this.badge,
  });

  factory ReadingBlock.fromHtml(String html) {
    BlockType type = BlockType.normal;
    String? badge;

    if (html.contains('class="reading-section-title"')) {
      type = BlockType.title;
    } else if (html.contains('class="reading-block definition"')) {
      type = BlockType.definition;
    } else if (html.contains('class="reading-block warning"')) {
      type = BlockType.warning;
    } else if (html.contains('class="reading-block quote"')) {
      type = BlockType.quote;
    } else if (html.contains('class="reading-block bordered"')) {
      type = BlockType.bordered;
    }

    // Extract badge: <span class="badge">Conceito</span>
    final badgeRegex = RegExp(r'<span class="badge">([^<]+)</span>');
    final badgeMatch = badgeRegex.firstMatch(html);
    if (badgeMatch != null) {
      badge = badgeMatch.group(1);
    }

    // Clean html for raw TTS text
    String rawText = html;
    rawText = rawText.replaceAll(RegExp(r'</?(div|p|h1|h2|h3|br)[^>]*>'), '\n');
    rawText = rawText.replaceAll(RegExp(r'<[^>]+>'), '');
    rawText = rawText.replaceAll(RegExp(r'\n+'), '\n');
    rawText = rawText.trim();
    rawText = _decodeHtmlEntities(rawText);

    // Remove badge text from rawText if present at the start
    if (badge != null && rawText.startsWith(badge)) {
      rawText = rawText.substring(badge.length).trim();
      if (rawText.startsWith(':') || rawText.startsWith('-')) {
        rawText = rawText.substring(1).trim();
      }
    }

    return ReadingBlock(
      html: html,
      rawText: rawText,
      type: type,
      badge: badge,
    );
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }
}

class ReadingSession {
  final String sessionId;
  final String title;
  final List<ReadingBlock> blocks;
  int progressIndex;
  final String date;

  ReadingSession({
    required this.sessionId,
    required this.title,
    required this.blocks,
    this.progressIndex = 0,
    required this.date,
  });

  double get progressPercentage {
    if (blocks.isEmpty) return 0.0;
    return (progressIndex / blocks.length).clamp(0.0, 1.0);
  }
}

// In-Memory Database for local UI state
class SessionManager {
  static final List<ReadingSession> _sessions = [];

  static List<ReadingSession> get sessions => _sessions;

  static void addSession(ReadingSession session) {
    _sessions.removeWhere((s) => s.sessionId == session.sessionId);
    _sessions.insert(0, session);
  }

  static void deleteSession(String sessionId) {
    _sessions.removeWhere((s) => s.sessionId == sessionId);
  }
}

// Home Screen View
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  List<VoiceOption> _voicesList = List.from(defaultVoicesList);
  String _selectedVoiceId = 'pt-BR-FranciscaNeural';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  void _navigateToReader(ReadingSession session) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            session: session,
            voicesList: _voicesList,
            selectedVoiceId: _selectedVoiceId,
            onVoiceChanged: (newVoiceId) {
              setState(() {
                _selectedVoiceId = newVoiceId;
              });
            },
          ),
        ),
      ).then((_) {
        setState(() {}); // Refresh home progress when returning
      });
    }
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: ConfigManager.serverUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configurações do Servidor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Digite a URL do seu servidor backend (ex: nuvem ou IP local):',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'URL do Servidor',
                  border: OutlineInputBorder(),
                  hintText: 'https://seu-servidor.onrender.com',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                String url = controller.text.trim();
                if (url.endsWith('/')) {
                  url = url.substring(0, url.length - 1);
                }
                await ConfigManager.saveServerUrl(url);
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadPDF() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User cancelled
      }

      setState(() {
        _isLoading = true;
      });

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;

      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseBody);
        final sessionId = jsonResponse['session_id'];
        final List<dynamic> rawBlocks = jsonResponse['blocks'];

        final List<ReadingBlock> blocks = rawBlocks
            .map((b) => ReadingBlock.fromHtml(b.toString()))
            .toList();

        final newSession = ReadingSession(
          sessionId: sessionId,
          title: fileName.replaceAll('.pdf', ''),
          blocks: blocks,
          date: 'Agora',
        );

        SessionManager.addSession(newSession);

        setState(() {
          _isLoading = false;
        });

        _navigateToReader(newSession);
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = SessionManager.sessions;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Beautiful Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24, top: 32, right: 24, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0050D6), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0050D6).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'LUMINA',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0050D6),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const Text(
                                  ' READER',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w300,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Leitura Otimizada por IA',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
                          tooltip: 'Configurar Servidor',
                          onPressed: _showSettingsDialog,
                        ),
                      ],
                    ),
                  ),
                ),
                // Welcome / Upload card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: const Color(0xFF0050D6).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: _pickAndUploadPDF,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 56,
                                color: Color(0xFF0050D6),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Carregar Novo Documento PDF',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Toque para selecionar um arquivo PDF do seu dispositivo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),



                // Title for Recent Readings
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Text(
                      'Leituras Recentes',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                // Recent readings items list
                sessions.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.015),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.menu_book_outlined,
                                  size: 40,
                                  color: Color(0xFF94A3B8),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Nenhuma leitura recente.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Faça o upload de um PDF acima para iniciar sua biblioteca.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final session = sessions[index];
                            return Dismissible(
                              key: Key(session.sessionId),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                setState(() {
                                  SessionManager.deleteSession(session.sessionId);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"${session.title}" excluído das leituras recentes.'),
                                  ),
                                );
                              },
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              session.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            session.date,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: session.progressPercentage,
                                                minHeight: 6,
                                                backgroundColor: const Color(0xFFE2E8F0),
                                                color: const Color(0xFF0050D6),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${(session.progressPercentage * 100).toInt()}%',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => _navigateToReader(session),
                                            icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
                                            label: const Text('Ler Agora'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFF0050D6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: sessions.length,
                        ),
                      ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Enviando PDF e formatando texto...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Reader Screen View
class ReaderScreen extends StatefulWidget {
  final ReadingSession session;
  final List<VoiceOption> voicesList;
  final String selectedVoiceId;
  final Function(String) onVoiceChanged;

  const ReaderScreen({
    super.key,
    required this.session,
    required this.voicesList,
    required this.selectedVoiceId,
    required this.onVoiceChanged,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _blockKeys = {};

  int _currentIndex = 0;
  bool _isPlaying = false;
  double _speed = 1.0;
  ReadingTheme _currentTheme = readingThemes[0];

  // Native audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerPlaybackEventSub;
  StreamSubscription? _processingStateSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.session.progressIndex;

    // Listen to native audio playing state changes
    _playerPlaybackEventSub = _audioPlayer.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });

    // Listen to native audio completion to auto-advance
    _processingStateSub = _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _advanceNextBlock();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _playerPlaybackEventSub?.cancel();
    _processingStateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _scrollToBlock(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _blockKeys[index];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1, // Near the top of the viewport
        );
      }
    });
  }

  Future<void> _playBlock(int index) async {
    if (widget.session.blocks.isEmpty) return;

    setState(() {
      _currentIndex = index;
      widget.session.progressIndex = index;
    });

    _scrollToBlock(index);

    try {
      await _audioPlayer.stop();
      
      // Load and stream directly from local backend endpoint using just_audio
      final audioUrl = '$baseUrl/stream-audio/${widget.session.sessionId}/$index?voice=${widget.selectedVoiceId}';
      
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.setSpeed(_speed);
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reproduzir áudio: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      if (_audioPlayer.duration == null) {
        _playBlock(_currentIndex);
      } else {
        _audioPlayer.play();
      }
    }
  }

  void _advanceNextBlock() {
    if (_currentIndex < widget.session.blocks.length - 1) {
      _playBlock(_currentIndex + 1);
    } else {
      setState(() {
        _isPlaying = false;
        widget.session.progressIndex = widget.session.blocks.length; // Complete
      });
    }
  }

  void _goToPreviousBlock() {
    if (_currentIndex > 0) {
      _playBlock(_currentIndex - 1);
    }
  }

  void _changeSpeed(double newSpeed) {
    setState(() {
      _speed = newSpeed;
    });
    _audioPlayer.setSpeed(newSpeed);
  }

  void _changeVoice(String voiceId) {
    widget.onVoiceChanged(voiceId);
    // Give a tiny delay for voice state to update
    Future.microtask(() {
      if (_isPlaying) {
        _playBlock(_currentIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.session.blocks;

    return Scaffold(
      backgroundColor: _currentTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.session.title,
          style: TextStyle(
            color: _currentTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _currentTheme.cardBackgroundColor,
        foregroundColor: _currentTheme.textColor,
        elevation: 1,
        iconTheme: IconThemeData(color: _currentTheme.textColor),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Alterar Tema',
            onPressed: _showThemeSelector,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _currentTheme.bannerColor,
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  color: _currentTheme.bannerTextColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toque sobre qualquer bloco para ler em voz alta com vozes neurais.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentTheme.bannerTextColor.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Blocks list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: blocks.length,
              itemBuilder: (context, index) {
                final block = blocks[index];
                final key = _blockKeys.putIfAbsent(index, () => GlobalKey());
                final isCurrent = index == _currentIndex;

                return GestureDetector(
                  key: key,
                  onTap: () => _playBlock(index),
                  child: _buildBlockWidget(block, isCurrent),
                );
              },
            ),
          ),
          // Playback Bottom controls bar
          _buildBottomControlBar(blocks.length),
        ],
      ),
    );
  }

  // Build appropriate widget based on HTML BlockType
  Widget _buildBlockWidget(ReadingBlock block, bool isCurrent) {
    Color cardBg = _currentTheme.cardBackgroundColor;
    double leftBarWidth = 0.0;
    Color leftBarColor = Colors.transparent;
    EdgeInsets padding = const EdgeInsets.all(18);

    switch (block.type) {
      case BlockType.definition:
        cardBg = _currentTheme.bannerColor;
        padding = const EdgeInsets.all(20);
        break;
      case BlockType.warning:
        if (_currentTheme.name == 'Noturno') {
          cardBg = const Color(0xFF2E1A05);
          leftBarColor = const Color(0xFFFBBF24);
        } else if (_currentTheme.name == 'Sépia') {
          cardBg = const Color(0xFFEFE6C9);
          leftBarColor = const Color(0xFFD97706);
        } else if (_currentTheme.name == 'Verde') {
          cardBg = const Color(0xFFFFFDE6);
          leftBarColor = const Color(0xFFE2B93B);
        } else {
          cardBg = const Color(0xFFFFFBEB);
          leftBarColor = const Color(0xFFF59E0B);
        }
        leftBarWidth = 4.0;
        padding = const EdgeInsets.only(left: 22, top: 18, bottom: 18, right: 18);
        break;
      case BlockType.quote:
        if (_currentTheme.name == 'Noturno') {
          cardBg = const Color(0xFF1E293B);
          leftBarColor = const Color(0xFF64748B);
        } else if (_currentTheme.name == 'Sépia') {
          cardBg = const Color(0xFFEFE6C9);
          leftBarColor = const Color(0xFF8B5A2B);
        } else {
          cardBg = _currentTheme.backgroundColor;
          leftBarColor = const Color(0xFF64748B);
        }
        leftBarWidth = 4.0;
        padding = const EdgeInsets.only(left: 22, top: 18, bottom: 18, right: 18);
        break;
      case BlockType.bordered:
        cardBg = _currentTheme.cardBackgroundColor;
        leftBarWidth = 4.0;
        leftBarColor = _currentTheme.accentColor;
        padding = const EdgeInsets.only(left: 22, top: 18, bottom: 18, right: 18);
        break;
      default:
        break;
    }

    Color borderColor;
    if (isCurrent) {
      borderColor = _currentTheme.accentColor;
    } else {
      switch (block.type) {
        case BlockType.definition:
          borderColor = _currentTheme.name == 'Noturno' ? const Color(0xFF312E81) : const Color(0xFFE0E7FF);
          break;
        case BlockType.warning:
          borderColor = _currentTheme.name == 'Noturno' ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
          break;
        default:
          borderColor = _currentTheme.borderColor;
          break;
      }
    }

    if (block.type == BlockType.title) {
      return Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 16, left: 24, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: _parseHtmlToSpans(block.html, _currentTheme.accentColor),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _currentTheme.textColor,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: 80,
              height: 4,
              decoration: BoxDecoration(
                color: _currentTheme.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isCurrent ? 2.0 : 1.0,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: _currentTheme.accentColor.withOpacity(0.12),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            if (leftBarWidth > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: leftBarWidth,
                child: Container(color: leftBarColor),
              ),
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // If badge is present, render it first
                  if (block.badge != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: block.type == BlockType.definition
                            ? (_currentTheme.name == 'Noturno' ? const Color(0xFF4338CA) : const Color(0xFF6366F1))
                            : (block.type == BlockType.warning ? const Color(0xFFF59E0B) : _currentTheme.accentColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        block.badge!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  // Custom rich HTML renderer
                  RichText(
                    text: TextSpan(
                      children: _parseHtmlToSpans(block.html, _currentTheme.accentColor),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: _currentTheme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HTML regex parsing into TextSpans
  List<TextSpan> _parseHtmlToSpans(String htmlContent, Color accentColor) {
    final List<TextSpan> spans = [];

    // Clean outer tags
    String cleanText = htmlContent;
    cleanText = cleanText.replaceAll(RegExp(r'^<div[^>]*>'), '');
    cleanText = cleanText.replaceAll(RegExp(r'</div>$'), '');
    cleanText = cleanText.replaceAll(RegExp(r'^<h2[^>]*>'), '');
    cleanText = cleanText.replaceAll(RegExp(r'</h2>$'), '');

    // Strip out badges and outer ul tags, keep list item tags
    cleanText = cleanText.replaceAll(RegExp(r'<span class="badge">[^<]+</span>'), '');
    cleanText = cleanText.replaceAll('<ul>', '').replaceAll('</ul>', '');
    
    // Clean all paragraph tags globally from the text block
    cleanText = cleanText.replaceAll(RegExp(r'</?p[^>]*>'), '');

    // Tokenize
    final tagRegex = RegExp(
      r'(<strong>.*?</strong>|<b>.*?</b>|<mark>.*?</mark>|<em>.*?</em>|<i>.*?</i>|<li>.*?</li>)',
    );

    int lastMatchEnd = 0;
    final matches = tagRegex.allMatches(cleanText);

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        final plain = cleanText.substring(lastMatchEnd, match.start);
        spans.add(TextSpan(text: _decodeHtmlEntities(plain)));
      }

      final matchedText = match.group(0)!;

      if (matchedText.startsWith('<strong>') || matchedText.startsWith('<b>')) {
        final content = matchedText
            .replaceAll('<strong>', '')
            .replaceAll('</strong>', '')
            .replaceAll('<b>', '')
            .replaceAll('</b>', '');
        spans.add(TextSpan(
          text: _decodeHtmlEntities(content),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ));
      } else if (matchedText.startsWith('<mark>')) {
        final content = matchedText.replaceAll('<mark>', '').replaceAll('</mark>', '');
        spans.add(TextSpan(
          text: _decodeHtmlEntities(content),
          style: const TextStyle(
            backgroundColor: Color(0xFFFEF08A), // yellow-200
            color: Color(0xFF854D0E), // yellow-800
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (matchedText.startsWith('<em>') || matchedText.startsWith('<i>')) {
        final content = matchedText
            .replaceAll('<em>', '')
            .replaceAll('em>', '')
            .replaceAll('<i>', '')
            .replaceAll('</i>', '');
        spans.add(TextSpan(
          text: _decodeHtmlEntities(content),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (matchedText.startsWith('<li>')) {
        final content = matchedText.replaceAll('<li>', '').replaceAll('</li>', '');
        spans.add(TextSpan(
          text: '\n• ${_decodeHtmlEntities(content)}',
          style: const TextStyle(height: 1.6),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < cleanText.length) {
      final plain = cleanText.substring(lastMatchEnd);
      spans.add(TextSpan(text: _decodeHtmlEntities(plain)));
    }

    return spans;
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.cardBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Selecionar Tema de Leitura',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _currentTheme.textColor,
                  ),
                ),
              ),
              Divider(height: 1, color: _currentTheme.borderColor),
              ...readingThemes.map((theme) {
                final isSelected = theme.name == _currentTheme.name;
                return ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.borderColor, width: 1.5),
                    ),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.textColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    theme.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _currentTheme.accentColor : _currentTheme.textColor,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: _currentTheme.accentColor)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentTheme = theme;
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showVoiceDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.cardBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Selecionar Voz',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _currentTheme.textColor,
                  ),
                ),
              ),
              Divider(height: 1, color: _currentTheme.borderColor),
              ...widget.voicesList.map((voice) {
                final isSelected = voice.id == widget.selectedVoiceId;
                return ListTile(
                  leading: Icon(
                    Icons.record_voice_over_rounded,
                    color: isSelected ? _currentTheme.accentColor : _currentTheme.textColor.withOpacity(0.6),
                  ),
                  title: Text(
                    voice.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _currentTheme.accentColor : _currentTheme.textColor,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: _currentTheme.accentColor)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _changeVoice(voice.id);
                  },
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showSpeedDropdown() {
    final speeds = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.cardBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Velocidade de Leitura',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _currentTheme.textColor,
                  ),
                ),
              ),
              Divider(height: 1, color: _currentTheme.borderColor),
              ...speeds.map((speedVal) {
                final isSelected = speedVal == _speed;
                return ListTile(
                  leading: Icon(
                    Icons.speed_rounded,
                    color: isSelected ? _currentTheme.accentColor : _currentTheme.textColor.withOpacity(0.6),
                  ),
                  title: Text(
                    '${speedVal.toStringAsFixed(1).replaceAll('.0', '')}x',
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? _currentTheme.accentColor : _currentTheme.textColor,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: _currentTheme.accentColor)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _changeSpeed(speedVal);
                  },
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Draw Bottom playback controller
  Widget _buildBottomControlBar(int totalBlocks) {
    // Current voice resolution to avoid Dropdown errors
    final resolvedVoiceId = widget.voicesList.any((v) => v.id == widget.selectedVoiceId)
        ? widget.selectedVoiceId
        : (widget.voicesList.isNotEmpty ? widget.voicesList.first.id : 'alloy');

    final activeVoice = widget.voicesList.firstWhere(
      (v) => v.id == resolvedVoiceId,
      orElse: () => VoiceOption(id: 'pt-BR-FranciscaNeural', name: 'Francisca (Feminina)', provider: 'edge', lang: 'pt-BR'),
    );

    return Container(
      decoration: BoxDecoration(
        color: _currentTheme.cardBackgroundColor,
        border: Border(top: BorderSide(color: _currentTheme.borderColor, width: 1)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Voice Selector Pill
            GestureDetector(
              onTap: _showVoiceDropdown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.record_voice_over_rounded,
                      size: 16,
                      color: _currentTheme.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      activeVoice.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _currentTheme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Row 2: Playback Controls (Anterior, Play/Pause com rounded-rectangle azul, Próximo)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: 28,
                  color: _currentTheme.name == 'Noturno' ? const Color(0xFF64748B) : const Color(0xFF94A3B8), // slate-400
                  onPressed: _currentIndex > 0 ? _goToPreviousBlock : null,
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _currentTheme.accentColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _currentTheme.accentColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 28,
                  color: _currentTheme.name == 'Noturno' ? const Color(0xFF64748B) : const Color(0xFF94A3B8), // slate-400
                  onPressed: _currentIndex < totalBlocks - 1 ? _advanceNextBlock : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 3: Speed Selector
            GestureDetector(
              onTap: _showSpeedDropdown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 14,
                      color: _currentTheme.textColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_speed.toStringAsFixed(1).replaceAll('.0', '')}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _currentTheme.textColor.withOpacity(0.6),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: _currentTheme.textColor.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
