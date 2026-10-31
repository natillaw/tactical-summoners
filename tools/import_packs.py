"""Imports ONLY the files the game uses from the raw packs in assets/source_packs/ (git-ignored) into
assets/ (UI/art prompt, D-063). Reproducible: run again after changing the selection.
  python tools/import_packs.py            (needs sox for the music: C:/Program Files (x86)/sox-14-4-2/sox)
Every destination folder gets a LICENSE.txt with the pack's terms as registered in docs/ASSET_REGISTRY.md.
Originals are never modified; adjustments are made later on copies (tools/art_cohesion.gd -> assets/processed/)."""
import os, shutil, subprocess, sys, tempfile, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "source_packs")
SOX = r"C:/Program Files (x86)/sox-14-4-2/sox"

NINJA = "Ninja Adventure - Asset Pack.zip"
NINJA_IN = "Ninja Adventure - Asset Pack/"
NINJA_MONSTERS = ["Mouse", "BlueBat", "Slime", "Slime2", "Mushroom", "Mushroom2", "SpiderRed", "Bear", "Grey Trex"]
NINJA_CHARACTERS = ["DemonGreen", "DemonRed", "Skeleton", "Vampire"]
NINJA_BOSSES = ["GiantRacoon", "DemonCyclop", "GiantSlime", "GiantFrog"]
NINJA_FX = ["FX/Slash/", "FX/Projectile/", "FX/Magic/", "FX/Elemental/", "FX/Smoke/", "FX/Particle/"]
NINJA_SFX = ["Audio/Sounds/Hit & Impact/", "Audio/Sounds/Whoosh & Slash/", "Audio/Sounds/Magic & Skill/", "Audio/Sounds/Bonus/",
             "Audio/Sounds/Creature/", "Audio/Sounds/Alert/"]
MUSIC = {  # role -> xDeviruchi track (WAV -> OGG)
    "title": "xDeviruchi - Title Theme .wav",
    "town": "xDeviruchi - Take some rest and eat some food!.wav",
    "explore": "xDeviruchi - Exploring The Unknown.wav",
    "dungeon": "xDeviruchi - Mysterious Dungeon.wav",
    "battle": "xDeviruchi - Prepare for Battle! .wav",
    "boss": "xDeviruchi - Decisive Battle.wav",
    "results": "xDeviruchi - And The Journey Begins .wav",
}

LICENSES = {
    "ninja": "Ninja Adventure Asset Pack (pixel-boy & AAA, https://pixel-boy.itch.io/ninja-adventure-asset-pack) - CC0 1.0.\n",
    "dragon": "Tiny RPG Dragon Regalia GUI (https://tiny-rpg.itch.io) - CC0 (license.html in the pack).\n",
    "kurai": "Free RPG Skill Icons by KURAI (https://kurai7.itch.io/rpg-skill-icons): commercial use allowed, modify allowed, "
             "credit appreciated; do not resell or redistribute the icons.\n",
    "caz_mv": "MV Icons Complete Sheet by Caz (https://cazwolf.itch.io) - CC BY 4.0, credit Caz (EULA linked in the pack).\n",
    "raven": "Raven Fantasy Icons by Clockwork Raven Studios: license held by the project owner (D-063, 2026-10-31).\n",
    "kenney": "Interface Sounds by Kenney (https://kenney.nl) - CC0 1.0.\n",
    "xdeviruchi": "8-bit Fantasy & Adventure Music by xDeviruchi - CC BY-SA 4.0, credit xDeviruchi. Converted WAV -> OGG (sox), "
                  "unchanged otherwise.\n",
    "fonts": "m5x7 by Daniel Linssen (managore) - CC0. m6x11 by Daniel Linssen - license held by the project owner (D-063).\n",
    "enemy_anim": "Enemy_Animations_Set: license held by the project owner (D-063, 2026-10-31).\n",
    "pixel_dungeon": "2D Pixel Dungeon Asset Pack v2.0 (Pixel_Poem): license held by the project owner (D-063, 2026-10-31).\n",
}


def _dest(*parts):
    p = os.path.join(ROOT, "assets", *parts)
    os.makedirs(p, exist_ok=True)
    return p


def _license(folder, key):
    with open(os.path.join(folder, "LICENSE.txt"), "w", encoding="utf-8") as f:
        f.write(LICENSES[key])


def _extract(zf, member, out_path):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with zf.open(member) as src, open(out_path, "wb") as dst:
        shutil.copyfileobj(src, dst)


