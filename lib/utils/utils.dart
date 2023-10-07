import 'package:flutter/material.dart';

Future<void> showSnackMessage(BuildContext context, String message, dynamic action) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
      message, style: const TextStyle(color: Colors.white,),
    ),
    backgroundColor: const Color(0xFF2d3134),
    closeIconColor: Colors.white,
    elevation: 10,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(10),
    action: action == null ? null : SnackBarAction(
      textColor: Colors.blue, label: action[0], onPressed: () => action[1](),
    ),
  ));
}
