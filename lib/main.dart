import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinematic Movies',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        fontFamily: 'Poppins',
      ),
      home: const MovieListPage(),
    );
  }
}

// Focusable card optimized for TV remote
class FocusableMovieCard extends StatefulWidget {
  final Map<String, String> movie;
  final int index;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onFocus;

  const FocusableMovieCard({
    super.key,
    required this.movie,
    required this.index,
    required this.isFocused,
    required this.onTap,
    required this.onFocus,
  });

  @override
  State<FocusableMovieCard> createState() => _FocusableMovieCardState();
}

class _FocusableMovieCardState extends State<FocusableMovieCard> {
  final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        widget.onFocus();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: true,
      skipTraversal: false,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          // Handle enter/select on remote
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(widget.isFocused ? 1.05 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: widget.isFocused
                ? Border.all(color: const Color(0xFFFF6B00), width: 4)
                : null,
            boxShadow: widget.isFocused
                ? [
              BoxShadow(
                color: const Color(0xFFFF6B00).withOpacity(0.8),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ]
                : _isHovered
                ? [
              BoxShadow(
                color: const Color(0xFFFF6B00).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isFocused
                      ? [const Color(0xFFFF6B00), const Color(0xFF1A1A1A)]
                      : [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.8),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.movie_filter,
                          size: widget.isFocused ? 100 : 80,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "EP ${widget.movie["episode"]}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            widget.movie["title"] ?? "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: widget.isFocused ? 20 : 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: (widget.isFocused || _isHovered) ? 1 : 0,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                "PRESS • OK",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key});

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  List<Map<String, String>> movies = [];
  bool isLoading = true;
  String? error;
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;
  int _cardsPerRow = 5;
  late FocusNode _pageFocusNode;
  final GlobalKey _gridKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageFocusNode = FocusNode();
    fetchMovies();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCardsPerRow();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _updateCardsPerRow() {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      if (width >= 1600) {
        _cardsPerRow = 7;
      } else if (width >= 1200) {
        _cardsPerRow = 6;
      } else if (width >= 900) {
        _cardsPerRow = 5;
      } else if (width >= 600) {
        _cardsPerRow = 3;
      } else {
        _cardsPerRow = 2;
      }
    });
  }

