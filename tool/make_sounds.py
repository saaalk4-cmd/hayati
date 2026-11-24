"""بيولّد أصوات حياتي الأصلية (من غير أي حقوق) في assets/sounds و android res/raw.
تشغيل: python3 tool/make_sounds.py"""
import wave, numpy as np, os

SR = 44100

def env(n, attack=0.005, decay=0.25):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)

def tone(freq, dur, decay=0.25, harmonics=((1, 1.0), (2, 0.25), (3, 0.08)), vol=0.5):
    n = int(SR * dur)
    t = np.arange(n) / SR
    s = sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in harmonics)
    return vol * s * env(n, decay=decay)

def mix(*parts):
    n = max(off + len(p) for off, p in parts)
    out = np.zeros(n)
    for off, p in parts:
        out[off:off + len(p)] += p
    return out

def at(sec):
    return int(SR * sec)

def save(name, x, dirs):
    x = x / max(1e-9, np.max(np.abs(x))) * 0.8
    # تلاشي في الآخر عشان مفيش طقة
    fade = min(len(x), at(0.02))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16).tobytes()
    for d in dirs:
        os.makedirs(d, exist_ok=True)
        with wave.open(os.path.join(d, name), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

A = ['assets/sounds']
# «تك» ناعمة: خلّصت مهمة
pop = mix((0, tone(880, 0.18, decay=0.04, harmonics=((1, 1), (2, 0.3)))), (0, tone(1320, 0.12, decay=0.03, vol=0.25)))
save('done.wav', pop, A)
# عملة: مصروف
coin = mix((0, tone(1568, 0.12, decay=0.05, vol=0.5)), (at(0.07), tone(2093, 0.35, decay=0.12, vol=0.5)))
save('coin.wav', coin, A)
# احتفال: أربيجيو جرس (دو مي صول دو)
notes = [523.25, 659.25, 783.99, 1046.5]
chime = mix(*[(at(0.09 * i), tone(f, 1.2, decay=0.45, harmonics=((1, 1), (2, 0.4), (3, 0.15), (4.2, 0.05)), vol=0.4)) for i, f in enumerate(notes)])
save('celebrate.wav', chime, A)
# سبحة: طقة خشب قصيرة
n = at(0.05)
noise = np.random.default_rng(7).standard_normal(n) * env(n, attack=0.0005, decay=0.006)
click = mix((0, noise * 0.3), (0, tone(1800, 0.05, decay=0.008, vol=0.6)))
save('tick.wav', click, A)
# هدف السبحة (33/100): نغمتين ناعمين
goal = mix((0, tone(784, 0.6, decay=0.25, vol=0.4)), (at(0.12), tone(1046.5, 0.9, decay=0.35, vol=0.4)))
save('milestone.wav', goal, A)
# صوت إشعار حياتي: جرس هادي (للتذكيرات)
bell = mix((0, tone(659.25, 1.6, decay=0.6, harmonics=((1, 1), (2.01, 0.35), (3, 0.12), (4.1, 0.06)), vol=0.45)),
           (at(0.22), tone(987.77, 1.8, decay=0.7, harmonics=((1, 1), (2.01, 0.3), (3, 0.1)), vol=0.4)))
save('hayati_chime.wav', bell, A + ['android/app/src/main/res/raw'])
print('ok')
