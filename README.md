# LimiterTest
This is a Godot 4 project that implements a basic synth that feeds itself into a limiter. The purpose of this is to demonstrate how limiters work. They are not waveshapers; they're more like compressors, but weird ones.

The main example is Main.gd. It is a correct, fast limiter.

If Main.gd is too hard to understand, read MainSimple.gd first. It is a limiter that only has a release curve, with no sustain or attack. This makes it produce slightly distorted output. After MainSimple.gd, read MainNoAttack.gd. It is a limiter with release and sustain, but no attack. Having sustain allows it to be even less distorted, but sometimes it still crushes the leading edge of waveforms. Main.gd adds attack to MainNoAttack.gd, allowing it to have virtually no distortion at all.

The other .gd files (MainSlow.gd, MainHacky.gd, and MainOld.gd) are only here to serve as examples on how *not* to implement a limiter. MainSlow.gd uses an O(n) sustain analysis algorithm instead of an O(sqrt(n)) one. MainOld.gd and MainHacky.gd implement bad sustain algorithms are common in audio visualization but that don't work for limiting.

## Example

See [out__a_asdf.wav](out__a_asdf.wav).

## License

Public domain! (Creative Commons Zero)
