import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
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

// Samsung Tizen TV Remote Handler - Mouse/Arrow hybrid
class TizenTVRemoteHandler {
  static Function(int direction)? _onNavigate;
  static Function()? _onSelect;
  static Function()? _onBack;
  static int _lastX = 0;
  static int _lastY = 0;
  static Timer? _moveTimer;
  static String _lastDirection = '';

  static void init({
    required Function(int direction) onNavigate,
    required Function() onSelect,
    required Function() onBack,
  }) {
    _onNavigate = onNavigate;
    _onSelect = onSelect;
    _onBack = onBack;

    // Register JavaScript for Samsung TV
    js.context.callMethod('eval', ['''
      (function() {
        console.log('Samsung TV Mouse/Arrow Handler Initializing...');
        
        var lastX = 0;
        var lastY = 0;
        var moveTimer = null;
        var isTizen = typeof tizen !== 'undefined';
        
        // Function to detect direction from mouse movement
        function detectDirection(x, y) {
          var deltaX = x - lastX;
          var deltaY = y - lastY;
          var threshold = 30; // Movement threshold
          
          if (Math.abs(deltaX) > threshold || Math.abs(deltaY) > threshold) {
            if (Math.abs(deltaX) > Math.abs(deltaY)) {
              if (deltaX > 0) {
                return 'right';
              } else {
                return 'left';
              }
            } else {
              if (deltaY > 0) {
                return 'down';
              } else {
                return 'up';
              }
            }
          }
          return null;
        }
        
        // Track mouse movement (triggered by remote D-pad)
        document.addEventListener('mousemove', function(event) {
          var x = event.clientX;
          var y = event.clientY;
          
          if (lastX !== 0 || lastY !== 0) {
            var direction = detectDirection(x, y);
            
            if (direction && window.tizenMouseHandler) {
              // Clear previous timer
              if (moveTimer) clearTimeout(moveTimer);
              
              // Send direction with debounce
              window.tizenMouseHandler(direction);
              
              // Reset after short delay to prevent multiple rapid triggers
              moveTimer = setTimeout(function() {
                lastX = x;
                lastY = y;
              }, 200);
            }
          }
          
          lastX = x;
          lastY = y;
        });
        
        // Also catch mouse clicks (for OK/Enter)
        document.addEventListener('click', function(event) {
          console.log('Mouse click detected (OK button)');
          if (window.tizenMouseClickHandler) {
            window.tizenMouseClickHandler();
          }
        });
        
        // Also handle key events as fallback for number buttons
        document.addEventListener('keydown', function(event) {
          var keyCode = event.keyCode || event.which;
          console.log('Key pressed:', keyCode);
          
          // Handle number buttons (these work on Samsung)
          if (keyCode >= 48 && keyCode <= 57) { // 0-9
            var number = keyCode - 48;
            console.log('Number pressed:', number);
            if (window.tizenNumberHandler) {
              window.tizenNumberHandler(number);
            }
          }
          
          // Handle back button
          if (keyCode === 10009 || keyCode === 8 || keyCode === 461) {
            console.log('Back button pressed');
            if (window.tizenBackHandler) {
              window.tizenBackHandler();
            }
          }
        });
        
        console.log('Samsung TV Handler Ready');
      })();
    ''']);

    // Register callbacks
    js.context['tizenMouseHandler'] = (String direction) {
      print("Mouse direction: $direction");
      if (direction == 'up') _onNavigate?.call(0);
      else if (direction == 'down') _onNavigate?.call(1);
      else if (direction == 'left') _onNavigate?.call(2);
      else if (direction == 'right') _onNavigate?.call(3);

      // Reset movement debouncer
      _moveTimer?.cancel();
      _moveTimer = Timer(const Duration(milliseconds: 200), () {
        _lastDirection = '';
      });
    };

    js.context['tizenMouseClickHandler'] = () {
      print("OK/Select button pressed");
      _onSelect?.call();
    };

    js.context['tizenNumberHandler'] = (int number) {
      print("Number pressed: $number");
      // Use numbers for quick navigation (1-9 = 10%-90% scroll)
      if (number >= 1 && number <= 9) {
        _onNavigate?.call(4 + number); // Special code for number navigation
      }
    };

    js.context['tizenBackHandler'] = () {
      print("Back button pressed");
      _onBack?.call();
    };
  }

