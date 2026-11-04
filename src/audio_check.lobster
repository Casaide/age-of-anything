// Looks at rendered sounds by numbers: length, peak, RMS, a pitch guess (autocorrelation over the middle of the sound),
// so a re-render can be sanity-checked without ears.
//   lobster audio_check.lobster -- <file.wav> [...]   (absolute paths, or relative to src/)
import std

set_print_decimals(1)

def read_wav(path:string) -> [float], int:
    let data = assert read_file(path, 0)
    let chans = read_int16_le(data, 22)
    let rate = read_int32_le(data, 24)
    let bytes = read_int32_le(data, 40)
    let n = bytes / (2 * chans)
    let buf = map(n) i:
        read_int16_le(data, 44 + i * 2 * chans) / 32768.0
    return buf, rate

def energy(b:[float]) -> float: return fold(b, 0.0): _a + _b * _b

def pitch(buf:[float], rate:int) -> float:
    let mid = buf.length / 3
    let len = min(4096, buf.length - mid)
    guard len >= 512:
        return 0.0
    let win = buf.slice(mid, len)
    let e = energy(win) + 0.000000001
    var best = 0.0
    var bestr = 0.0
    for(rate / 40 - rate / 3000) k:
        let lag = rate / 3000 + k
        var sum = 0.0
        for(max(0, len - lag)) i: sum += win[i] * win[i + lag]
        if sum / e > bestr:
            bestr = sum / e
            best = float(rate) / lag
    return if bestr > 0.3: best else: 0.0

def lowpassed(b:[float], fc:float, rate:int) -> [float]:
    let a = 1.0 - pow(2.718281828459045, -6.283185307179586 * fc / rate)
    var y = 0.0
    return map(b) x:
        y += a * (x - y)
        y

def db(x:float) -> float: return 20.0 * log(x + 0.000000001) / log(10.0)

for(command_line_arguments()) path:
    let buf, rate = read_wav(path)
    var pk = 0.0
    for(buf) x: pk = max(pk, abs(x))
    let all = energy(buf)
    let lo = energy(lowpassed(buf, 300.0, rate)) + 0.000000000001
    let mid = energy(lowpassed(buf, 1500.0, rate)) + 0.000000000001
    let tot = max(0.000000000001, lo + (mid - lo) + (all + 0.000000000001 - mid))
    let p = pitch(buf, rate)
    print "{path}: {float(buf.length) / rate} s, peak {db(pk)} dB, rms {db(sqrt(all / buf.length))} dB, " +
        "low/mid/high {lo / tot * 100.0}/{(mid - lo) / tot * 100.0}/{(all - mid) / tot * 100.0}%, " +
        "pitch {if p > 0.0: string(p) + " Hz" else: "-"}"
