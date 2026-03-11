import 'dart:convert';
import 'dart:html' as html; // For web fullscreen
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cors_image/flutter_cors_image.dart';
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

  @override
  void initState() {
    super.initState();
    fetchMovies();
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
          style: TextStyle(color: Colors.orange, fontSize: 32),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : ListView.builder(
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
              child: Card(
                color: Colors.grey[900],
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // align top
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomNetworkImage(
                          url: movie["posterUrl"] ?? "",
                          width: 150, // larger width
                          height: 180, // larger height
                          fit: BoxFit.cover,
                          webStorageCacheConfig: WebStorageCacheConfig(
                            enabled: true,
                            cacheExpirationHours: 168,
                            maxCacheSize: 100 * 1024 * 1024,
                          ),
                          errorWidget: const Icon(Icons.broken_image, size: 50),
                        ),
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
                                  fontSize: 24), // bigger font
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Episode ${movie["episode"] ?? ""}",
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 20), // bigger font
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ),
          );
        },
      ),
    );
  }
}


// ------------------- Movie Detail Page -------------------
class MovieDetailPage extends StatefulWidget {
  final Map<String,String> movie;
  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {

  late VideoPlayerController videoController;
  ChewieController? chewieController;

  @override
  void initState() {
    super.initState();

    videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.movie["videoUrl"]!),
    );

    videoController.initialize().then((_) {
      chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: false, // we handle true fullscreen manually
        showControls: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.orange,
          handleColor: Colors.orange,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white,
        ),
      );
      setState(() {});
    });
  }

  // True fullscreen using browser API
  void enterFullscreen() {
    final videoElement = html.document.querySelector('video');
    if (videoElement != null) {
      if (videoElement.requestFullscreen != null) {
        videoElement.requestFullscreen();
      } else if ((videoElement as dynamic).webkitRequestFullscreen != null) {
        (videoElement as dynamic).webkitRequestFullscreen();
      } else if ((videoElement as dynamic).mozRequestFullScreen != null) {
        (videoElement as dynamic).mozRequestFullScreen();
      }
    }
  }

  @override
  void dispose() {
    videoController.dispose();
    chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.movie["title"] ?? ""),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 28),
            onPressed: enterFullscreen,
          )
        ],
      ),
      body: Center(
        child: chewieController != null &&
            chewieController!.videoPlayerController.value.isInitialized
            ? Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: chewieController!.videoPlayerController.value.aspectRatio,
            child: Chewie(controller: chewieController!),
          ),
        )
            : const CircularProgressIndicator(),
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