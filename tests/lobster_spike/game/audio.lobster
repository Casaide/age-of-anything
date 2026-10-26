// ------------------------------------------------------------------ sound (src/view/audio.gd, data/audio.json)
// Every sound and voice is a WAV in assets/audio, rendered by tools/audio. A sound has takes played in
// turn, a gap it won't repeat within, and a bus (a volume in dB); voices are a creature's
// select / ack / die takes.

let AUDIO_DIR = "../../assets/audio"

class Sound:
    takes:int
    gap:float        // seconds
    bus:string
    next:int = 0     // the take to play next
    last:float = -10.0

var sounds = dictionary<string, Sound>(64)
var buses = dictionary<string, float>(8)
var voice_takes = dictionary<string, int>(8)
var voice_of = []::string                   // per player: its creature's voice
var voice_last = -10.0
var sound_on = true

def db_to_volume(db:float) -> float: return pow(10.0, db / 20.0)

def play_sound(name:string, db:float):
    if not sound_on: return
    let s = sounds.get(name)
    if not s: return
    let now = gl.time()
    if now - s.last < s.gap: return
    s.last = now
    let n = s.next % s.takes + 1
    s.next++
    let ch = play_wav("{AUDIO_DIR}/sfx/{name}_{n}.wav")
    if ch > 0: sound_volume(ch, db_to_volume(buses.get(s.bus, 0.0) + db))

// One of the player's creature voices: "select", "ack" or "die".
def say(p:int, kind:string):
    if not sound_on or p < 0 or p >= voice_of.length: return
    let now = gl.time()
    if now - voice_last < 0.4: return
    voice_last = now
    let n = rnd(max(1, voice_takes.get(kind, 1))) + 1
    let ch = play_wav("{AUDIO_DIR}/voice/{voice_of[p]}_{kind}_{n}.wav")
    if ch > 0: sound_volume(ch, db_to_volume(buses.get("Voice", 0.0)))
