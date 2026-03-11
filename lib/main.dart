import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;

// JS interop
import 'package:js/js.dart';

@JS('Hls')
class HlsJs {
  external factory HlsJs();
  external void loadSource(String url);
  external void attachMedia(dynamic video);
  external bool get isSupported;
}

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

// ---------------- Movie List Page ----------------
class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key});

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  List<Map<String, String>> movies = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchMovies();
  }

  Future fetchMovies() async {
    try {
      final response = await http.get(Uri.parse(
          "https://raw.githubusercontent.com/omarlshenawy/vvv/refs/heads/main/m.json?t=${DateTime.now().millisecondsSinceEpoch}"));

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
          : ListView.builder(
        padding:
        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    movie["posterUrl"] ?? "",
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 180,
                        color: Colors.grey,
                        child: const Icon(Icons.movie,
                            color: Colors.white70, size: 50),
                      );
                    },
                  ),
                ),
                title: Text(
                  movie["title"] ?? "",
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                subtitle: Text(
                  "Episode ${movie["episode"] ?? ""}",
                  style: const TextStyle(color: Colors.white70),
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
    );
  }
}

// ---------------- Movie Detail Page ----------------
class MovieDetailPage extends StatefulWidget {
  final Map<String, String> movie;
  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  late String viewId;

  @override
  void initState() {
    super.initState();

    final videoUrl = widget.movie["videoUrl"]!;

    if (kIsWeb && videoUrl.endsWith('.m3u8')) {
      // Web HLS
      viewId = 'video-${widget.movie["title"]}';

      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(viewId, (int viewIdInt) {
        final video = html.VideoElement()
          ..controls = true
          ..autoplay = true
          ..style.width = '100%'
          ..style.height = '100%';

        // Use HlsJs via JS interop
        final hls = HlsJs();
        if (hls.isSupported) {
          hls.loadSource(videoUrl);
          hls.attachMedia(video);
        } else {
          video.src = videoUrl; // fallback for Safari
        }

        return video;
      });
    } else {
      // Mobile/TV or MP4
      _videoController = VideoPlayerController.network(videoUrl)
        ..initialize().then((_) {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
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
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = widget.movie["videoUrl"]!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.movie["title"] ?? ""),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: kIsWeb && videoUrl.endsWith('.m3u8')
            ? SizedBox(
          width: 800,
          height: 450,
          child: HtmlElementView(viewType: viewId),
        )
            : (_chewieController != null &&
            _chewieController!.videoPlayerController.value.isInitialized
            ? Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: _chewieController!
                .videoPlayerController.value.aspectRatio,
            child: Chewie(controller: _chewieController!),
          ),
        )
            : const CircularProgressIndicator()),
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