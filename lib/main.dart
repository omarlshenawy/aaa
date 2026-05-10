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

// Samsung Tizen TV Remote Handler
class TizenTVRemoteHandler {
  static late Function(String key, int keyCode) _onKeyPress;
  static bool _initialized = false;

  static void init(Function(String key, int keyCode) onKeyPress) {
    _onKeyPress = onKeyPress;

    if (_initialized) return;
    _initialized = true;

    // Register JavaScript for Tizen TV
    js.context.callMethod('eval', ['''
      (function() {
        console.log('Tizen TV Remote Handler Initializing...');
        
        // Check if running on Tizen
        var isTizen = typeof tizen !== 'undefined';
        
        // Key code mapping for Samsung TVs
        var keyMap = {
          37: 'ArrowLeft',
          38: 'ArrowUp', 
          39: 'ArrowRight',
          40: 'ArrowDown',
          13: 'Enter',
          10009: 'Back',  // Samsung Return key
          461: 'Back',    // Alternative back key
          457: 'Menu',
          403: 'Red',
          404: 'Green', 
          405: 'Yellow',
          406: 'Blue',
          427: 'ChannelUp',
          428: 'ChannelDown',
          448: 'VolumeDown',
          447: 'VolumeUp',
          415: 'Play',
          411: 'Pause',
          503: 'PlayPause',
          412: 'Rewind',
          417: 'FastForward',
          10000: 'Enter',  // Samsung OK button often uses this
          10001: 'Menu',
          10002: 'Back'
        };
        
        // Register additional keys with Tizen API if available
        if (isTizen && tizen.tvinputdevice) {
          console.log('Tizen TV Input Device API available');
          
          // Get supported keys and register them
          try {
            var supportedKeys = tizen.tvinputdevice.getSupportedKeys();
            console.log('Supported keys:', supportedKeys);
            
            // Register common keys
            var keysToRegister = [
              'ChannelUp', 'ChannelDown', 'VolumeUp', 'VolumeDown',
              'ColorF0Red', 'ColorF1Green', 'ColorF2Yellow', 'ColorF3Blue',
              'Play', 'Pause', 'Stop', 'Rewind', 'FastForward'
            ];
            
            for (var i = 0; i < keysToRegister.length; i++) {
              try {
                tizen.tvinputdevice.registerKey(keysToRegister[i]);
                console.log('Registered key:', keysToRegister[i]);
              } catch(e) {
                console.log('Failed to register key:', keysToRegister[i], e);
              }
            }
          } catch(e) {
            console.log('Error registering keys:', e);
          }
        }
        
        // Main keydown event listener
        document.addEventListener('keydown', function(event) {
          var keyCode = event.keyCode || event.which;
          var keyName = keyMap[keyCode] || 'Unknown_' + keyCode;
          
          console.log('Key pressed - Code:', keyCode, 'Name:', keyName);
          
          // Call Flutter handler if registered
          if (window.tizenKeyHandler) {
            window.tizenKeyHandler(keyName, keyCode);
          }
          
          // Prevent default browser behavior for TV keys
          var blockKeys = [37,38,39,40,13,10009,461,427,428,447,448];
          if (blockKeys.indexOf(keyCode) !== -1) {
            event.preventDefault();
            return false;
          }
        });
        
        // Also listen for keyup to prevent double events
        document.addEventListener('keyup', function(event) {
          var blockKeys = [37,38,39,40,13,10009,461];
          if (blockKeys.indexOf(event.keyCode) !== -1) {
            event.preventDefault();
            return false;
          }
        });
        
        console.log('Tizen TV Remote Handler Ready');
        
        // Log environment info
        console.log('Platform:', navigator.platform);
        console.log('User Agent:', navigator.userAgent);
        console.log('Tizen available:', isTizen);
      })();
    ''']);

    // Register callback
    js.context['tizenKeyHandler'] = (String key, int keyCode) {
      _onKeyPress(key, keyCode);
    };
  }

