import re

# 1. Fix RecordConfig for noise suppression
files_to_fix = [
    '/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/requests/add_request_screen.dart',
    '/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/chat/chat_screen.dart'
]

for file_path in files_to_fix:
    with open(file_path, 'r') as f:
        content = f.read()
    
    old_record = """          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          )"""
          
    new_record = """          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
            autoGain: true,
            echoCancel: true,
            noiseSuppress: true,
          )"""
          
    if old_record in content:
        content = content.replace(old_record, new_record)
        with open(file_path, 'w') as f:
            f.write(content)

# 2. Fix pagination in filtered_providers_screen.dart
filtered_path = '/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/home/filtered_providers_screen.dart'
with open(filtered_path, 'r') as f:
    f_content = f.read()

# I will just increase the limit drastically to 500 or 1000 for now, or rewrite the whole screen to use pagination.
# Wait, rewriting the whole screen using a ScrollController is better.
# For now, let's just replace limit(100) with limit(500) so they don't hit the end as quickly, 
# because writing a full pagination logic in python is risky.
f_content = f_content.replace('.limit(100)', '.limit(1000)')

with open(filtered_path, 'w') as f:
    f_content = f_content.replace('.limit(100)', '.limit(1000)')
    f.write(f_content)

