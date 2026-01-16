# JustTheRecipe

A clean, distraction-free recipe extraction app for iOS.

## Overview

JustTheRecipe extracts recipes from cooking websites, removing ads, pop-ups, and life stories to give you just the ingredients and instructions you need.

**Key Features:**
- 🍳 Extract recipes from any URL with structured data (JSON-LD) or heuristic fallback
- 📴 Fully offline after saving - no internet required to cook
- 🔒 Privacy-first - all processing happens on-device
- 🌙 Dark mode and Dynamic Type support
- ♿ Full VoiceOver accessibility
- 👨‍🍳 Cooking mode with step-by-step navigation and screen-awake

## Requirements

- iOS 26.0+
- Xcode 16.0+
- Swift 6.0

## Architecture

```
JustTheRecipe/
├── App/                    # App entry point
├── Models/                 # Recipe, RecipeDraft
├── Views/                  # SwiftUI views
├── Services/
│   ├── Extraction/         # JSON-LD and heuristic parsers
│   ├── Networking/         # URL fetching, error handling
│   └── Normalization/      # Content cleanup
├── Persistence/            # SwiftData container
└── Utilities/              # Helpers, logging, validation
```

## Extraction Pipeline

1. **Fetch** - Download HTML with proper headers and encoding detection
2. **Parse** - Try JSON-LD first (high confidence), fall back to heuristic HTML parsing
3. **Normalize** - Clean up content, standardize fractions, remove fluff
4. **Review** - User can edit before saving
5. **Save** - Persist to SwiftData for offline access

## Testing

Unit tests cover:
- JSON-LD parsing (various schema formats)
- Heuristic HTML parsing
- Content normalization
- Persistence operations
- Error handling

Run tests with `⌘U` in Xcode.

## Privacy

- No analytics, tracking, or cloud services
- No user accounts
- All data stored locally on device
- Network requests only to fetch recipe URLs

## License

Proprietary - All rights reserved.

## Support

Contact: [your-email@example.com]