  static void dispose() {
    js.context.callMethod('eval', ['''
      if (window.tizenKeyHandler) {
        delete window.tizenKeyHandler;
      }
    ''']);
    _initialized = false;
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
  String _lastKey = "None";
  int _lastKeyCode = 0;
  String _tizenStatus = "Checking...";
  bool _showDebug = true;

  @override
  void initState() {
    super.initState();
    fetchMovies();

    // Initialize Tizen TV remote handler
    TizenTVRemoteHandler.init(_handleTVKeyPress);

    // Check if running on Tizen
    _checkTizenEnvironment();
  }

  void _checkTizenEnvironment() {
    // Use JavaScript to check Tizen environment
    js.context.callMethod('eval', ['''
      (function() {
        var status = 'Not Tizen';
        if (typeof tizen !== 'undefined') {
          status = 'Tizen TV Detected!';
        } else if (navigator.userAgent.indexOf('Tizen') !== -1) {
          status = 'Tizen Browser Detected';
        } else {
          status = 'Standard Browser';
        }
        if (window.tizenKeyHandlerStatus) {
          window.tizenKeyHandlerStatus(status);
        }
      })();
    ''']);

    js.context['tizenKeyHandlerStatus'] = (String status) {
      setState(() {
        _tizenStatus = status;
      });
    };
  }

  void _handleTVKeyPress(String key, int keyCode) {
    print("Tizen TV Key: $key (Code: $keyCode)");

    setState(() {
      _lastKey = key;
      _lastKeyCode = keyCode;
    });

    // Handle navigation based on key
    switch(key) {
      case 'ArrowRight':
        _navigateToMovie(_selectedIndex + 1);
        break;
      case 'ArrowLeft':
        _navigateToMovie(_selectedIndex - 1);
        break;
      case 'ArrowDown':
      case 'ChannelDown':
        _navigateDown();
        break;
      case 'ArrowUp':
      case 'ChannelUp':
        _navigateUp();
        break;
      case 'Enter':
        _openMovieDetail();
        break;
      case 'Back':
      // Optional: handle back button
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        break;
      case 'PlayPause':
      case 'Play':
      case 'Pause':
      // These will be handled in video player
        print('Media key pressed: $key');
        break;
      default:
        print('Unhandled key: $key');
    }
  }

  void _navigateDown() {
    final totalCards = movies.length;
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

  void _navigateUp() {
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
          // Main content
          isLoading
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
                Text(
                  "Tizen Status: $_tizenStatus",
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
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

          // Debug overlay for Samsung TV
          if (_showDebug)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 250),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "📺 SAMSUNG TIZEN DEBUG",
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Status: $_tizenStatus",
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last Key: $_lastKey (Code: $_lastKeyCode)",
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Use D-pad to navigate • OK to select",
                      style: TextStyle(color: Colors.white38, fontSize: 9),
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

// MovieDetailPage - Keep from previous version with same Tizen handling
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

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    TizenTVRemoteHandler.init(_handleTVKeyPress);
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    videoController.dispose();
    super.dispose();
  }

  void _handleTVKeyPress(String key, int keyCode) {
    print("Video Player Key: $key (Code: $keyCode)");

    switch(key) {
      case 'Enter':
        if (videoController.value.isPlaying) {
          videoController.pause();
        } else {
          videoController.play();
        }
        _toggleControls();
        setState(() {});
        break;
      case 'ArrowLeft':
      case 'Rewind':
        if (!_isLiveStream) jumpSeconds(-10);
        break;
      case 'ArrowRight':
      case 'FastForward':
        if (!_isLiveStream) jumpSeconds(10);
        break;
      case 'ArrowDown':
      case 'ChannelDown':
        if (!_isLiveStream) jumpSeconds(-30);
        break;
      case 'ArrowUp':
      case 'ChannelUp':
        if (!_isLiveStream) jumpSeconds(30);
        break;
      case 'Back':
        Navigator.pop(context);
        break;
      case 'PlayPause':
      case 'Play':
      case 'Pause':
        if (videoController.value.isPlaying) {
          videoController.pause();
        } else {
          videoController.play();
        }
        _toggleControls();
        setState(() {});
        break;
    }
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
      body: GestureDetector(
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
                          "Samsung Remote: ▲▼ (30s)  ◀▶ (10s)  OK (Play/Pause)",
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