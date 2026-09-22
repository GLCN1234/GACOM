# Sound files needed here

The sound system is fully wired and ready — it just needs the actual
audio files dropped into this folder with these exact names:

- tap.mp3      — light tap/click feedback
- correct.mp3  — correct answer / successful action
- wrong.mp3    — wrong answer / miss / buzz
- win.mp3      — round or game won
- lose.mp3     — round or game lost
- bgm.mp3      — background music loop (kept quiet, volume 0.35)

Until these exist, every game runs completely normally with no sound —
missing files are handled silently, on purpose, so nothing crashes.
Short, simple sounds work best (under 1-2 seconds for sfx). Once you
add real files here with these exact names, they'll start playing
automatically — no code changes needed.
