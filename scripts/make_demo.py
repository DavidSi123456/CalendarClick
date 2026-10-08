#!/usr/bin/env python3
"""用虚构日程绘制中文操作演示，需要 Python 3 与 Pillow。"""

from pathlib import Path
import re

from PIL import Image, ImageColor, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "images"
PREVIEW = ROOT / ".build" / "demo"
W, H, SCALE = 1280, 850, 2
FPS, SECONDS = 12, 15
TEAL = "#18877D"
INK = "#252B32"
MUTED = "#737A84"
FONT_PATH = "/System/Library/Fonts/STHeiti Medium.ttc"
FONTS = {}
RESAMPLE = getattr(Image, "Resampling", Image).LANCZOS
MEDIANCUT = getattr(Image, "Quantize", Image).MEDIANCUT
NO_DITHER = getattr(Image, "Dither", Image).NONE


def font(size):
    if size not in FONTS:
        FONTS[size] = ImageFont.truetype(FONT_PATH, size * SCALE)
    return FONTS[size]


def rect(draw, box, fill, radius=0, outline=None, width=1):
    box = tuple(round(v * SCALE) for v in box)
    if radius:
        draw.rounded_rectangle(box, radius=radius * SCALE, fill=fill,
                               outline=outline, width=width * SCALE)
    else:
        draw.rectangle(box, fill=fill, outline=outline, width=width * SCALE)


def line(draw, points, fill, width=1):
    draw.line([(round(x * SCALE), round(y * SCALE)) for x, y in points],
              fill=fill, width=width * SCALE, joint="curve")


def text(draw, x, y, label, size=16, fill=INK, anchor="lt"):
    draw.text((round(x * SCALE), round(y * SCALE)), label,
              font=font(size), fill=fill, anchor=anchor)


def check(draw, x, y, size=13, color="white", width=2):
    line(draw, [(x, y + size * .52), (x + size * .35, y + size * .87),
                (x + size, y + size * .12)], color, width)


def shadow(image, box, radius=12, blur=12, opacity=28):
    layer = Image.new("RGBA", image.size)
    d = ImageDraw.Draw(layer)
    rect(d, (box[0], box[1] + 6, box[2], box[3] + 6),
         (22, 37, 43, opacity), radius)
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur * SCALE)))


def calendar(completed):
    image = Image.new("RGBA", (W * SCALE, H * SCALE), "#F1F5F4")
    d = ImageDraw.Draw(image)
    rect(d, (48, 36, 78, 66), TEAL, 9)
    check(d, 56, 43, 14)
    text(d, 92, 40, "日历打勾", 23)
    text(d, 1228, 48, "CalendarClick  ·  中文模拟演示", 15, MUTED, "rt")
    text(d, 48, 89, "做完一件事，就给日程打个勾。", 28)

    box = (42, 150, 1238, 742)
    shadow(image, box, 15, 17, 24)
    d = ImageDraw.Draw(image)
    rect(d, box, "#FFFFFF", 15, "#D9E0DF")
    rect(d, (43, 205, 225, 726), "#F5F6F7")
    rect(d, (43, 165, 225, 210), "#F5F6F7")
    rect(d, (43, 714, 225, 741), "#F5F6F7", 13)
    rect(d, (54, 157, 224, 180), "#F5F6F7")
    for x, color in [(64, "#FF6057"), (84, "#FEBC2E"), (104, "#28C840")]:
        d.ellipse((x * SCALE, 172 * SCALE, (x + 12) * SCALE, 184 * SCALE), fill=color)
    text(d, 248, 170, "2026年10月", 25)
    rect(d, (550, 164, 756, 193), "#EFF0F2", 7)
    for index, label in enumerate(["日", "周", "月", "年"]):
        x = 552 + index * 51
        if label == "周":
            rect(d, (x, 166, x + 49, 191), "#FFFFFF", 5, "#D7D9DE")
        text(d, x + 24, 177, label, 14, INK if label == "周" else MUTED, "mm")
    text(d, 1092, 178, "‹", 26, MUTED, "mm")
    rect(d, (1120, 164, 1175, 193), "#FFFFFF", 6, "#DDE0E3")
    text(d, 1147, 179, "今天", 13, anchor="mm")
    text(d, 1202, 178, "›", 26, MUTED, "mm")
    line(d, [(225, 204), (1237, 204)], "#E6E9EB")
    line(d, [(225, 204), (225, 741)], "#DEE3E5")

    text(d, 62, 229, "日历", 16)
    text(d, 62, 267, "iCloud", 13, MUTED)
    for y, label, color in [(304, "工作", "#3D9A89"), (344, "个人", "#BE8ADE"),
                             (384, "生活", "#E8AA51")]:
        rect(d, (62, y - 1, 77, y + 14), color, 4)
        check(d, 65, y + 1, 9, width=1)
        text(d, 88, y, label, 14)
    text(d, 63, 590, "小提示", 13, MUTED)
    text(d, 63, 619, "完成后，勾号会保留", 12, MUTED)
    text(d, 63, 641, "在日程标题里。", 12, MUTED)

    gx, column = 285, 136
    for i, weekday in enumerate(["周一", "周二", "周三", "周四", "周五", "周六", "周日"]):
        cx = gx + i * column + column / 2
        text(d, cx, 224, weekday, 13, MUTED, "mt")
        if i == 3:
            d.ellipse(((cx - 15) * SCALE, 244 * SCALE, (cx + 15) * SCALE, 274 * SCALE), fill="#E65855")
        text(d, cx, 259, str(5 + i), 19, "#FFFFFF" if i == 3 else INK, "mm")
        line(d, [(gx + i * column, 284), (gx + i * column, 741)], "#E7EAED")
    line(d, [(225, 284), (1237, 284)], "#DEE3E5")
    text(d, 263, 304, "全天", 11, MUTED, "rm")
    line(d, [(225, 324), (1237, 324)], "#DEE3E5")
    for hour in range(8):
        y = 324 + hour * 52
        text(d, 274, y + 7, f"{8 + hour}:00", 11, MUTED, "rt")
        if hour:
            line(d, [(285, y), (1237, y)], "#E7EAED")
        line(d, [(285, y + 26), (1237, y + 26)], "#F3F4F5")

    def event(x, y, label, time, color, accent, height=47, done=False):
        rect(d, (x, y, x + 126, y + height), color, 5)
        rect(d, (x + 1, y + 4, x + 4, y + height - 4), accent, 2)
        if done:
            check(d, x + 10, y + 9, 10, accent, 2)
        text(d, x + (25 if done else 10), y + 9, label, 13, accent)
        text(d, x + 10, y + 29, time, 11, accent)

    event(291, 329, "阅读与学习", "08:00 – 09:00", "#EAE2F4", "#7D52A7")
    event(427, 485, "散步", "11:00 – 12:00", "#FAEDD6", "#9B731F")
    event(699, 432, "整理项目资料", "10:00 – 11:00", "#DDEFE8", "#277563", done=completed)
    event(971, 588, "周末计划", "13:00 – 14:00", "#EAE2F4", "#7D52A7")
    return image


