import 'package:flutter/material.dart';

const _agentMarkerColors = [
  Color(0xFF0284C7),
  Color(0xFFDB2777),
  Color(0xFF16A34A),
  Color(0xFF9333EA),
  Color(0xFFEA580C),
  Color(0xFF0D9488),
  Color(0xFFDC2626),
  Color(0xFF4F46E5),
  Color(0xFFCA8A04),
  Color(0xFFC026D3),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
];

class AgentMarker extends StatelessWidget {
  const AgentMarker({
    super.key,
    required this.name,
    required this.identity,
    this.isOnline,
    this.offlineColor,
  });

  final String name;
  final Object? identity;
  final bool? isOnline;
  final Color? offlineColor;

  Color get _color {
    final key = (identity ?? '').toString().trim().toUpperCase();
    if (key.isEmpty) return _agentMarkerColors[0];

    var hash = 0;
    for (final codeUnit in key.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
    }
    return _agentMarkerColors[hash % _agentMarkerColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final markerColor = isOnline == false ? offlineColor ?? _color : _color;
    final initials = name.trim().isEmpty
        ? '??'
        : name.trim().characters.take(2).toString().toUpperCase();
    final marker = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ],
    );

    if (isOnline == null) return marker;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          marker,
          Positioned(
            right: 1,
            bottom: 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline! ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
