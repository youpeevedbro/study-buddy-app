import 'package:flutter/material.dart';

class SquareButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;

  const SquareButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: ElevatedButton(
        onPressed: () {
          print("Square button pressed!");
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0), // removes roundness
          ),
          padding: EdgeInsets.all(2), // controls the size
          maximumSize: const Size(150, 150), // fixed square size
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white, // text/icon color
          elevation: 20,
          shadowColor: Colors.orangeAccent,
        ),
        child: Text(text, textAlign: TextAlign.left, style: const TextStyle(fontFamily: "SuperLobster", fontSize: 30),),
      ),
    );
  }
}