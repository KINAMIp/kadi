# Tucheze Kadi – Visual & Interactive Blueprint

This blueprint outlines the presentation layer goals for Tucheze Kadi across splash, lobby, and in-game experiences. Use it to align design, animation, and audio decisions across platforms.

## Core Theme
- **Title:** Tucheze Kadi
- **Mood:** Modern African luxury casino vibe – bold reds, deep blacks, glowing golds, rhythmic energy.
- **Tagline:** *Play. Shine. Rule the Table.*
- Consistent black / red / white palette with emerald highlights and smooth motion.

## Screen Experiences

### 1. Splash Screen — “The Awakening”
- **Visuals:**
  - 3D fade-in of the KADI logo with red-white glow.
  - Rotating deck orbiting behind the logo.
  - Dark gradient background (black → crimson → onyx) with drifting dust particles and card silhouettes.
- **Animation Timeline:**
  1. **0–2s:** Cards swirl and converge into the central logo.
  2. **2–4s:** “Tucheze Kadi” text pulses with heartbeat glow.
  3. **4–5s:** Fade transition to the lobby.
- **Audio:**
  - Low whoosh for logo reveal.
  - Subtle card shuffle loop.
  - Bass heartbeat synced to the text pulse.

### 2. Lobby — “The Arena of Players”
- **Layout:**
  - Slight top-down view of a 3D poker table.
  - Background blur of glowing drifting cards.
  - Red banner with animated light sweep.
  - Rotating promo/leaderboard/rules tiles in the top-right corner.
- **UI Components:**
  - Frosted-glass input box with bright white text.
  - Buttons:
    - *Create Room* – crimson border, hover ripple.
    - *Join Room* – white border, pulsing glow.
    - *Quick Play* – gold accent fill.
- **Ambient Motion:**
  - Cards slide across the table periodically.
  - “Waiting for players…” text breathes softly.
- **Audio:**
  - Button tap with gentle ping.
  - Room creation fanfare sting.
  - Lo-fi Afro-beat lobby loop (~70 BPM).

### 3. Game Board — “Live Play Arena”
- **Layout Layers:**
  1. **Upper HUD:** Circular turn timer, active player badge, dynamic pop-outs (Cancel, Niko Kadi) with neon countdown ring.
  2. **Center Battlefield:** Large circular table, evenly spaced seats (2–7 players), center pile with animated shine, sliding & flipping cards.
  3. **Lower Hand Area:** Parallax fan of player cards, emerald “Pick” button when drawing is required.
- **Interactions:**
  - Real-time shuffle animation at round start.
  - Card plays feature glow trails, flips, and upward fades.
  - Cancel/Niko pop-outs burst into view, respecting personal visibility.
  - Seat halos highlight the current player.
- **Optional Voice:**
  - Mic toggle for in-app voice chat (WebRTC).
  - Optional voice cues (“Pick two!”, “Niko Kadi!”).

## Pop-Out System
- Pop-outs only appear for relevant players and auto-dismiss on interaction or timer expiry.
- **Timers:**

| Pop-Out        | Visible To       | Duration | Timeout Result            |
| -------------- | ---------------- | -------- | ------------------------- |
| Niko Kadi      | Eligible player  | 5 s      | Hide badge, continue play |
| Cancel Jump    | Other players    | 5 s      | Apply skip                |
| Cancel Kickback| Other players    | 5 s      | Apply reverse             |

- Pop-out timers pause the global turn countdown; play resumes immediately after resolution.

## Player Seating
- Circular arrangement around the center pile with adjustable seat size.
- Seat elements show name, profile image, card count, and active-player glow.
- Display Niko Kadi badge beneath the avatar upon declaration.

## Animation System
- Built with Rive/Flare, Lottie, or Flutter implicit animations.
- Standard behaviours:
  - Entry: scale + fade.
  - Exit: slide-down + blur.
  - Card shuffle: continuous 3D transform loop (~60 fps).
  - Screen transitions: fade → zoom → fade chain.

## Audio System
- Stereo mix with light reverb for immersion.
- **Events:**

| Event          | Sound Type | Description                     |
| -------------- | ---------- | ------------------------------- |
| Card shuffle   | Loop FX    | Crisp stereo shuffle, low mix.  |
| Card placed    | Short FX   | Flip + soft thud.               |
| Pick card      | FX         | Rising swoosh.                  |
| Button click   | UI tap     | Clean digital tap.              |
| Countdown      | Tick+drum  | Soft ticks, bass hit at zero.   |
| Timeout        | Alert      | Deep buzz with fading echo.     |
| Win / Lose     | Music cue  | Fanfare or minor-chord sting.   |
| Joker played   | Impact     | Heavy distorted sweep.          |
| “Niko Kadi”    | Voice line | Optional spoken call-out.       |

## Cross-Screen Continuity
- Shared background motion (card swirl + gradient) between splash, lobby, and board.
- Music cross-fades between screens without restarting.
- Subtle Tucheze Kadi watermark persists in a corner on all screens.

## Performance & Responsiveness
- Use GPU-accelerated effects (Impeller/Skia).
- Dynamically lower animation detail on low-end hardware.
- Limit frame rate when idle to save battery.
- Preload audio assets for zero-latency playback.

## Future Enhancements
- 3D avatars or emoji reactions tied to gameplay events.
- Fireworks burst on win.
- Camera orbit on Kickback reversals.
- Cloud sync for voice and match replays.
