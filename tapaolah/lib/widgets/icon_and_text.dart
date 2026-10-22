import 'package:flutter/material.dart';
import 'package:tapaolah/utilis/dimensions.dart';
import 'package:tapaolah/widgets/small_text.dart';

class IconAndTextWidget extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;
  final Color? color; // ✅ 新增颜色参数
  final double iconSize;
  final double? textSize;

  const IconAndTextWidget({
    Key? key,
    required this.icon,
    required this.text,
    required this.iconColor,
    this.color,
    this.iconSize = 24,
    this.textSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        SizedBox(width: Dimensions.width5),
        Flexible(
          child: SmallText(
            text: text,
            size: textSize ?? Dimensions.font12,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }
}
