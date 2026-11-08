import 'dart:math' as math;
import 'package:app/shared/models/milestone.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

const _placeholderColor = Color(0xFFF0EDF8);

/// Miniatura de un hito: foto, vídeo (con indicador) o emoji de su categoría.
class MilestoneThumbnail extends StatelessWidget {
  final Milestone milestone;
  final double emojiSize;
  final int? memCacheWidth;

  const MilestoneThumbnail({
    super.key,
    required this.milestone,
    this.emojiSize = 44,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = _EmojiPlaceholder(
      emoji: milestone.displayEmoji,
      size: emojiSize,
    );

    final url = milestone.previewImageUrl;
    final image = url == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: memCacheWidth,
            fadeInDuration: const Duration(milliseconds: 250),
            placeholder: (_, _) => const ColoredBox(color: _placeholderColor),
            errorWidget: (_, _, _) => placeholder,
          );

    if (!milestone.isVideo) return image;

    // Vídeo: su fotograma de portada (si ya existe) con el botón de play.
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        const Center(child: PlayBadge()),
      ],
    );
  }
}

class _EmojiPlaceholder extends StatelessWidget {
  final String emoji;
  final double size;

  const _EmojiPlaceholder({required this.emoji, required this.size});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _placeholderColor,
      child: Center(
        child: ExcludeSemantics(
          child: Text(emoji, style: TextStyle(fontSize: size)),
        ),
      ),
    );
  }
}

/// Círculo translúcido con el icono de reproducir.
class PlayBadge extends StatelessWidget {
  final double size;
  const PlayBadge({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: size * 0.64,
      ),
    );
  }
}

// ─── Visor a pantalla completa ─────────────────────────────────────────────────

void openMilestoneMediaViewer(BuildContext context, Milestone milestone) {
  if (!milestone.hasMedia) return;
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _MediaViewer(milestone: milestone),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _MediaViewer extends StatefulWidget {
  final Milestone milestone;
  const _MediaViewer({required this.milestone});

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer>
    with SingleTickerProviderStateMixin {
  final _transformCtrl = TransformationController();
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..addListener(() => _transformCtrl.value = _zoomTween!.evaluate(_zoomCurve));
  late final _zoomCurve = CurvedAnimation(
    parent: _zoomAnim,
    curve: Curves.easeOutCubic,
  );
  Matrix4Tween? _zoomTween;

  ImageStream? _imageStream;
  late final _imageListener = ImageStreamListener((info, _) {
    if (!mounted) return;
    setState(() {
      _imageSize = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
    });
  });
  Size? _imageSize;

  Offset _doubleTapPosition = Offset.zero;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // La foto ocupa también la zona de las barras del sistema.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final m = widget.milestone;
    if (_imageStream == null && m.isImage) {
      // Mismo provider que CachedNetworkImage: comparte caché, sin descarga extra.
      _imageStream = CachedNetworkImageProvider(
        m.mediaUrl!,
      ).resolve(createLocalImageConfiguration(context));
      _imageStream!.addListener(_imageListener);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _imageStream?.removeListener(_imageListener);
    _zoomAnim.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  bool get _isZoomed => _transformCtrl.value.getMaxScaleOnAxis() > 1.01;

  void _animateTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _transformCtrl.value, end: target);
    _zoomAnim.forward(from: 0);
  }

  /// Doble toque: alterna entre la foto entera y la foto llenando la pantalla
  /// (centrada en el punto tocado).
  void _onDoubleTap(Size viewport) {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }

    final img = _imageSize;
    // Rectángulo que ocupa la foto con BoxFit.contain.
    final fitted = img == null
        ? Size(viewport.width, viewport.height)
        : applyBoxFit(BoxFit.contain, img, viewport).destination;
    final offset = Offset(
      (viewport.width - fitted.width) / 2,
      (viewport.height - fitted.height) / 2,
    );

    // Escala que hace que la foto cubra la pantalla; si ya casi la cubre
    // (misma proporción), se usa un zoom fijo.
    final fill = math.max(
      viewport.width / fitted.width,
      viewport.height / fitted.height,
    );
    final scale = (fill > 1.05 ? fill : 2.5).clamp(1.0, _maxScale);

    double axis(double tap, double view, double start, double length) {
      final scaled = length * scale;
      // Si la foto ampliada no llena este eje, se centra.
      if (scaled <= view) return (view - scaled) / 2 - start * scale;
      final t = tap - tap * scale; // mantiene fijo el punto tocado
      return t.clamp(view - (start + length) * scale, -start * scale);
    }

    final tap = _doubleTapPosition;
    _animateTo(
      Matrix4.identity()
        ..translateByDouble(
          axis(tap.dx, viewport.width, offset.dx, fitted.width),
          axis(tap.dy, viewport.height, offset.dy, fitted.height),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1),
    );
  }

  static const _maxScale = 5.0;

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: m.isVideo
                ? GestureDetector(
                    onTap: () => setState(() => _showControls = !_showControls),
                    child: _VideoPlayerView(
                      url: m.mediaUrl!,
                      showControls: _showControls,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      onTap: () =>
                          setState(() => _showControls = !_showControls),
                      onDoubleTapDown: (d) =>
                          _doubleTapPosition = d.localPosition,
                      onDoubleTap: () => _onDoubleTap(constraints.biggest),
                      child: InteractiveViewer(
                        transformationController: _transformCtrl,
                        minScale: 1,
                        maxScale: _maxScale,
                        onInteractionStart: (_) => _zoomAnim.stop(),
                        child: Hero(
                          tag: m.heroTag,
                          child: CachedNetworkImage(
                            imageUrl: m.mediaUrl!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (_, _) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          IgnorePointer(
            ignoring: !_showControls,
            child: AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _ViewerButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Cerrar',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ViewerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _VideoPlayerView extends StatefulWidget {
  final String url;
  final bool showControls;

  const _VideoPlayerView({required this.url, required this.showControls});

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  late final VideoPlayerController _ctrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl.initialize().then(
      (_) {
        if (!mounted) return;
        _ctrl
          ..setLooping(true)
          ..play();
        setState(() {});
      },
      onError: (_) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'No se pudo reproducir el vídeo',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_ctrl.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _ctrl.value.aspectRatio,
          child: VideoPlayer(_ctrl),
        ),
        ValueListenableBuilder(
          valueListenable: _ctrl,
          builder: (_, value, _) => AnimatedOpacity(
            opacity: widget.showControls || !value.isPlaying ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              iconSize: 56,
              tooltip: value.isPlaying ? 'Pausar' : 'Reproducir',
              onPressed: _togglePlay,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: VideoProgressIndicator(
              _ctrl,
              allowScrubbing: true,
              colors: const VideoProgressColors(playedColor: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
