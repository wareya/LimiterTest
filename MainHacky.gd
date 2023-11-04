extends Node2D

class Limiter extends RefCounted:
    var pre_gain := 4.0
    var post_gain := 1.0
    var srate := 44100.0
    
    var limit := 0.25
    
    var release := 0.001
    var release_memory := 0.0
    
    var attack := 0.001
    var box_blur := 0
    
    var sustain_dc_hack := true
    var sustain_ref_count := 0
    var sustain_ref := 0.0
    var sustain := 0.001
    var sustain_memory := 0.0
    
    var amp := 1.0
    var ref_amp := 1.0
    
    var memory_cursor := 0
    var amp_memory := PackedFloat32Array()
    var memory := PackedFloat32Array()
    
    func _init():
        for i in int(ceil(srate * attack)) + 1:
            memory.push_back(0.0)
            amp_memory.push_back(0.0)
    
    func push_sample(sample : float) -> float:
        sample *= pre_gain
        
        var ret_sample := memory[memory_cursor]
        
        var ref_val := absf(amp * sample)
        if ref_val >= limit:
            var amount = limit / ref_val
            ref_amp = amp
            amp *= amount
            ref_val *= amount
            sustain_memory = sustain + attack
            release_memory = release
            if sustain_dc_hack:
                sustain_ref = sign(sample)
                sustain_ref_count = 2
        
        if sustain_dc_hack and sustain_ref_count > 0:
            if sign(sample) == sustain_ref:
                sustain_memory = sustain + attack
            else:
                sustain_ref = -sustain_ref
                sustain_ref_count -= 1
        
        memory[memory_cursor] = sample
        
        box_blur -= int(amp_memory[memory_cursor] * 32767.0)
        amp_memory[memory_cursor] = amp
        box_blur += int(amp_memory[memory_cursor] * 32767.0)
        
        memory_cursor = (memory_cursor + 1) % memory.size()
        
        if sustain_memory == 0.0:
            release_memory = max(0.0, release_memory - 1.0 / srate)
            if release > 0.0:
                var f := 1.0 - release_memory / release
                amp = lerp(ref_amp, 1.0, smoothstep(0.0, 1.0, f))
            else:
                amp = 1.0
        
        sustain_memory = max(0.0, sustain_memory - 1.0 / srate)
        
        var ret : float = clamp(ret_sample * float(box_blur / 32767.0 / memory.size()), -limit, limit) * post_gain
        return ret
    pass

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
        data.encode_s16(data.size() - 2, sample * 32767.0)
    
    wav.data = data
    wav.mix_rate = srate
    
    wav.save_to_wav("out__a_asdf.wav")
    
    return wav

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    $AudioStreamPlayer.stream = make_wav()
    $AudioStreamPlayer.play()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
