class_name TitleScreen
extends Control
## Title screen (D-063): the tower portal of the kit, a few generated heroes idling in front of the
## forest, title music. Continue / New game / Options / Credits / Quit. New game asks before wiping.

signal navigate(screen: String, arg: int)

var _menu: GameMenu = null


func _ready() -> void:
    UIKit.music("title")
    var bg := ColorRect.new()
    bg.color = ArtPalette.INK
    add_child(bg)
    UIKit.fill(bg)
    var ground := ColorRect.new()
    ground.color = ArtPalette.GREEN[1]
    add_child(ground)
    ground.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    ground.offset_top = -110
    var portal := AnimatedSprite2D.new()
    var sf := SpriteFrames.new()
    var tex: Texture2D = load(AssetCatalog.world("tower_portal"))
    if tex != null:
        for i in 6:
            var at := AtlasTexture.new()
            at.atlas = tex
            at.region = Rect2(i * 32, 0, 32, 48)
            sf.add_frame("default", at)
        sf.set_animation_speed("default", 8.0)
        portal.sprite_frames = sf
        portal.scale = Vector2(3, 3)
        portal.position = Vector2(320, 190)
        portal.play()
        add_child(portal)
    for i in 5:
        var h := HeroGenerator.generate(9100 + i * 37, 1 + (i % 3))
        var s := AnimatedSprite2D.new()
        s.sprite_frames = SpriteComposer.build_frames(h)
        s.position = Vector2(200 + i * 60, 285)
        s.play("idle_down")
        add_child(s)
    var v := VBoxContainer.new()
    add_child(v)
    v.position = Vector2(20, 20)
    v.add_child(UIKit.label("Tactical Summoners", 28, UIKit.ACCENT))
    v.add_child(UIKit.label("A tower, a village and the people you call.", 14, UIKit.MUTED))
    if not Game.heroes.is_empty() or Game.onboarded:
        v.add_child(UIKit.button("Continue", func(): navigate.emit("town", 0), Vector2(260, 36)))
    v.add_child(UIKit.button("New game", _confirm_new, Vector2(260, 36)))
    v.add_child(UIKit.button("Options", func(): _open_menu("options"), Vector2(260, 36)))
    v.add_child(UIKit.button("Credits", func(): _open_menu("credits"), Vector2(260, 36)))
    v.add_child(UIKit.button("Quit", func(): get_tree().quit(), Vector2(260, 36)))


func _open_menu(page: String) -> void:
    _menu = GameMenu.new()
    _menu.leave_label = "Back"
    add_child(_menu)
    if page == "options":
        _menu.show_options()
    else:
        _menu.show_credits()


func _confirm_new() -> void:
    if Game.heroes.is_empty() and not Game.onboarded:
        Game.new_game()
        navigate.emit("welcome", 0)
        return
    var dlg := ConfirmationDialog.new()
    dlg.dialog_text = "Start a new account?\nThe current village, heroes and progress are erased."
    dlg.confirmed.connect(func():
        Game.new_game()
        navigate.emit("welcome", 0))
    add_child(dlg)
    dlg.popup_centered()