def ninja():
    z = zipfile.ZipFile(os.path.join(SRC, NINJA))
    names = z.namelist()
    groups = [("enemies", "Actor/Monster/", NINJA_MONSTERS), ("enemies", "Actor/Character/", NINJA_CHARACTERS),
              ("bosses", "Actor/Boss/", NINJA_BOSSES)]
    for kind, base, wanted in groups:
        out = _dest("pixel", kind, "ninja")
        _license(out, "ninja")
        for w in wanted:
            prefix = NINJA_IN + base + w + "/"
            for n in names:
                if n.startswith(prefix) and n.lower().endswith(".png"):
                    _extract(z, n, os.path.join(out, w.replace(" ", "_"), os.path.basename(n)))
    fx = _dest("pixel", "fx", "ninja")
    _license(fx, "ninja")
    for sub in NINJA_FX:
        for n in names:
            if n.startswith(NINJA_IN + sub) and n.lower().endswith(".png"):
                _extract(z, n, os.path.join(fx, n[len(NINJA_IN + "FX/"):]))
    sfx = _dest("audio", "sfx", "ninja")
    _license(sfx, "ninja")
    for sub in NINJA_SFX:
        for n in names:
            if n.startswith(NINJA_IN + sub) and n.lower().endswith((".wav", ".ogg")):
                _extract(z, n, os.path.join(sfx, n[len(NINJA_IN + "Audio/Sounds/"):].replace(" & ", "_").replace(" ", "_")))


def simple_zip(zip_name, dest_parts, key, inner_filter=lambda n: n.lower().endswith(".png"), flatten=True):
    z = zipfile.ZipFile(os.path.join(SRC, zip_name))
    out = _dest(*dest_parts)
    _license(out, key)
    for n in z.namelist():
        if n.endswith("/") or not inner_filter(n):
            continue
        target = os.path.join(out, os.path.basename(n) if flatten else n.split("/", 1)[-1])
        _extract(z, n, target)


def music():
    z = zipfile.ZipFile(os.path.join(SRC, "xDeviruchi - 8-bit Fantasy  & Adventure Music (2021).zip"))
    out = _dest("audio", "music", "xdeviruchi")
    _license(out, "xdeviruchi")
    tmp = tempfile.mkdtemp()
    for role, track in MUSIC.items():
        member = [n for n in z.namelist() if n.endswith(track)][0]
        wav = os.path.join(tmp, "in.wav")
        _extract(z, member, wav)
        ogg = os.path.join(out, role + ".ogg")
        subprocess.run([SOX, wav, "-C", "4", ogg], check=True)
        os.remove(wav)


def fonts():
    out = _dest("fonts")
    _license(out, "fonts")
    for f in ["m5x7.ttf", "m6x11.ttf"]:
        shutil.copy(os.path.join(SRC, f), os.path.join(out, f))


def kit():
    """The project's own kit (assets/_inbox is ignored by Godot): copied to an importable folder."""
    src = os.path.join(ROOT, "assets", "_inbox", "ts_generated_kit")
    out = os.path.join(ROOT, "assets", "pixel", "ui", "ts_kit")
    if os.path.isdir(out):
        shutil.rmtree(out)
    shutil.copytree(src, out, ignore=shutil.ignore_patterns("_preview.png", "*.md"))
    with open(os.path.join(out, "LICENSE.txt"), "w", encoding="utf-8") as f:
        f.write("Tactical Summoners generated kit v1: original to the project (no third-party art).\n")


def main():
    ninja()
    simple_zip("tinyRPG_dragonRegaliaGUI_v1_0.zip", ["pixel", "ui", "dragon_regalia"], "dragon")
    simple_zip("FREE RPG SKILL ICONS 32x32.zip", ["pixel", "icons", "kurai_skills"], "kurai")
    simple_zip("MV Icons Complete Sheet - Free Icons.zip", ["pixel", "icons", "caz_mv"], "caz_mv")
    simple_zip("Free - Raven Fantasy Icons.zip", ["pixel", "icons", "raven"], "raven",
               lambda n: "/Full Spritesheet/" in n and n.lower().endswith(".png"))
    simple_zip("kenney_interface-sounds.zip", ["audio", "ui", "kenney"], "kenney", lambda n: n.lower().endswith(".ogg"))
    simple_zip("Enemy_Animations_Set.zip", ["pixel", "enemies", "enemy_animations_set"], "enemy_anim")
    simple_zip("2D Pixel Dungeon Asset Pack v2.0.zip", ["pixel", "tilesets", "pixel_dungeon"], "pixel_dungeon",
               lambda n: n.lower().endswith(".png") and ("character and tileset/" in n or "Character_animation/" in n), flatten=False)
    fonts()
    kit()
    if "--no-music" not in sys.argv:
        music()
    print("imported")


if __name__ == "__main__":
    main()


