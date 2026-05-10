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

// Custom focusable card widget for TV navigation
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: FocusNode(),
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          widget.onFocus();
          setState(() {});
        }
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()..scale(widget.isFocused ? 1.05 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: widget.isFocused
                  ? [
                BoxShadow(
                  color: const Color(0xFFFF6B00).withOpacity(0.8),
                  blurRadius: 30,
                  spreadRadius: 5,
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
              borderRadius: BorderRadius.circular(20),
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
                                  "Press Enter to play",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
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

  bool isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  bool isLeftKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft;
  }

  bool isRightKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowRight;
  }

  bool isUpKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp;
  }

  bool isDownKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowDown;
  }

  bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack;
  }

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
        final cardHeight = 280.0; // Approximate card height
        final currentRow = _selectedIndex ~/ _cardsPerRow;
        final viewportHeight = MediaQuery.of(context).size.height - 150;
        final scrollOffset = currentRow * cardHeight;

        _scrollController.animateTo(
          scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final totalCards = movies.length;
      final currentRow = _selectedIndex ~/ _cardsPerRow;
      final cardsInCurrentRow =
      (_selectedIndex + 1) <= (currentRow + 1) * _cardsPerRow
          ? _cardsPerRow
          : totalCards - (currentRow * _cardsPerRow);

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _navigateToMovie(_selectedIndex + 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _navigateToMovie(_selectedIndex - 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextRowIndex = _selectedIndex + _cardsPerRow;
        if (nextRowIndex < totalCards) {
          final columnInRow = _selectedIndex % _cardsPerRow;
          final targetIndex = nextRowIndex +
              (columnInRow < cardsInCurrentRow ? columnInRow : 0);
          _navigateToMovie(targetIndex.clamp(0, totalCards - 1));
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevRowIndex = _selectedIndex - _cardsPerRow;
        if (prevRowIndex >= 0) {
          final columnInRow = _selectedIndex % _cardsPerRow;
          final prevRowCards =
          prevRowIndex + _cardsPerRow <= totalCards
              ? _cardsPerRow
              : totalCards - prevRowIndex;
          final targetIndex = prevRowIndex +
              (columnInRow < prevRowCards ? columnInRow : prevRowCards - 1);
          _navigateToMovie(targetIndex.clamp(0, totalCards - 1));
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select) {
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
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6B00), Color(0xFFFFD700)],
              ).createShader(bounds),
              child: const Text(
                "Shenawys",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
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
        child: isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B00), Color(0xFFFFD700)],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Loading your movies...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        )
            : error != null
            ? Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        )
            : LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0A0A0A),
                    const Color(0xFF1A1A1A),
                    Colors.blueGrey.shade900.withOpacity(0.3),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                child: GridView.builder(
                  controller: _scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _cardsPerRow,
                    crossAxisSpacing: 25,
                    mainAxisSpacing: 25,
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
              ),
            );
          },
        ),
      ),
    );
  }
}

// MovieDetailPage with improved controls
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
            _errorMessage = videoController.value.errorDescription ?? 'Unknown error occurred';
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
        _errorMessage = 'Failed to load video: ${e.toString()}';
      });
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
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
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        if (videoController.value.isPlaying) {
          videoController.pause();
        } else {
          videoController.play();
        }
        _toggleControls();
        setState(() {});
      }

      if (!_isLiveStream) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          jumpSeconds(-10);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          jumpSeconds(10);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          jumpSeconds(-60);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          jumpSeconds(60);
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        enterFullscreen();
      }

      _showControls = true;
      _startControlsTimer();
      setState(() {});
    }
  }

  String formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h == "00" ? "$m:$s" : "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                "${widget.movie["title"]} - EP ${widget.movie["episode"]}",
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isLiveStream) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 32),
            onPressed: enterFullscreen,
          )
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: handleKey,
        child: GestureDetector(
          onTap: _toggleControls,
          child: _errorMessage != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isInitialized = false;
                    });
                    _initializeVideo();
                  },
                  child: const Text('Retry'),
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
                          ),
                        AnimatedOpacity(
                          opacity: _showControls && !videoController.value.isPlaying ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: IconButton(
                              iconSize: 80,
                              color: Colors.white,
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () {
                                videoController.play();
                                _toggleControls();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.orange),
                      SizedBox(height: 20),
                      Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white70),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  formatTime(videoController.value.duration),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_isLiveStream) ...[
                           Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'LIVE STREAM',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isLiveStream) ...[
                              _buildControlButton(
                                icon: Icons.replay_30,
                                label: "-30s",
                                onPressed: () => jumpSeconds(-30),
                              ),
                              const SizedBox(width: 14),
                              _buildControlButton(
                                icon: Icons.replay_10,
                                label: "-10s",
                                onPressed: () => jumpSeconds(-10),
                              ),
                              const SizedBox(width: 14),
                            ],
                            _buildControlButton(
                              icon: videoController.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              label: videoController.value.isPlaying ? "Pause" : "Play",
                              iconSize: 50,
                              color: Colors.orange,
                              onPressed: () {
                                setState(() {
                                  if (videoController.value.isPlaying) {
                                    videoController.pause();
                                  } else {
                                    videoController.play();
                                  }
                                });
                                _toggleControls();
                              },
                            ),
                            if (!_isLiveStream) ...[
                              const SizedBox(width: 14),
                              _buildControlButton(
                                icon: Icons.forward_10,
                                label: "+10s",
                                onPressed: () => jumpSeconds(10),
                              ),
                              const SizedBox(width: 14),
                              _buildControlButton(
                                icon: Icons.forward_30,
                                label: "+30s",
                                onPressed: () => jumpSeconds(30),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Remote Controls: ↑↓←→ (seek), ⏎ (play/pause), F (fullscreen)",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
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

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    double iconSize = 40,
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        IconButton(
          iconSize: iconSize,
          color: color,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
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