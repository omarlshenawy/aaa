import 'dart:convert';
import 'dart:html' as html; // For web fullscreen
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
        cardTheme: CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const MovieListPage(),
    );
  }
}

// ------------------- Movie List Page -------------------
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
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    fetchMovies();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future fetchMovies() async {
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

  @override
  Widget build(BuildContext context) {
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
      body: isLoading
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
          : Focus(
        autofocus: true,
        child: RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (event) {
            if (event is RawKeyDownEvent) {
              double offset = _scrollController.offset;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                offset = (offset + 150).clamp(
                    0.0, _scrollController.position.maxScrollExtent);
              } else if (event.logicalKey ==
                  LogicalKeyboardKey.arrowUp) {
                offset = (offset - 150).clamp(
                    0.0, _scrollController.position.maxScrollExtent);
              }
              _scrollController.animateTo(
                offset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          },
          child: Container(
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
            child: GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (MediaQuery.of(context).size.width >= 900)? 5 : 2,
                  crossAxisSpacing: 25,
                  mainAxisSpacing: 25,
                  childAspectRatio: 0.7,
                ),
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final movie = movies[index];
                  final isHovered = _hoveredIndex == index;

                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoveredIndex = index),
                    onExit: (_) => setState(() => _hoveredIndex = -1),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => MovieDetailPage(movie: movie),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        transform: Matrix4.identity()..scale(isHovered ? 1.08 : 1.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isHovered
                              ? [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withOpacity(0.6),
                              blurRadius: 25,
                              spreadRadius: 3,
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
                                colors: isHovered
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
                                        "${movie["posterUrl"]}".trim() == "1"
                                            ? Icons.image
                                            : Icons.image_not_supported,
                                        size: isHovered ? 120 : 80,
                                        color: Colors.white,
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
                                          "EP ${movie["episode"]}",
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
                                          movie["title"] ?? "",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isHovered ? 20 : 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedOpacity(
                                        duration: const Duration(milliseconds: 300),
                                        opacity: isHovered ? 1 : 0,
                                        child: const Row(
                                          children: [
                                            Icon(Icons.play_arrow,
                                                color: Colors.white, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              "Watch",
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
                  );
                }
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RawMaterialButton(
            onPressed: () {
              _scrollController.animateTo(
                (_scrollController.offset - 380)
                    .clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            },
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 10,
            fillColor: Colors.transparent,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA6000), Color(0xFFE69D00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE88200).withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_upward, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 30),
          RawMaterialButton(
            onPressed: () {
              _scrollController.animateTo(
                (_scrollController.offset + 380)
                    .clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            },
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 10,
            fillColor: Colors.transparent,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA6000), Color(0xFFE69D00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE88200).withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_downward, size: 50, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- Movie Detail Page (FIXED) -------------------
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

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final videoUrl = widget.movie["videoUrl"]!;

      // Check if it's a live stream (common live stream extensions/patterns)
      _isLiveStream = videoUrl.contains('.m3u8') ||
          videoUrl.contains('live') ||
          videoUrl.contains('stream') ||
          videoUrl.contains('.ts');

      videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      // Add listener for errors using the standard listener
      videoController.addListener(() {
        if (videoController.value.hasError) {
          setState(() {
            _errorMessage = videoController.value.errorDescription ?? 'Unknown error occurred';
          });
        }
      });

      // Initialize the controller
      await videoController.initialize();

      setState(() {
        _isInitialized = true;
      });

      // Auto-play after initialization
      await videoController.play();

      // Listen for playback changes
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

  void enterFullscreen() {
    final videoElement = html.document.querySelector('video');
    if (videoElement != null) {
      videoElement.requestFullscreen();
    }
  }

  void jumpSeconds(int seconds) {
    if (!_isInitialized || _isLiveStream) return; // Disable seeking for live streams

    final position = videoController.value.position;
    final duration = videoController.value.duration;

    Duration newPosition = position + Duration(seconds: seconds);

    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > duration) newPosition = duration;

    videoController.seekTo(newPosition);
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
        setState(() {});
      }

      if (!_isLiveStream) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          jumpSeconds(-10);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          jumpSeconds(10);
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        enterFullscreen();
      }
    }
  }

  @override
  void dispose() {
    videoController.dispose();
    _focusNode.dispose();
    super.dispose();
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
            Text("${widget.movie["title"]}  ${widget.movie["episode"]}" ?? ""),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 42),
            onPressed: enterFullscreen,
          )
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: handleKey,
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
            // Video Player
            Expanded(
              child: Center(
                child: _isInitialized
                    ? AspectRatio(
                  aspectRatio: videoController.value.aspectRatio > 0
                      ? videoController.value.aspectRatio
                      : 16 / 9, // Fallback aspect ratio
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(videoController),
                      // Show loading indicator while buffering
                      if (videoController.value.isBuffering)
                        const CircularProgressIndicator(
                          color: Colors.orange,
                        ),
                      // Play/Pause button overlay
                      if (!videoController.value.isPlaying && _isInitialized)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: IconButton(
                            iconSize: 64,
                            color: Colors.white,
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () {
                              videoController.play();
                              setState(() {});
                            },
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

            // Controls - Hide progress bar for live streams
            if (_isInitialized)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (!_isLiveStream) ...[
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
                    ] else ...[
                      // Live indicator
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'LIVE',
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
                    // Control Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isLiveStream) ...[
                          IconButton(
                            iconSize: 40,
                            color: Colors.white,
                            icon: const Icon(Icons.replay_10_sharp),
                            onPressed: () => jumpSeconds(-10),
                          ),
                          const SizedBox(width: 14),
                        ],
                        IconButton(
                          iconSize: 50,
                          color: Colors.orange,
                          icon: Icon(
                            videoController.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: () {
                            setState(() {
                              if (videoController.value.isPlaying) {
                                videoController.pause();
                              } else {
                                videoController.play();
                              }
                            });
                          },
                        ),
                        if (!_isLiveStream) ...[
                          const SizedBox(width: 14),
                          IconButton(
                            iconSize: 40,
                            color: Colors.white,
                            icon: const Icon(Icons.forward_10_sharp),
                            onPressed: () => jumpSeconds(10),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
          ],
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