# --- registry (same schema as tools/Import-Asset.ps1) ---------------------------------------------
REGISTRY = [
    # id, name, kind, zip, source, author, license, license_url, path, notes
    ("ninja-adventure", "Ninja Adventure Asset Pack (monsters, bosses, FX, SFX)", "enemies", NINJA,
     "https://pixel-boy.itch.io/ninja-adventure-asset-pack", "pixel-boy & AAA", "CC0 1.0",
     "https://creativecommons.org/publicdomain/zero/1.0/", "assets/pixel/enemies/ninja", "Selection only (tools/import_packs.py)."),
    ("dragon-regalia-gui", "Tiny RPG Dragon Regalia GUI", "ui", "tinyRPG_dragonRegaliaGUI_v1_0.zip", "https://tiny-rpg.itch.io",
     "Tiny RPG", "CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/", "assets/pixel/ui/dragon_regalia", ""),
    ("kurai-skill-icons", "Free RPG Skill Icons", "ui", "FREE RPG SKILL ICONS 32x32.zip", "https://kurai7.itch.io/rpg-skill-icons",
     "KURAI", "Author terms: commercial use, modify; no resale/redistribution", "", "assets/pixel/icons/kurai_skills", "Credit appreciated."),
    ("caz-mv-icons", "MV Icons Complete Sheet", "ui", "MV Icons Complete Sheet - Free Icons.zip", "https://cazwolf.itch.io",
     "Caz", "CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/", "assets/pixel/icons/caz_mv", "Attribution required."),
    ("raven-fantasy-icons", "Raven Fantasy Icons (free)", "ui", "Free - Raven Fantasy Icons.zip", "https://clockworkraven.itch.io",
     "Clockwork Raven Studios", "License held by the project owner (D-063)", "", "assets/pixel/icons/raven", ""),
    ("kenney-interface-sounds", "Interface Sounds", "audio", "kenney_interface-sounds.zip", "https://kenney.nl/assets/interface-sounds",
     "Kenney", "CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/", "assets/audio/ui/kenney", ""),
    ("xdeviruchi-music", "8-bit Fantasy & Adventure Music (2021)", "audio", "xDeviruchi - 8-bit Fantasy  & Adventure Music (2021).zip",
     "https://xdeviruchi.itch.io", "xDeviruchi", "CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/",
     "assets/audio/music/xdeviruchi", "Attribution required. 7 tracks converted WAV -> OGG, otherwise unchanged."),
    ("m5x7-font", "m5x7 font", "fonts", "m5x7.ttf", "https://managore.itch.io/m5x7", "Daniel Linssen", "CC0 1.0",
     "https://creativecommons.org/publicdomain/zero/1.0/", "assets/fonts", ""),
    ("m6x11-font", "m6x11 font", "fonts", "m6x11.ttf", "https://managore.itch.io/m6x11", "Daniel Linssen",
     "License held by the project owner (D-063)", "", "assets/fonts", "Credit Daniel Linssen."),
    ("enemy-animations-set", "Enemy Animations Set (skeletons, vampire)", "enemies", "Enemy_Animations_Set.zip", "itch.io",
     "unknown author", "License held by the project owner (D-063)", "", "assets/pixel/enemies/enemy_animations_set", ""),
    ("2d-pixel-dungeon", "2D Pixel Dungeon Asset Pack v2.0", "tilesets", "2D Pixel Dungeon Asset Pack v2.0.zip", "https://pixel-poem.itch.io",
     "Pixel_Poem", "License held by the project owner (D-063)", "", "assets/pixel/tilesets/pixel_dungeon", "Prepared for the dungeon biome."),
]


def register():
    import datetime, hashlib, json
    reg_path = os.path.join(ROOT, "assets", "ASSET_REGISTRY.json")
    data = json.load(open(reg_path, encoding="utf-8-sig"))
    items = data["assets"]
    today = datetime.date.today().isoformat()
    for (aid, name, kind, zname, source, author, lic, lic_url, path, notes) in REGISTRY:
        src = os.path.join(SRC, zname)
        sha = hashlib.sha256(open(src, "rb").read()).hexdigest().upper()
        old = next((a for a in items if a.get("id") == aid), None)
        files = sum(len(f) for _, _, f in os.walk(os.path.join(ROOT, path)))
        entry = {"id": aid, "name": name, "kind": kind, "source": source, "author": author, "license": lic, "license_url": lic_url,
                 "frame_size": 0, "modified": "copies in assets/processed only", "notes": notes, "status": "Imported", "sha256": sha,
                 "original_file": zname, "path": path, "files": files, "license_file_in_pack": True,
                 "imported": old["imported"] if old else today, "updated": today}
        items = [a for a in items if a.get("id") != aid] + [entry]
    data["assets"] = items
    with open(reg_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    md = ["# Credits", "", "Generated by tools\Import-Asset.ps1 / tools\import_packs.py from assets\ASSET_REGISTRY.json. Do not edit by hand.", ""]
    for a in sorted(items, key=lambda a: a["name"]):
        lic = "[%s](%s)" % (a["license"], a["license_url"]) if a.get("license_url") else a["license"]
        md.append("- **%s** by %s - %s - %s (%s)" % (a["name"], a["author"], lic, a["source"], a["status"]))
    with open(os.path.join(ROOT, "assets", "CREDITS.md"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(md) + "\n")
    print("registered", len(REGISTRY))


if __name__ == "__main__" and "--register" in sys.argv:
    register()