  static void dispose() {
    _moveTimer?.cancel();
    js.context.callMethod('eval', ['''
      if (window.tizenMouseHandler) delete window.tizenMouseHandler;
      if (window.tizenMouseClickHandler) delete window.tizenMouseClickHandler;
      if (window.tizenNumberHandler) delete window.tizenNumberHandler;
      if (window.tizenBackHandler) delete window.tizenBackHandler;
    ''']);
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

  // Debug info
  String _lastAction = "None";
  bool _showDebug = true;
  bool _useMouseMode = true;

  @override
  void initState() {
    super.initState();
    fetchMovies();

    // Initialize Samsung TV handler
    TizenTVRemoteHandler.init(
      onNavigate: _handleNavigation,
      onSelect: _openMovieDetail,
      onBack: _handleBack,
    );
  }

  void _handleNavigation(int direction) {
    // direction: 0=up, 1=down, 2=left, 3=right, 4+=numbers
    setState(() {
      if (direction >= 4) {
        // Number button navigation (quick scroll)
        int number = direction - 4;
        _lastAction = "Number $number";
        _quickScroll(number);
      } else {
        // Directional navigation
        _lastAction = ["UP", "DOWN", "LEFT", "RIGHT"][direction];
        switch(direction) {
          case 0: // Up
            _navigateUp();
            break;
          case 1: // Down
            _navigateDown();
            break;
          case 2: // Left
            _navigateToMovie(_selectedIndex - 1);
            break;
          case 3: // Right
            _navigateToMovie(_selectedIndex + 1);
            break;
        }
      }
    });
  }

  void _quickScroll(int number) {
    // Numbers 1-9 scroll to different percentages
    if (!_scrollController.hasClients) return;

    double percentage = number / 9.0;
    double maxScroll = _scrollController.position.maxScrollExtent;
    double targetScroll = maxScroll * percentage;

    _scrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );

    // Also try to select a movie near that scroll position
    int targetIndex = (movies.length * percentage).toInt();
    if (targetIndex >= movies.length) targetIndex = movies.length - 1;
    if (targetIndex < 0) targetIndex = 0;
    _navigateToMovie(targetIndex);
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _navigateDown() {
    if (movies.isEmpty) return;
    final nextRowIndex = _selectedIndex + _cardsPerRow;
    if (nextRowIndex < movies.length) {
      final columnInRow = _selectedIndex % _cardsPerRow;
      final targetIndex = nextRowIndex + columnInRow;
      if (targetIndex < movies.length) {
        _navigateToMovie(targetIndex);
      } else {
        _navigateToMovie(nextRowIndex);
      }
    }
  }

  void _navigateUp() {
    if (movies.isEmpty) return;
    final prevRowIndex = _selectedIndex - _cardsPerRow;
    if (prevRowIndex >= 0) {
      final columnInRow = _selectedIndex % _cardsPerRow;
      final targetIndex = prevRowIndex + columnInRow;
      if (targetIndex < movies.length) {
        _navigateToMovie(targetIndex);
      } else {
        _navigateToMovie(prevRowIndex);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCardsPerRow();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    TizenTVRemoteHandler.dispose();
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
      );
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
      body: Stack(
        children: [
          // Hide cursor on TV for better experience
          MouseRegion(
            cursor: SystemMouseCursors.none,
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
                  const SizedBox(height: 20),
                  const Text(
                    "Use D-pad to navigate",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
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
                : Padding(
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
                  return _buildMovieCard(index);
                },
              ),
            ),
          ),

          // Help overlay for Samsung TV
          if (_showDebug)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "📺 SAMSUNG TV MODE",
                      style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last Action: $_lastAction",
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "• D-pad: Navigate between movies",
                      style: TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                    const Text(
                      "• OK/Enter: Select movie",
                      style: TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                    const Text(
                      "• Numbers 1-9: Quick scroll",
                      style: TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                    const Text(
                      "• Return: Go back",
                      style: TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(int index) {
    final movie = movies[index];
    final isFocused = _selectedIndex == index;

    return GestureDetector(
      onTap: _openMovieDetail,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(isFocused ? 1.05 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: isFocused
              ? Border.all(color: const Color(0xFFFF6B00), width: 4)
              : null,
          boxShadow: isFocused
              ? [
            BoxShadow(
              color: const Color(0xFFFF6B00).withOpacity(0.8),
              blurRadius: 40,
              spreadRadius: 10,
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
                colors: isFocused
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
                        size: isFocused ? 100 : 80,
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
                            fontSize: isFocused ? 20 : 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isFocused ? 1 : 0,
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
    );
  }
}

// MovieDetailPage with same mouse-based navigation
class MovieDetailPage extends StatefulWidget {
  final Map<String, String> movie;
  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late VideoPlayerController videoController;
  bool _isLiveStream = false;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showControls = true;
  Timer? _controlsTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();

    // Initialize with video player navigation
    TizenTVRemoteHandler.init(
      onNavigate: _handleVideoNavigation,
      onSelect: _togglePlayPause,
      onBack: () => Navigator.pop(context),
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _navigationTimer?.cancel();
    videoController.dispose();
    TizenTVRemoteHandler.dispose();
    super.dispose();
  }

  void _handleVideoNavigation(int direction) {
    if (!_isInitialized || _isLiveStream) return;

    setState(() {
      _showControls = true;
    });
    _startControlsTimer();

    // Debounce rapid navigation
    _navigationTimer?.cancel();
    _navigationTimer = Timer(const Duration(milliseconds: 150), () {
      switch(direction) {
        case 0: // Up
          jumpSeconds(30);
          break;
        case 1: // Down
          jumpSeconds(-30);
          break;
        case 2: // Left
          jumpSeconds(-10);
          break;
        case 3: // Right
          jumpSeconds(10);
          break;
      }
    });
  }

  void _togglePlayPause() {
    if (videoController.value.isPlaying) {
      videoController.pause();
    } else {
      videoController.play();
    }
    _toggleControls();
    setState(() {});
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
    setState(() {});
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
      body: MouseRegion(
        cursor: SystemMouseCursors.none,
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
                                "D-pad: Seek • OK: Play/Pause",
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
                  height: 100,
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
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            "Samsung Remote: D-pad to seek (◀▶ 10s, ▲▼ 30s) • OK Play/Pause",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
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