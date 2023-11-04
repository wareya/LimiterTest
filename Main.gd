extends Node2D

class Limiter extends RefCounted:
    var pre_gain := 4.0
    var post_gain := 1.0
    
    var srate := 44100.0
    
    var limit := 0.25
    
    var release := 0.04
    var attack := 0.001
    var sustain := 0.04
    
    var box_blur := 0
    var amp := 1.0
    
    var memory_cursor := 0
    var sustained_amp := PackedFloat32Array()
    var sample_memory := PackedFloat32Array()
    
    var amp_memory_cursor := 0
    var amp_memory := PackedFloat32Array()
    var amp_min_buckets : PackedFloat32Array = []
    var amp_bucket_size := 0
    
    func _init():
        for i in int(ceil(srate * attack)) + 1:
            sample_memory.push_back(0.0)
            sustained_amp.push_back(0.0)
        
        var amp_count := int(ceil(srate * (attack + sustain))) + 1
        amp_bucket_size = int(sqrt(amp_count))
        for i in amp_count:
            amp_memory.push_back(1.0)
        for i in range(0, amp_count, amp_bucket_size):
            amp_min_buckets.push_back(1.0)
    
    func push_sample(sample : float) -> float:
        sample *= pre_gain
        
        # do the release curve
        if release > 0.0:
            amp = lerp(amp, 1.0, 1.0 - pow(0.5, 1.0 / (srate * release)))
        else:
            amp = 1.0
        
        # reset sustain if we exceed the limit
        var ref_val := absf(amp * sample)
        if ref_val >= limit:
            var amount = limit / ref_val
            amp *= amount
            ref_val *= amount
        
        amp_memory[amp_memory_cursor] = amp
        
        # update affected bucket
        @warning_ignore("integer_division")
        var bucket := amp_memory_cursor / amp_bucket_size
        amp_min_buckets[bucket] = 1.0
        for i in range(bucket * amp_bucket_size, min((bucket + 1) * amp_bucket_size, amp_memory.size())):
            amp_min_buckets[bucket] = min(amp_min_buckets[bucket], amp_memory[i])
        
        # now get the current sustain value
        var min_amp := 1.0
        for past_amp in amp_min_buckets:
            min_amp = min(min_amp, past_amp)
        
        amp_memory_cursor = (amp_memory_cursor + 1) % amp_memory.size()
        
        # update the sustain buffer
        box_blur -= int(sustained_amp[memory_cursor] * 32767.0)
        sustained_amp[memory_cursor] = min_amp
        box_blur += int(sustained_amp[memory_cursor] * 32767.0)
        
        # update the sample memory buffer
        var ret_sample := sample_memory[memory_cursor] if sustain + attack > 0.0 else sample
        sample_memory[memory_cursor] = sample
        
        memory_cursor = (memory_cursor + 1) % sample_memory.size()
        
        # return the limited sample
        return ret_sample * (box_blur / 32767.0 / sample_memory.size()) * post_gain
        #return box_blur / 32767.0 / sample_memory.size()

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
