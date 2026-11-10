"""Tileable neutral-grey painted textures for the warrior armor sets (albedo + normal), tinted per set in game.
Run: blender -b -P tools/outfits/make_armor_textures.py  (uses Blender's numpy; no other deps)."""
import bpy, numpy as np, os
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "creator", "armor"))
rng = np.random.default_rng(7)

def periodic_noise(n, octaves=5, base=2, seed=0):
    r = np.random.default_rng(seed); y, x = np.mgrid[0:n, 0:n] / n * 2 * np.pi
    out = np.zeros((n, n), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        f = base * 2 ** o
        for _ in range(3):
            a, b = r.integers(-f, f + 1, 2); ph = r.uniform(0, 2 * np.pi)
            out += amp * np.cos(a * x + b * y + ph)
        tot += amp * 3; amp *= 0.55
    return out / tot

def normal_from_height(h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-gx, -gy, np.ones_like(h)], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5

def shade(h, strength=6.0, light=(-0.5, 0.6, 0.62)):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-gx, -gy, np.ones_like(h)], -1); n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return np.clip((n * np.array(light)).sum(-1), 0, 1)

def save(arr, name, srgb=True):
    h, w = arr.shape[:2]
    rgba = np.ones((h, w, 4), np.float32)
    rgba[..., :3] = arr if arr.ndim == 3 else arr[..., None]
    im = bpy.data.images.new(name, w, h, alpha=False, float_buffer=False)
    im.colorspace_settings.name = 'sRGB' if srgb else 'Non-Color'
    im.pixels.foreach_set(rgba.reshape(-1)); im.filepath_raw = os.path.join(OUT, name + ".png"); im.file_format = 'PNG'; im.save()

def plate(n=1024):
    base = periodic_noise(n, 3, 1, 1)          # broad painted mottling
    mid = periodic_noise(n, 3, 5, 2)
    stripes = np.zeros((n, n), np.float32)
    for _ in range(40):                        # fine scratches, mostly horizontal
        yy = rng.integers(0, n); ln = rng.integers(40, 260); xx = rng.integers(0, n); v = rng.uniform(0.2, 0.8)
        idx = (xx + np.arange(ln)) % n; stripes[yy, idx] = np.maximum(stripes[yy, idx], v)
    stripes = (stripes + np.roll(stripes, 1, 0) * 0.5) / 1.5
    alb = 0.74 + 0.11 * base + 0.03 * mid - 0.09 * stripes
    h = mid * 0.15 - stripes * 0.35
    save(np.clip(alb, 0, 1)[..., None].repeat(3, -1), "T_plate")
    save(normal_from_height(h, 2.0), "T_plate_n", srgb=False)

def mail(n=512, cells=8):
    cs = n / cells
    H = np.zeros((n, n), np.float32)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    R = cs * 0.58; w = cs * 0.2
    for row in range(cells * 2):
        for col in range(cells):
            cx = (col + (0.5 if row % 2 else 0.0) + 0.5) * cs; cy = (row + 0.5) * cs * 0.5
            for ox in (-n, 0, n):
                for oy in (-n, 0, n):
                    d = np.sqrt((x - cx - ox) ** 2 + ((y - cy - oy) * 1.0) ** 2)
                    ring = np.clip(1 - np.abs(d - R * 0.5) / w, 0, 1)
                    # alternate over/under so rings look interlocked
                    H = np.where(ring > 0, np.maximum(H, ring * (0.8 + 0.2 * (row % 2))), H)
    L = shade(H, 14.0)
    alb = 0.16 + 0.78 * np.clip(H, 0, 1) ** 0.8 * (0.55 + 0.6 * L) + 0.02 * periodic_noise(n, 3, 6, 5)
    save(np.clip(alb, 0, 1)[..., None].repeat(3, -1), "T_mail")
    save(normal_from_height(H, 7.0), "T_mail_n", srgb=False)

def leather(n=512):
    g = periodic_noise(n, 5, 8, 11); big = periodic_noise(n, 3, 2, 12)
    y, x = np.mgrid[0:n, 0:n] / n
    cr = np.abs(periodic_noise(n, 4, 12, 13))    # cracked-grain look
    h = g * 0.4 - cr * 0.4
    alb = 0.62 + 0.16 * big + 0.07 * g - 0.10 * cr
    save(np.clip(alb, 0, 1)[..., None].repeat(3, -1), "T_leather")
    save(normal_from_height(h, 3.5), "T_leather_n", srgb=False)

def cloth(n=512):
    y, x = np.mgrid[0:n, 0:n] / n * 2 * np.pi
    weave = (np.cos(x * 24) * np.cos(y * 24) * 0.5 + 0.5)
    slub = periodic_noise(n, 4, 4, 21)
    alb = 0.74 + 0.12 * slub + 0.025 * weave
    save(np.clip(alb, 0, 1)[..., None].repeat(3, -1), "T_cloth")
    save(normal_from_height(weave * 0.3 + slub * 0.3, 2.0), "T_cloth_n", srgb=False)

if __name__ == "__main__":
    plate(); mail(); leather(); cloth(); print("armor textures done")
