// ------------------------------------------------------------------ sound (src/view/audio.gd, data/audio.json)
// Every sound and voice is a WAV in assets/audio, rendered by tools/audio. A sound has takes played in
// turn, a gap it won't repeat within, and a bus (a volume in dB); voices are a creature's
// select / ack / die takes.

let AUDIO_DIR = "../assets/audio"

class Sound:
    takes:int
    gap:float  // seconds
    bus:string
    next:int = 0  // the take to play next
    last:float = -10.0

let sounds = dictionary<string, Sound>(64)
let buses = dictionary<string, float>(8)
let voice_takes = dictionary<string, int>(8)
var voice_of = []::string  // per player: its creature's voice
var voice_last = -10.0
var sound_on = true
var music_level = 5  // the player's volumes, 0..10 (settings.txt beside the saves)
var sound_level = 10
var hud_size = 115  // the match HUD's size in percent (Ctrl/Cmd + and -), in settings.txt too
let SETTINGS_FILE = "settings.txt"

def volume_load():
    let t = read_file(SETTINGS_FILE, true)
    if not t: return
    for(tokenize(t, "\n", " ")) line:
        let kv = tokenize(line, "=", " ")
        if kv.length == 2:
            if kv[0] == "music": music_level = clamp(string_to_int(kv[1]), 0, 10)
            elif kv[0] == "sound": sound_level = clamp(string_to_int(kv[1]), 0, 10)
            elif kv[0] == "hud": hud_size = clamp(string_to_int(kv[1]), 70, 200)

def volume_save(): write_file(SETTINGS_FILE, "music={music_level}\nsound={sound_level}\nhud={hud_size}\n")

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
    if ch > 0: sound_volume(ch, db_to_volume(buses.get(s.bus, 0.0) + db) * float(sound_level) / 10.0)

// One of the player's creature voices: "select", "ack" or "die".
def say(p:int, kind:string):
    if not sound_on or p < 0 or p >= voice_of.length: return
    let now = gl.time()
    if now - voice_last < 0.4: return
    voice_last = now
    let n = rnd(max(1, voice_takes.get(kind, 1))) + 1
    let ch = play_wav("{AUDIO_DIR}/voice/{voice_of[p]}_{kind}_{n}.wav")
    if ch > 0: sound_volume(ch, db_to_volume(buses.get("Voice", 0.0)) * float(sound_level) / 10.0)

// ---- the theme (Audio.music, battle): its stems play together, in step, each faded to the mix
// (data/audio.json music: the lobby's, then by the player's age; the battle layer while there's
// fighting on screen; none with the sound off). Each stem is a music track of its own.

let music_ids = []::int
let music_names = []::string
let music_now = []::float  // each stem's volume now (0..1)
var music_cfg:JV? = nil

def music_start():
    let a = load_json("../data/audio.json")
    let m = at(a, "music")
    music_cfg = m
    for(gstrs(m, "stems")) stem:
        let id = play_music("{AUDIO_DIR}/music/theme_{stem}.ogg", -1)
        if id > 0:
            music_volume(id, 0.0)
            music_ids.push(id)
            music_names.push(stem)
            music_now.push(0.0)
    print "music: {music_ids.length} stems playing"

def music_tick(mix:string, battle:bool, dt:float):
    let m = music_cfg
    if not m: return
    let levels = gobj(gobj(m, "mixes"), mix)
    let master = db_to_volume(buses.get("Music", 0.0)) * float(music_level) / 10.0
    let rate = dt / max(0.1, as_float(at(m, "fade_s")))
    for(music_ids) id, k:
        let stem = music_names[k]
        var want = 0.0
        if sound_on:
            if stem == "battle":
                if battle and mix != "lobby": want = db_to_volume(as_float(at(m, "battle_db"))) * master
            elif has(levels, stem): want = db_to_volume(as_float(at(levels, stem))) * master
        music_now[k] = move_toward(music_now[k], want, rate)
        music_volume(id, music_now[k])

// ---- the ambience (Audio.ambience, town): the meadow loop under a match, the town's quiet and busy
// loops on top by town_level (0: no town or the camera far away .. 1: a big town right below): the
// quiet one comes in first, the busy one joins past the middle. Each a music track, looping, faded.

let amb_ids = []::int  // meadow, town_quiet, town_busy
let amb_now = [ 0.0, 0.0, 0.0 ]

def ambience_start():
    for([ "sfx/meadow_1.wav", "sfx/town_quiet_1.wav", "sfx/town_busy_1.wav" ]) f:
        let id = play_music("{AUDIO_DIR}/{f}", -1)
        if id > 0: music_volume(id, 0.0)
        amb_ids.push(id)
    print "ambience: {(filter(amb_ids) id: id > 0).length} loops playing"

def ambience_tick(town_level:float, dt:float):
    let master = db_to_volume(buses.get("Ambience", 0.0)) * float(sound_level) / 10.0
    let want = [ db_to_volume(-6.0),
                 if town_level * 2.5 > 0.01: db_to_volume(4.0) * clamp(town_level * 2.5, 0.0, 1.0) else: 0.0,
                 if town_level > 0.41: db_to_volume(4.0) * clamp((town_level - 0.4) / 0.6, 0.0, 1.0) else: 0.0 ]
    for(amb_ids) id, k:
        if id > 0:
            amb_now[k] = move_toward(amb_now[k], (if sound_on: want[k] * master else: 0.0), dt * 0.5)
            music_volume(id, amb_now[k])
