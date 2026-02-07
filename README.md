# TinyChaton

![Icon](icon.png)

**TinyChaton** is a lightweight, modular chat enhancement addon for World of Warcraft (Retail). It provides essential chat features without the bloat of larger UI suites.

## Features

### 🛠 Chat Enhancement

- **Sticky Channels**: Remembers your last used channel when switching tabs.
- **Tab Cycle**: Cycle through chat channels using the `TAB` key.
- **Link Hover**: Show tooltips for items/spells/achievements when hovering over links in chat.
- **Short Channel Names**: Shorten channel names with multiple format options:
  - Short (e.g., "General" → "1", "Guild" → "G")
  - Number (e.g., "1", "2")
  - Number+Short (e.g., "1.G", "2.T")
  - Full (original names)

### 📋 Copy & History
- **Chat Copy**: Click timestamps to copy chat messages to the input box.
- **Chat History**: Saves local chat history per character and restores it upon login/reload.
- **Per-Channel Storage**: Configure which channels to store (Say, Guild, Party, Raid, World, etc.)

### 😄 Social & Emotes
- **Chat Emotes**: Supports standard raid icons and 50+ custom emotes in chat.
- **Chat Bubble Emotes**: Emotes also display in chat bubbles above characters.
- **Emote Panel**: Quick-access panel for inserting emotes (click the emote button on Shelf).
- **Auto Welcome**: Automatically send welcome messages to new Guild/Party/Raid members (configurable templates, cooldown support, requires leader for groups).

### 🔍 Filters & Highlights
- **Keyword Filtering**: Filter out spam based on keywords or player names (supports regex).
- **Keyword Highlighting**: Highlight specific words in chat with custom colors.
- **Repeat Filter**: Collapses consecutive identical messages to reduce spam.
- **Block List**: Block messages from specific players or containing specific keywords.

### 🎛 Shelf Toolbar
- **Quick Access Buttons**: Ready Check, Roll, Countdown, Emote Panel, Reload UI, Leave Group, Macro, Filter Toggle.
- **Channel Buttons**: Quick-switch between chat channels (Say, Party, Raid, Guild, World, LFG, Trade, etc.).
- **Dynamic Channels**: Auto-detects joined channels; configurable display modes (hide unjoined or mark inactive).
- **Customizable**: 4 visual styles (Modern, Legacy, Soft, Flat), adjustable size, spacing, scale, alpha.
- **Draggable**: Can be positioned above chat, below input, or custom dragged position.
- **Edit Mode Integration**: Works with Blizzard's Edit Mode for precise positioning.

### ⚙️ Configuration
- **Font Management**: Override chat font family, size, and outline.
- **Per-Character Settings**: Option to use separate settings for each character.
- **Profile Management**: Reset to defaults, clear history.

## Installation

1. Download the latest release.
2. Unzip the `TinyChaton` folder.
3. Place it in your WoW AddOns directory:  
   `World of Warcraft/_retail_/Interface/AddOns/`

## Usage

- **Open Settings**: Type `/tinychaton` or go to `Options -> AddOns -> TinyChaton`.
- **Toggle Emote Panel**: Click the emote button on the Shelf (if enabled).
- **Click to Copy**: Click any message timestamp to copy the full message to your chat input.
- **Drag Shelf**: Enter Edit Mode (from game menu) to drag and position the Shelf.

## Supported Channels

### System Channels
- Say, Yell, Whisper, Party, Raid, Instance, Guild, Officer

### Dynamic Channels (Auto-detected)
- World, LFG, Trade, Services, Beginner/Newbie, Local Defense, World Defense, General, Guild Recruitment

## Localization

TinyChaton is fully localized for:
- English (`enUS`)
- Simplified Chinese (`zhCN`)
- Traditional Chinese (`zhTW`)
- Korean (`koKR`)
- Russian (`ruRU`)
- German (`deDE`)

## License

MIT
