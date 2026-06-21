with open('lib/views/squads/squads_explorer_screen.dart', 'r') as f:
    content = f.read()

# Replace the wrong ending
wrong_ending = """          },
        ),
    ],
  );
}
}
"""

correct_ending = """          },
        ),
        ],
      ),
    );
  }
}
"""

if wrong_ending in content:
    content = content.replace(wrong_ending, correct_ending)
    with open('lib/views/squads/squads_explorer_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed ending")
else:
    print("Wrong ending not found")