BASE = [calendar(False), calendar(True)]
MENU = (739, 462, 926, 676)
PANEL = (937, 462, 1209, 619)
TARGET, BUTTON = (748, 455), (1074, 583)


def popup(image, completed, hovered, success):
    d = ImageDraw.Draw(image)
    if not success:
        shadow(image, MENU, 10, 9, 43)
        d = ImageDraw.Draw(image)
        rect(d, MENU, "#F9F9FA", 10, "#D4D8DB")
        for y, label in [(481, "显示简介"), (519, "剪切"), (546, "拷贝"),
                         (573, "复制日程"), (600, "删除"), (645, "日历")]:
            text(d, 754, y, label, 14)
        line(d, [(748, 508), (917, 508)], "#DFE2E5")
        line(d, [(748, 630), (917, 630)], "#DFE2E5")
        text(d, 910, 651, "›", 17, MUTED, "mm")
    panel_box = PANEL if not success else (937, 462, 1209, 552)
    shadow(image, panel_box, 12, 10, 44)
    d = ImageDraw.Draw(image)
    rect(d, panel_box, "#F7F9F9", 12, "#D6E0DD")
    d.ellipse((952 * SCALE, 477 * SCALE, 966 * SCALE, 491 * SCALE), fill=TEAL)
    check(d, 955, 479, 8, width=1)
    text(d, 974, 479, "日历打勾", 12, MUTED)
    text(d, 1189, 484, "×", 16, MUTED, "mm")
    if success:
        text(d, 953, 519, "已标记为完成" if completed else "已取消完成", 16, TEAL)
        check(d, 1178, 515, 13, TEAL)
        return
    text(d, 953, 511, "整理项目资料", 16)
    text(d, 953, 540, "工作 · 10月8日 10:00", 12, MUTED)
    color = ("#5C6872" if hovered else "#737E87") if completed else ("#116D65" if hovered else TEAL)
    rect(d, (952, 566, 1194, 602), color, 7)
    if completed:
        line(d, [(976, 588), (976, 579), (972, 575), (962, 575)], "#FFFFFF", 2)
        d.polygon([(963 * SCALE, 570 * SCALE), (958 * SCALE, 575 * SCALE),
                   (963 * SCALE, 580 * SCALE)], fill="#FFFFFF")
    else:
        check(d, 963, 576, 13)
    text(d, 986, 584, "取消完成" if completed else "标记为已完成", 15, "#FFFFFF", "lm")


def smooth(a, b, amount):
    amount = max(0, min(1, amount))
    amount = amount * amount * (3 - 2 * amount)
    return tuple(x + (y - x) * amount for x, y in zip(a, b))