  Future<void> fetchMovies() async {
    try {
      final response = await http.get(
        Uri.parse(
            "https://raw.githubusercontent.com/omarlshenawy/vvv/refs/heads/main/m.json?t=${DateTime.now().millisecondsSinceEpoch}"),
      );

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        movies = data.map((e) => Map<String, String>.from(e)).toList();
        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Failed to load movies";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _navigateToMovie(int newIndex) {
    if (newIndex < 0 || newIndex >= movies.length) return;

    setState(() {
      _selectedIndex = newIndex;
    });

    // Auto-scroll to keep selected card in view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final cardHeight = 280.0;
        final currentRow = _selectedIndex ~/ _cardsPerRow;
        final scrollOffset = (currentRow * cardHeight) - 100;

        _scrollController.animateTo(
          scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final totalCards = movies.length;
      final logicalKey = event.logicalKey;

      // Handle D-pad navigation (works with all TV remotes)
      if (logicalKey == LogicalKeyboardKey.arrowRight) {
        _navigateToMovie(_selectedIndex + 1);
      }
      else if (logicalKey == LogicalKeyboardKey.arrowLeft) {
        _navigateToMovie(_selectedIndex - 1);
      }
      else if (logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextRowIndex = _selectedIndex + _cardsPerRow;
        if (nextRowIndex < totalCards) {
          final columnInRow = _selectedIndex % _cardsPerRow;
          final targetIndex = nextRowIndex + columnInRow;
          if (targetIndex < totalCards) {
            _navigateToMovie(targetIndex);
          } else {
            _navigateToMovie(nextRowIndex);
          }
        }
      }
      else if (logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevRowIndex = _selectedIndex - _cardsPerRow;
        if (prevRowIndex >= 0) {
          final columnInRow = _selectedIndex % _cardsPerRow;
          final targetIndex = prevRowIndex + columnInRow;
          if (targetIndex < totalCards) {
            _navigateToMovie(targetIndex);
          } else {
            _navigateToMovie(prevRowIndex);
          }
        }
      }
      else if (logicalKey == LogicalKeyboardKey.select ||
          logicalKey == LogicalKeyboardKey.enter ||
          logicalKey == LogicalKeyboardKey.space) {
        _openMovieDetail();
      }
    }
  }

  void _openMovieDetail() {
    if (_selectedIndex >= 0 && _selectedIndex < movies.length) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MovieDetailPage(movie: movies[_selectedIndex]),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ).then((_) {
        // Refocus when returning
        FocusScope.of(context).requestFocus(_pageFocusNode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateCardsPerRow();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: AppBar(
            automaticallyImplyLeading: false,
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFFFD700)],
              ).createShader(bounds),
              child: const Text(
                "SHENA WYS",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
      body: RawKeyboardListener(
        focusNode: _pageFocusNode,
        autofocus: true,
        onKey: _handleKeyEvent,
        child: Container(
          key: _gridKey,
          child: isLoading
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFFD700)],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Loading Movies...",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          )
              : error != null
              ? Center(
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: GridView.builder(
                  controller: _scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _cardsPerRow,
                    crossAxisSpacing: 30,
                    mainAxisSpacing: 30,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    return FocusableMovieCard(
                      movie: movies[index],
                      index: index,
                      isFocused: _selectedIndex == index,
                      onTap: _openMovieDetail,
                      onFocus: () => _navigateToMovie(index),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// MovieDetailPage optimized for TV remote
class MovieDetailPage extends StatefulWidget {
  final Map<String, String> movie;
  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late VideoPlayerController videoController;
  final FocusNode _focusNode = FocusNode();
  bool _isLiveStream = false;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    // Request focus after a short delay for TV
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    videoController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoUrl = widget.movie["videoUrl"]!;

      _isLiveStream = videoUrl.contains('.m3u8') ||
          videoUrl.contains('live') ||
          videoUrl.contains('stream') ||
          videoUrl.contains('.ts');

      videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      videoController.addListener(() {
        if (videoController.value.hasError) {
          setState(() {
            _errorMessage = videoController.value.errorDescription ?? 'Video error occurred';
          });
        }
      });

      await videoController.initialize();

      setState(() {
        _isInitialized = true;
      });

      await videoController.play();
      _startControlsTimer();

      videoController.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load video';
      });
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void enterFullscreen() {
    final videoElement = html.document.querySelector('video');
    if (videoElement != null) {
      videoElement.requestFullscreen();
    }
  }

  void jumpSeconds(int seconds) {
    if (!_isInitialized || _isLiveStream) return;

    final position = videoController.value.position;
    final duration = videoController.value.duration;

    Duration newPosition = position + Duration(seconds: seconds);

    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > duration) newPosition = duration;

    videoController.seekTo(newPosition);
    _showControls = true;
    _startControlsTimer();
    setState(() {});
  }

  void handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final logicalKey = event.logicalKey;

      // Play/Pause with remote OK/Enter button
      if (logicalKey == LogicalKeyboardKey.select ||
          logicalKey == LogicalKeyboardKey.enter ||
          logicalKey == LogicalKeyboardKey.space) {
        if (videoController.value.isPlaying) {
          videoController.pause();
        } else {
          videoController.play();
        }
        _toggleControls();
        setState(() {});
      }

      // Navigation for seeking (works with D-pad)
      if (!_isLiveStream) {
        if (logicalKey == LogicalKeyboardKey.arrowLeft) {
          jumpSeconds(-10);
        }
        if (logicalKey == LogicalKeyboardKey.arrowRight) {
          jumpSeconds(10);
        }
        if (logicalKey == LogicalKeyboardKey.arrowDown) {
          jumpSeconds(-30);
        }
        if (logicalKey == LogicalKeyboardKey.arrowUp) {
          jumpSeconds(30);
        }
      }

      // Back button on remote
      if (logicalKey == LogicalKeyboardKey.goBack ||
          logicalKey == LogicalKeyboardKey.backspace) {
        Navigator.pop(context);
      }

      // Fullscreen
      if (logicalKey == LogicalKeyboardKey.keyF ||
          logicalKey == LogicalKeyboardKey.f1) {
        enterFullscreen();
      }

      _showControls = true;
      _startControlsTimer();
      setState(() {});
    }
  }

  String formatTime(Duration d) {
    if (!d.isNegative && d.inSeconds > 0) {
      String two(int n) => n.toString().padLeft(2, '0');
      final h = two(d.inHours);
      final m = two(d.inMinutes.remainder(60));
      final s = two(d.inSeconds.remainder(60));
      return h == "00" ? "$m:$s" : "$h:$m:$s";
    }
    return "0:00";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 32, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "${widget.movie["title"]} - EP ${widget.movie["episode"]}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_isLiveStream)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.fullscreen, size: 32, color: Colors.white),
                  onPressed: enterFullscreen,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: handleKey,
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: _errorMessage != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isInitialized = false;
                    });
                    _initializeVideo();
                  },
                  child: const Text('RETRY', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          )
              : Column(
            children: [
              Expanded(
                child: Center(
                  child: _isInitialized
                      ? AspectRatio(
                    aspectRatio: videoController.value.aspectRatio > 0
                        ? videoController.value.aspectRatio
                        : 16 / 9,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(videoController),
                        if (videoController.value.isBuffering)
                          const CircularProgressIndicator(
                            color: Colors.orange,
                            strokeWidth: 4,
                          ),
                        AnimatedOpacity(
                          opacity: _showControls && !videoController.value.isPlaying ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(80),
                            ),
                            child: IconButton(
                              iconSize: 100,
                              color: Colors.white,
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () {
                                videoController.play();
                                _toggleControls();
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          child: AnimatedOpacity(
                            opacity: _showControls ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "▲▼ ◀▶  •  OK",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.orange, strokeWidth: 4),
                      SizedBox(height: 30),
                      Text(
                        'Loading Video...',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black87,
                  height: 120,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    child: Column(
                      children: [
                        if (!_isLiveStream && _isInitialized) ...[
                          Slider(
                            min: 0,
                            max: videoController.value.duration.inSeconds.toDouble(),
                            value: videoController.value.position.inSeconds
                                .clamp(0, videoController.value.duration.inSeconds)
                                .toDouble(),
                            activeColor: Colors.orange,
                            inactiveColor: Colors.grey,
                            onChanged: (value) {
                              videoController.seekTo(
                                Duration(seconds: value.toInt()),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatTime(videoController.value.position),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                Text(
                                  formatTime(videoController.value.duration),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_isLiveStream) ...[
                          const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'LIVE STREAM',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            "REMOTE: ▲▼ (30s)  ◀▶ (10s)  OK (Play/Pause)",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*
flutter build web --release --base-href /aaa/

cp -r build/web/* . -Force

git add .
git commit -m "Deploy Flutter Web movie app to GitHub Pages"
git push origin main

 */
*/