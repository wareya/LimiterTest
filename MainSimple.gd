extends Node2D

class Limiter extends RefCounted:
    var pre_gain := 4.0
    var post_gain := 1.0
    
    var srate := 44100.0
    var limit := 0.25
    
    var release := 0.04
    var release_memory := 0.0
    
    var amp := 1.0
    var ref_amp := 1.0
    
    func push_sample(sample : float) -> float:
        sample *= pre_gain
        
        # do the release curve
        release_memory = max(0.0, release_memory - 1.0 / srate)
        if release > 0.0:
            amp = lerp(ref_amp, 1.0, 1.0 - release_memory / release)
        else:
            amp = 1.0
        
        # reset sustain if we exceed the limit
        var ref_val := absf(amp * sample)
        if ref_val >= limit:
            var amount = limit / ref_val
            amp *= amount
            ref_amp = amp
            ref_val *= amount
            release_memory = release
        
        # return the limited sample
        return sample * amp * post_gain

func make_wav() -> AudioStreamWAV:
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    var data := PackedByteArray()
    
    var srate := 44100.0
    var freq := 441.0
    
    var limiter := Limiter.new()
    
    for i in int(srate):
        var t := 1.0 - (i / srate)
        if t > 0.5:
            t -= 0.5
        t *= 2.0
        var sample := t * t
        var phase = i * freq / srate
        
        # sine wave stack
        var n := 0.0
        n += sin(phase * PI * 2.0)
        n += sin(phase * PI * 2.0 * 1.498)
        n += sin(phase * PI * 2.0 * 1.26)
        sample *= n
        
        # square wave
        #if fmod(phase, 1.0) > 0.5:
        #    sample = -sample
        
        sample = limiter.push_sample(sample)
        
        data.push_back(0)
        data.push_back(0)
        data.encode_s16(data.size() - 2, int(sample * 32767.0))
    
    wav.data = data
    wav.mix_rate = int(srate)
    
    wav.save_to_wav("out__a_asdf.wav")
    
    return wav

func _ready() -> void:
    $AudioStreamPlayer.stream = make_wav()
    $AudioStreamPlayer.play()
