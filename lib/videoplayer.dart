import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerPage extends StatefulWidget {
  final int videoId;

  const VideoPlayerPage({
    super.key,
    required this.videoId,
    required Uri videoUrl,
  });

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with TickerProviderStateMixin {
  int likes = 0;
  int dislikes = 0;
  int views = 0;
  String description = '';
  late VideoPlayerController _controller;
  late ChewieController _chewieController;
  late PanelController _panelController;
  late TabController _tabController;
  String truncatedDescription = '';
  String name = '';
  bool _isInitialized = false;
  String channelName = '';
  String channelAvatar = '';
  bool _isPlayPauseVisible = false;
  Timer? _playPauseTimer;
  int duration = 0;
  Comments comments = Comments();

  @override
  void initState() {
    super.initState();
    _panelController = PanelController();
    _tabController = TabController(length: 2, vsync: this);
    _fetchVideoData();
    _fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _playPauseTimer?.cancel();
    _chewieController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _togglePlayPauseVisibility() {
    setState(() {
      _isPlayPauseVisible = !_isPlayPauseVisible;
    });
  }

  void _startPlayPauseTimer() {
    _playPauseTimer = Timer(const Duration(seconds: 3), () {
      if (_isPlayPauseVisible) {
        _togglePlayPauseVisibility();
      }
    });
  }

  void _resetPlayPauseTimer() {
    _playPauseTimer?.cancel();
    _startPlayPauseTimer();
  }

  Future<void> _fetchVideoData() async {
    try {
      final response = await http.get(
          Uri.parse('https://www.tilvids.com/api/v1/videos/${widget.videoId}'));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          likes = responseData['likes'] ?? 0;
          dislikes = responseData['dislikes'] ?? 0;
          views = responseData['views'] ?? 0;
          description = responseData['description'] ?? '';
          truncatedDescription = responseData['truncatedDescription'] ?? '';
          duration = responseData['duration'];
          name = responseData['name'];
          channelName = responseData['channel']['name'];
          if (responseData['channel']['avatars'].isNotEmpty) {
            channelAvatar = responseData['channel']['avatars'][1]['path'];
          }
        });

        final playlistUrl =
            responseData['streamingPlaylists'][0]['playlistUrl'];
        _controller = VideoPlayerController.networkUrl(Uri.parse(playlistUrl))
          ..initialize().then((_) {
            setState(() {
              _isInitialized = true;
              _startPlayPauseTimer();
            });
          });
        _chewieController = ChewieController(
          allowFullScreen: true,
          allowedScreenSleep: true,
          allowMuting: true,
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
            DeviceOrientation.portraitDown,
            DeviceOrientation.portraitUp
          ],
          videoPlayerController: _controller,
          autoInitialize: true,
          autoPlay: true,
          showControls: true,
        );
        _chewieController.addListener(() {
          if (_chewieController.isFullScreen) {
            SystemChrome.setPreferredOrientations(
              [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight
              ],
            );
          } else {
            SystemChrome.setPreferredOrientations(
              [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
            );
          }
        });
      } else {
        throw Exception('Failed to fetch video data: ${response.statusCode}');
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching video data: $error');
      }
    }
  }

  Future<void> _fetchComments() async {
    try {
      final response = await http.get(Uri.parse(
          'https://www.tilvids.com/api/v1/videos/${widget.videoId}/comment-threads'));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          comments.total = responseData['total'];

          for (var item in responseData['data']) {
            var comment = CommentItem();
            comment.id = item['id'];
            comment.threadId = item['threadId'];
            comment.url = Uri.parse(item['url']);
            comment.inReplyToCommentId = item['inReplyToCommentId'];
            comment.videoId = item['videoId'];
            comment.createdAt = item['createdAt'];
            comment.updatedAt = item['updatedAt'];
            comment.deletedAt = item['deletedAt'];
            comment.isDeleted = item['isDeleted'];
            comment.totalRepliesFromVideoAuthor =
                item['totalRepliesFromVideoAuthor'];
            comment.totalReplies = item['totalReplies'];
            comment.text = item['text'];
            comment.account.url = item['account']['url'];
            comment.account.name = item['account']['name'];
            comment.account.host = item['account']['host'];
            comment.account.avatars = item['account']['avatars'];
            comment.account.avatar = item['account']['avatar'];

            comments.comments.add(comment);
          }
        });
      } else {
        throw Exception('Failed to fetch comments: ${response.statusCode}');
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error fetching comments: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: _resetPlayPauseTimer,
          child: _isInitialized
              ? SlidingUpPanel(
                  controller: _panelController,
                  minHeight: 0,
                  snapPoint: 0.7,
                  maxHeight: 700,
                  color: const Color(0xFF000000), // TODO: Use global theme
                  header: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  panel: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 32, 8, 8),
                    child: SingleChildScrollView(
                      child: Text(
                        description,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _controller.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: Stack(
                                alignment: FractionalOffset.bottomCenter +
                                    const FractionalOffset(-0.1, -0.1),
                                children: [
                                  Chewie(controller: _chewieController)
                                ],
                              ))
                          : Container(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: ExpansionTile(
                              title: Text(
                                name,
                                overflow: TextOverflow.fade,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                truncatedDescription,
                                overflow: TextOverflow.fade,
                                maxLines: 1,
                                softWrap: false,
                              ),
                              onExpansionChanged: (state) {
                                state
                                    ? _panelController.open()
                                    : _panelController.close();
                              },
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 7.0)),
                          const Icon(Icons.thumb_up_outlined),
                          const SizedBox(width: 6),
                          Text('$likes'),
                          const SizedBox(width: 20),
                          const Icon(Icons.thumb_down_outlined),
                          const SizedBox(width: 6),
                          Text('$dislikes'),
                          const SizedBox(width: 20),
                          const Text('•'),
                          const SizedBox(width: 8),
                          Text('$views Views'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TabBar(controller: _tabController, tabs: [
                        Tab(text: "Comments (${comments.total})"),
                        const Tab(text: "Recommended"),
                      ]),
                      Expanded(
                        child: TabBarView(
                            controller: _tabController,
                            children: const [
                              Text("Comments"),
                              Text("Recommended"),
                            ]),
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class Comments {
  int total = 0;
  List<CommentItem> comments = [];
}

class CommentItem {
  int? id;
  int? threadId;
  Uri? url;
  int? inReplyToCommentId;
  int? videoId;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? deletedAt;
  bool isDeleted = false;
  int totalRepliesFromVideoAuthor = 0;
  int totalReplies = 0;
  Commenter account = Commenter();
  String text = '';
}

class Commenter {
  Uri? url;
  String name = '';
  String host = '';
  dynamic avatars;
  dynamic avatar;
}
