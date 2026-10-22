import 'package:flutter/material.dart';
import 'package:tapaolah/utilis/dimensions.dart';

class ExpandableTextWidget extends StatefulWidget {
  final String text;
  final double size;
  final Color? textColor; // ✅ 新增 textColor 参数

  const ExpandableTextWidget({
    super.key,
    required this.text,
    this.size = 0,
    this.textColor, // ✅ 初始化
  });

  @override
  State<ExpandableTextWidget> createState() => _ExpandableTextWidgetState();
}

class _ExpandableTextWidgetState extends State<ExpandableTextWidget> {
  late String firstHalf;
  late String secondHalf;

  bool hiddenText = true;
  final int maxCharCount = 150;

  @override
  void initState() {
    super.initState();
    if (widget.text.length > maxCharCount) {
      firstHalf = widget.text.substring(0, maxCharCount);
      secondHalf = widget.text.substring(maxCharCount);
    } else {
      firstHalf = widget.text;
      secondHalf = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.textColor ?? Colors.black; // ✅ 默认颜色黑色

    return Container(
      margin: EdgeInsets.only(top: Dimensions.height10),
      child:
          secondHalf.isEmpty
              ? Text(
                firstHalf,
                style: TextStyle(
                  fontSize: Dimensions.font16,
                  color: color,
                  height: 1.5,
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hiddenText ? (firstHalf + "...") : (firstHalf + secondHalf),
                    style: TextStyle(
                      fontSize: Dimensions.font16,
                      color: color,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        hiddenText = !hiddenText;
                      });
                    },
                    child: Row(
                      children: [
                        Text(
                          hiddenText ? "Show more" : "Show less",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: Dimensions.font12,
                          ),
                        ),
                        Icon(
                          hiddenText
                              ? Icons.arrow_drop_down
                              : Icons.arrow_drop_up,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