def cursor(draw, position, pulse=None, right=False):
    x, y = position
    if pulse is not None:
        radius = 13 + pulse * 17
        color = "#B1DCD5" if right else "#A5D8D1"
        draw.ellipse(((x - radius) * SCALE, (y - radius) * SCALE,
                      (x + radius) * SCALE, (y + radius) * SCALE), outline=color, width=2 * SCALE)
    shape = [(x, y), (x, y + 24), (x + 6, y + 19), (x + 11, y + 30),
             (x + 15, y + 28), (x + 10, y + 17), (x + 18, y + 17)]
    draw.polygon([(round(px * SCALE), round(py * SCALE)) for px, py in shape],
                 fill="#202A30", outline="#FFFFFF", width=2 * SCALE)
    if right:
        rect(draw, (x + 23, y - 3, x + 81, y + 26), "#253B37", 7)
        text(draw, x + 52, y + 12, "右键", 13, "#FFFFFF", "mm")


def frame(t):
    completed = 5.25 <= t < 12.15
    image = BASE[int(completed)].copy()
    menu_visible = 2.6 <= t < 5.2 or 10.1 <= t < 12.1
    success = 5.25 <= t < 7.25 or 12.15 <= t < 13.8
    if menu_visible or success:
        popup(image, completed, 4.25 <= t < 5.2 or 11.4 <= t < 12.1, success)
    if t < 2.6 or t >= 13.8:
        step, caption = 1, "右键一个日程"
    elif t < 5.25:
        step, caption = 2, "原菜单保留，在旁边点击「标记为已完成」"
    elif t < 9.3:
        step, caption = 3, "标题显示勾号，完成状态一眼可见"
    else:
        step, caption = 4, "再次右键，也可以「取消完成」"
    d = ImageDraw.Draw(image)
    d.ellipse((48 * SCALE, 783 * SCALE, 77 * SCALE, 812 * SCALE), fill=TEAL)
    text(d, 62.5, 798, str(step), 16, "#FFFFFF", "mm")
    text(d, 92, 798, caption, 20, INK, "lm")
    text(d, 1230, 798, "虚构日程 · 操作示意", 13, MUTED, "rm")
    if t < 1.2:
        pos = (550, 689)
    elif t < 2.3:
        pos = smooth((550, 689), TARGET, (t - 1.2) / 1.1)
    elif t < 3.3:
        pos = TARGET
    elif t < 4.25:
        pos = smooth(TARGET, BUTTON, (t - 3.3) / .95)
    elif t < 6.4:
        pos = BUTTON
    elif t < 7.1:
        pos = smooth(BUTTON, (884, 710), (t - 6.4) / .7)
    elif t < 9.3:
        pos = (884, 710)
    elif t < 9.95:
        pos = smooth((884, 710), TARGET, (t - 9.3) / .65)
    elif t < 10.65:
        pos = TARGET
    elif t < 11.4:
        pos = smooth(TARGET, BUTTON, (t - 10.65) / .75)
    elif t < 12.75:
        pos = BUTTON
    elif t < 13.8:
        pos = smooth(BUTTON, (550, 689), (t - 12.75) / 1.05)
    else:
        pos = (550, 689)
    pulse = None
    right = 2.3 <= t < 3.25 or 9.95 <= t < 10.65
    for start in [2.3, 5.0, 9.95, 11.9]:
        if start <= t < start + .35:
            pulse = (t - start) / .35
    cursor(d, pos, pulse, right)
    return image.convert("RGB").resize((W, H), RESAMPLE)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    times = [0, 3.0, 4.6, 5.7, 8.1, 10.5, 11.7, 12.5]
    samples = [frame(t) for t in times]
    swatches = Image.new("RGB", (W, H * len(samples)))
    for index, sample in enumerate(samples):
        swatches.paste(sample, (0, H * index))
    # Reserve solid UI colors so small controls retain their colors in the GIF.
    solids = sorted(set(re.findall(r"#[0-9A-Fa-f]{6}", Path(__file__).read_text())))
    remaining = 256 - len(solids)
    adaptive = swatches.quantize(colors=remaining, method=MEDIANCUT)
    palette = Image.new("P", (1, 1))
    exact = [channel for color in solids for channel in ImageColor.getrgb(color)]
    palette.putpalette(exact + adaptive.getpalette()[:remaining * 3])
    frames = [frame(i / FPS).quantize(palette=palette, dither=NO_DITHER)
              for i in range(FPS * SECONDS)]
    destination = OUT / "calendarclick-demo-zh-CN.gif"
    frames[0].save(destination, save_all=True, append_images=frames[1:],
                   duration=[80, 80, 90] * (len(frames) // 3), loop=0,
                   disposal=1, optimize=True)
    sheet = Image.new("RGB", (W, H * 2), "white")
    for index, sample in enumerate(samples):
        sheet.paste(sample.resize((W // 2, H // 2), RESAMPLE),
                    ((index % 2) * W // 2, (index // 2) * H // 2))
    sheet.save(PREVIEW / "contact-sheet.png")
    samples[2].save(PREVIEW / "menu-preview.png")
    samples[4].save(PREVIEW / "completed-preview.png")
    print(f"已生成：{destination}")
    print(f"时长：15 秒；尺寸：{W} × {H}；大小：{destination.stat().st_size / 1024:.0f} KiB")


if __name__ == "__main__":
    main()
