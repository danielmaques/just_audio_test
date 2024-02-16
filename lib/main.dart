import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '/common.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'toca_source.dart';
import 'toca_source2.dart';
import 'just_test.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    ambiguate(WidgetsBinding.instance)!.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });
    // Try to load audio from a source and catch any errors.
    try {
      await loadPlayer();
      _player.play();
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  Future<void> loadPlayer() async {
    try {
      String url =
          "https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3";
      String url2 =
          "https://tla-uc.s3.amazonaws.com/3/d/4044/4077/c001.tla?AWSAccessKeyId=AKIARC3XBLPWYGY7T6GK&Expires=1708112770&Signature=Si3zf6Vy6anI1jL7p5uCSutMlkg%3D";
      final myAudioSource = TocaSource2(url, "Q1VaaztCeDFJb0V3ZVBsMg==");

      final cap1 = DecriptedAudioSource(
          Uri.parse(
              "https://tla-uc.s3.amazonaws.com/3/d/4044/4077/c001.tla?AWSAccessKeyId=AKIARC3XBLPWYGY7T6GK&Expires=1708121775&Signature=l6vc2eOyqhT1Ygql9G2V3tbschE%3D"),
          "Q1VaaztCeDFJb0V3ZVBsMg==");
      final cap2 = DecriptedAudioSource(
          Uri.parse(
              "https://tla-uc.s3.amazonaws.com/3/d/4044/4077/c002.tla?AWSAccessKeyId=AKIARC3XBLPWYGY7T6GK&Expires=1708143377&Signature=mZp0GpbonhDb3oTpvzMJG0MCI0E%3D"),
          "Q1VaaztCeDFJb0V3ZVBsMg==");
      final cap3 = DecriptedAudioSource(
          Uri.parse(
              "https://tla-uc.s3.amazonaws.com/3/d/4044/4077/c003.tla?AWSAccessKeyId=AKIARC3XBLPWYGY7T6GK&Expires=1708164977&Signature=wuzR%2B95kCBrLLQeYrMQa%2B%2FnTRos%3D"),
          "Q1VaaztCeDFJb0V3ZVBsMg==");
      final cap4 = DecriptedAudioSource(
          Uri.parse(
              "https://tla-uc.s3.amazonaws.com/3/d/4044/4077/c004.tla?AWSAccessKeyId=AKIARC3XBLPWYGY7T6GK&Expires=1708186577&Signature=bHdLPbeLo7ctG5%2FufDK%2F88hcs5o%3D"),
          "Q1VaaztCeDFJb0V3ZVBsMg==");

      List<AudioSource> entireBook = [];
      entireBook.add(cap1);
      entireBook.add(cap2);
      entireBook.add(cap3);
      entireBook.add(cap4);
      final source = ConcatenatingAudioSource(children: entireBook);

      //await _player.setUrl(url);
      await _player.setAudioSource(source);
      // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac
      //await _player.setAudioSource(AudioSource.uri(Uri.parse(
      //    "https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3")));
    } catch (e) {
      print("Error loading audio source: $e");
      //loadPlayer();
    }
  }

  @override
  void dispose() {
    ambiguate(WidgetsBinding.instance)!.removeObserver(this);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display play/pause button and volume/speed sliders.
              ControlButtons(_player),
              // Display seek bar. Using StreamBuilder, this widget rebuilds
              // each time the position, buffered position or duration changes.
              StreamBuilder<PositionData>(
                stream: _positionDataStream,
                builder: (context, snapshot) {
                  final positionData = snapshot.data;
                  return SeekBar(
                    duration: positionData?.duration ?? Duration.zero,
                    position: positionData?.position ?? Duration.zero,
                    bufferedPosition:
                        positionData?.bufferedPosition ?? Duration.zero,
                    onChangeEnd: _player.seek,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        /// This StreamBuilder rebuilds whenever the player state changes, which
        /// includes the playing/paused state and also the
        /// loading/buffering/ready state. Depending on the state we show the
        /// appropriate button or loading indicator.
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero),
              );
            }
          },
        ),
        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}
