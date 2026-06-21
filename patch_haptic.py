import re

# 1. Update post_card.dart (Like action)
with open('lib/widgets/cards/post_card.dart', 'r') as f:
    content = f.read()

if "import 'package:flutter/services.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")

old_like = """    try {
      if (isLiked) {
        await _firestoreService.unlikePost(widget.post.id, user.id);"""

new_like = """    try {
      HapticFeedback.lightImpact(); // Haptic feedback on like
      if (isLiked) {
        await _firestoreService.unlikePost(widget.post.id, user.id);"""

content = content.replace(old_like, new_like)

with open('lib/widgets/cards/post_card.dart', 'w') as f:
    f.write(content)

# 2. Update home_screen.dart (Tab changes)
with open('lib/views/home/home_screen.dart', 'r') as f:
    content = f.read()

if "import 'package:flutter/services.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")

old_tab = """  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });"""

new_tab = """  void _onItemTapped(int index) {
    HapticFeedback.selectionClick(); // Premium feel on navigation
    setState(() {
      _selectedIndex = index;
    });"""

content = content.replace(old_tab, new_tab)

with open('lib/views/home/home_screen.dart', 'w') as f:
    f.write(content)

# 3. Update chat_screen.dart (Send message)
with open('lib/views/chat/chat_screen.dart', 'r') as f:
    content = f.read()

if "import 'package:flutter/services.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")

old_send = """  void _sendMessage() {
    if (_messageController.text.trim().isEmpty && _attachedMedia == null) return;"""

new_send = """  void _sendMessage() {
    if (_messageController.text.trim().isEmpty && _attachedMedia == null) return;
    HapticFeedback.mediumImpact(); // Premium feel when sending message"""

content = content.replace(old_send, new_send)

with open('lib/views/chat/chat_screen.dart', 'w') as f:
    f.write(content)

print("Haptic feedback added successfully.")
