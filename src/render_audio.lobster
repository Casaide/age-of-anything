// Renders one job of the game's audio (render_audio.sh runs them all): an effect's takes, a creature's voice, or a music
// stem as a WAV, which the script turns into Ogg. Deterministic: the same files every time.
//   lobster render_audio.lobster -- <out dir> sfx <name> | voice <creature> | music <piece> <stem> | list
import std
import audio.synth
import audio.instruments
import audio.score
import audio.music
import audio.music_hearth
import audio.music_march
import audio.sfx
import audio.voices

def text_sum(s:string) -> int: return fold(s, 0): _a + _b

def seed_of(text:string) -> int:
    var sum = 0
    for(text) c, i: sum += (i + 1) * c
    return sum

def render_sfx(out:string, name:string):
    let i = find(sfx_names): _ == name
    assert i >= 0
    for(sfx_takes[i]) k:
        seed_rng(seed_of("sfx:{name}:{k}"))
        var buf = sfx_take(name)
        if name != "meadow" and name != "town_quiet" and name != "town_busy": buf = trim_tail(buf)
        write_wav("{out}/sfx/{name}_{k + 1}.wav", normalize(buf, sfx_peaks[i]), [])

def render_voice(out:string, creature:string):
    for(voice_kinds) kind, i:
        for(voice_takes[i]) k:
            seed_rng(seed_of("voice:{creature}:{kind}:{k}"))
            let buf = voice_take(creature, kind)
            write_wav("{out}/voice/{creature}_{kind}_{k + 1}.wav", normalize(trim_tail(buf), -4.0), [])

// A seamless loop: tails wrap, and the room's tail from the end lands on the start.
def render_music(out:string, piece:string, stem:string):
    let salt = if piece == "theme": 0 else: text_sum(piece) * 31  // (the theme keeps its old seeds)
    seed_rng(7 + text_sum(stem) + salt)
    let dry = switch piece:
        case "theme": theme_stem(stem)
        case "hearth": hearth_stem(stem)
        default: march_stem(stem)
    let room = switch piece:
        case "theme": theme_room(stem)
        case "hearth": hearth_room(stem)
        default: march_room(stem)
    let twice = reverb(concat(dry, dry), room.y, room.z)
    let loop = normalize(twice.slice(dry.length, -1), -3.0)
    let a = (room.x + 1.0) * PI / 4.0
    let left = gain(loop, rcos(a))
    let right = append(zeros(seconds(0.003)), gain(loop, rsin(a)).slice(0, loop.length - seconds(0.003)))
    write_wav("{out}/music/{piece}_{stem}.wav", left, right)

let args = command_line_arguments()
if args[0] == "list":
    for(sfx_names) n: print "sfx {n}"
    for(creatures) c: print "voice {c}"
    for([ "theme", "hearth", "march" ]) p:
        for([ "pluck", "flute", "drone", "horns", "drums", "battle" ]) s: print "music {p} {s}"
else:
    switch args[1]:
        case "sfx": render_sfx(args[0], args[2])
        case "voice": render_voice(args[0], args[2])
        default: render_music(args[0], args[2], args[3])
