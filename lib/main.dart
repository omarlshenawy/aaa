import 'dart:convert';
import 'dart:html' as html; // For web fullscreen
import 'package:chewie/chewie.dart';
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
      title: 'Flutter Movie Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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

  List<Map<String,String>> movies = [];
  bool isLoading = true;
  String? error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    fetchMovies();
  }
  @override
  void dispose() {
    _scrollController.dispose(); // dispose it when not needed
    super.dispose();
  }

  Future fetchMovies() async {
    try {
      final response = await http.get(
        Uri.parse(
            "https://raw.githubusercontent.com/omarlshenawy/vvv/refs/heads/main/m.json?t=${DateTime.now().millisecondsSinceEpoch}"
        ),
      );

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        movies = data.map((e) => Map<String,String>.from(e)).toList();
        setState(() { isLoading = false; });

      } else {
        setState(() {
          error = "Failed to load movies";
          isLoading = false;
        });
      }

    } catch(e){
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Movies",
          style: TextStyle(color: Colors.orange, fontSize: 26),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : Focus(
        autofocus: true,
        child: RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (event) {
            if (event is RawKeyDownEvent) {
              double offset = _scrollController.offset;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                offset = (offset + 150)
                    .clamp(0.0, _scrollController.position.maxScrollExtent);
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                offset = (offset - 150)
                    .clamp(0.0, _scrollController.position.maxScrollExtent);
              }
              _scrollController.animateTo(
                offset,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            }
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Card(
                  color: Colors.grey[900],
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Icon((movie["posterUrl"]=='1')? Icons.image : Icons.image_not_supported,size: 120, )
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  movie["title"] ?? "",
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Episode ${movie["episode"] ?? ""}",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MovieDetailPage(movie: movie),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // ---------- Floating Buttons ----------
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.large(
            heroTag: "scroll_up",
            onPressed: () {
              _scrollController.animateTo(
                (_scrollController.offset - 380)
                    .clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.arrow_upward, size: 40),
          ),

          const SizedBox(height: 30), // bigger space between buttons

          FloatingActionButton.large(
            heroTag: "scroll_down",
            onPressed: () {
              _scrollController.animateTo(
                (_scrollController.offset + 380)
                    .clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.arrow_downward, size: 40),
          ),
        ],
      ),
    );
  }
}


// ------------------- Movie Detail Page -------------------
// ------------------- Movie Detail Page -------------------
class MovieDetailPage extends StatefulWidget {
  final Map<String, String> movie;
  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {

  late VideoPlayerController videoController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.movie["videoUrl"]!),
      videoPlayerOptions:  VideoPlayerOptions(mixWithOthers: true),
    );

    videoController.initialize().then((_) {
      videoController.play();
      setState(() {});
    });

    videoController.addListener(() {
      setState(() {});
    });
  }

  // Fullscreen for browser
  void enterFullscreen() {
    final videoElement = html.document.querySelector('video');
    if (videoElement != null) {
      videoElement.requestFullscreen();
    }
  }

  // Jump function
  void jumpSeconds(int seconds) {
    final position = videoController.value.position;
    final duration = videoController.value.duration;

    Duration newPosition = position + Duration(seconds: seconds);

    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > duration) newPosition = duration;

    videoController.seekTo(newPosition);
  }

  // TV remote keys
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
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        jumpSeconds(-10);
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        jumpSeconds(10);
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

    final position = videoController.value.position;
    final duration = videoController.value.duration;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: Text(widget.movie["title"] ?? ""),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: enterFullscreen,
          )
        ],
      ),

      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: handleKey,
        child: Column(
          children: [

            // Video
            Expanded(
              child: Center(
                child: videoController.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: videoController.value.aspectRatio,
                  child: VideoPlayer(videoController),
                )
                    : const CircularProgressIndicator(),
              ),
            ),

            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [

                  Slider(
                    min: 0,
                    max: duration.inSeconds.toDouble(),
                    value: position.inSeconds
                        .clamp(0, duration.inSeconds)
                        .toDouble(),
                    activeColor: Colors.orange,
                    inactiveColor: Colors.grey,
                    onChanged: (value) {
                      videoController.seekTo(
                        Duration(seconds: value.toInt()),
                      );
                    },
                  ),

                  // Time row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatTime(position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          formatTime(duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      IconButton(
                        iconSize: 40,
                        color: Colors.white,
                        icon: const Icon(Icons.replay_10),
                        onPressed: () => jumpSeconds(-10),
                      ),

                      const SizedBox(width: 20),

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

                      const SizedBox(width: 20),

                      IconButton(
                        iconSize: 40,
                        color: Colors.white,
                        icon: const Icon(Icons.forward_10),
                        onPressed: () => jumpSeconds(10),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            )
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