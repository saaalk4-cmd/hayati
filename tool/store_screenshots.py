"""يطلّع صور المتجر من لقطات test_screens/out.

التشغيل:
  flutter test test_screens --update-goldens
  python3 tool/store_screenshots.py
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1080, 1920
ITEMS = [
    ('today', 'يومك كله في شاشة واحدة', 'الصلاة الجاية، ومهامك، وعاداتك، ومصروفك'),
    ('worship', 'عباداتك بهدوء', 'مواقيت دقيقة، وأذكار بعدّاد، وورد القرآن، والقبلة'),
    ('habits', 'عادات بتكمّل', 'سلسلة أيام متتالية، وتذكير، وخريطة شهرية'),
    ('money', 'فلوسك تحت السيطرة', 'ميزانية، ومصروفات ثابتة، ومقارنة كل شهر'),
    ('ramadan', 'رمضان بروح تانية', 'السحور والإفطار بعدّاد، وصيامك وتراويحك يوم بيوم'),
    ('more', 'كل حياتك في مكان واحد', 'مساعد ذكي، وتركيز، ويوميات، ومناسبات، وإحصائيات'),
]
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans{}.ttf'


def font(size, bold=False):
    return ImageFont.truetype(FONT.format('-Bold' if bold else ''), size,
                              layout_engine=ImageFont.Layout.RAQM)


def background():
    g = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(g)
    a, b = (0x1A, 0x4D, 0x3C), (0x05, 0x12, 0x0D)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((140, 700, 940, 1500), fill=(212, 175, 90, 60))
    return Image.alpha_composite(g.convert('RGBA'), glow.filter(ImageFilter.GaussianBlur(160)))


def centered(d, y, text, f, fill):
    bb = d.textbbox((0, 0), text, font=f, direction='rtl', language='ar')
    d.text(((W - (bb[2] - bb[0])) / 2 - bb[0], y - bb[1]), text, font=f, fill=fill,
           direction='rtl', language='ar')


def main():
    out = 'assets/brand/store'
    os.makedirs(out, exist_ok=True)
    for f in glob.glob(f'{out}/screenshot_*.png'):
        os.remove(f)
    for i, (name, title, sub) in enumerate(ITEMS, 1):
        bg = background()
        d = ImageDraw.Draw(bg)
        centered(d, 120, title, font(74, True), (0xD4, 0xAF, 0x5A))
        centered(d, 232, sub, font(37), (0xF4, 0xEE, 0xDF))
        shot = Image.open(f'test_screens/out/{name}.png').convert('RGB')
        pw = 760
        ph = int(shot.height * pw / shot.width)
        shot = shot.resize((pw, ph), Image.LANCZOS)
        top = 360
        sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle(
            ((W - pw) // 2 - 18, top + 12, (W + pw) // 2 + 18, top + ph + 48), radius=90,
            fill=(0, 0, 0, 150))
        bg = Image.alpha_composite(bg, sh.filter(ImageFilter.GaussianBlur(30)))
        d = ImageDraw.Draw(bg)
        d.rounded_rectangle(((W - pw) // 2 - 18, top - 18, (W + pw) // 2 + 18, top + ph + 18),
                            radius=90, fill=(12, 12, 12, 255), outline=(212, 175, 90, 120), width=3)
        mask = Image.new('L', (pw, ph), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, pw, ph), radius=74, fill=255)
        bg.paste(shot, ((W - pw) // 2, top), mask)
        d.rounded_rectangle((W // 2 - 70, top + 14, W // 2 + 70, top + 44), radius=15,
                            fill=(12, 12, 12, 255))
        bg.convert('RGB').save(f'{out}/screenshot_{i}_{name}.png', optimize=True)
    print('done')


if __name__ == '__main__':
    main()
