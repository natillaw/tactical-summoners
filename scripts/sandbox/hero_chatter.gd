class_name HeroChatter
extends RefCounted
## Immersive Hero AI dialogue and personality chatter system (D-013, D-016).
## Generates human-like banter, tower floor entry thoughts, and situational reactions.

const ENTRY_LINES := {
    "trait.brave": [
        "A relic in the depths? Let's carve our way through!",
        "No monster stands between us and the extraction zone.",
        "Forward! We seize glory on this floor."
    ],
    "trait.cautious": [
        "Quiet... I smell traps. Don't rush blindly into the dark.",
        "We know the goal is the extraction portal, but let's check every corner first.",
        "Stick close together. One wrong step and we're surrounded."
    ],
    "trait.greedy": [
        "I didn't climb this tower for fresh air. Where's the loot?",
        "Relic first, gold second. Or both at the exact same time!",
        "Someone better be paying us double for this floor."
    ],
    "trait.arrogant": [
        "Hhmpf. Mere pests infest this floor. Watch and learn how it's done.",
        "The objective is clear enough. Try not to slow me down.",
        "Child's play. Let's finish this quickly."
    ],
    "trait.gloomy": [
        "Another floor of damp stone and inevitable doom...",
        "We know the goal, sure... but how many of us walk out alive?",
        "Don't get too attached to this room. It smells like a tomb."
    ],
    "trait.cheerful": [
        "Come on team, we've got this! Let's find that relic!",
        "Ooh, look at the architecture! Creepy, but exciting!",
        "Eyes up, smiles on! We'll reach the exit in no time!"
    ],
    "trait.hot_headed": [
        "Stop talking and let's start swinging!",
        "I see enemies, I hit enemies. Simple plan!",
        "Let's smash through their lines right now!"
    ]
}

const DEFAULT_ENTRY := [
    "We need to find the relic and reach the extraction point... but how do we get past them?",
    "Objective received: secure the artifact and escape. Let's move.",
    "This tower floor looks dangerous. Stay sharp."
]

static func get_entry_line(hero: HeroData) -> String:
    if hero == null:
        return "Let's move."
    for t in hero.traits:
        if ENTRY_LINES.has(t):
            var lines: Array = ENTRY_LINES[t]
            return String(lines[randi() % lines.size()])
    return String(DEFAULT_ENTRY[randi() % DEFAULT_ENTRY.size()])
