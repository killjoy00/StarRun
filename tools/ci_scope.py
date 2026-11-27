#!/usr/bin/env python3
"""Conservative, auditable PR test selection; uncertainty runs every gate."""
import argparse
import os
import re
import subprocess

FLAGS = ("ordinary", "routes", "archive", "fleet", "progression", "endless", "native")
BALANCE = set(FLAGS) - {"native"}
ARCHIVE_FUNCTIONS = {
    "archive_challenge_active", "archive_boss_reworked", "archive_attack_pressure",
    "archive_precise_counter_window", "archive_counter_exposure", "archive_missed_exposure",
    "archive_sealed_factor", "archive_exposed_damage_factor", "_archive_index_fire",
    "_update_archive_attack", "_resolve_archive_attack", "_counter_archive_attack",
}
PRESENTATION = {
    "scripts/main.gd", "scripts/playfield.gd", "scripts/combat_hud.gd",
    "scripts/audio.gd", "scripts/sound.gd", "scripts/game_center_bridge.gd",
}


def git(*args):
    return subprocess.check_output(["git", *args], stderr=subprocess.PIPE).decode()


def sections(text):
    # Include the complete preamble and all function bodies, including comments.
    # Renames, additions, deleted functions and shared helpers are not whitelisted.
    matches = list(re.finditer(r"(?m)^func ([A-Za-z0-9_]+)\(", text))
    out = {"<preamble>": text[:matches[0].start()] if matches else text}
    for i, m in enumerate(matches):
        name = m.group(1)
        if name in out:
            raise ValueError("duplicate function")
        out[name] = text[m.start():matches[i+1].start() if i+1 < len(matches) else len(text)]
    return out


def archive_only(before, after):
    a, b = sections(before), sections(after)
    changed = {k for k in a.keys() | b.keys() if a.get(k) != b.get(k)}
    return a.keys() == b.keys() and bool(changed) and changed <= ARCHIVE_FUNCTIONS


def select(paths, read_pair):
    active = set()
    for path in paths:
        if path == "scripts/simulation.gd":
            before, after = read_pair(path)
            active |= {"archive", "native"} if archive_only(before, after) else set(FLAGS)
        elif path == "scripts/hidden_sector.gd":
            active |= {"archive", "native"}
        elif path in PRESENTATION:
            # All core UI/settlement/parse checks still run in Playable.
            active.add("native")
        elif path.startswith(("scripts/", "data/")) or path == "project.godot":
            active |= set(FLAGS)
        elif path.startswith(("assets/", "scenes/", "addons/")) or path == "export_presets.cfg":
            active.add("native")
            if path.startswith("addons/"):
                active |= BALANCE
        elif path in {"tools/ci_scope.py", ".github/workflows/ci-scope.yml"}:
            active |= {"routes", "archive"}
        elif path in {"tests/balance_matrix.gd", "tools/install-godot.sh"}:
            active |= BALANCE
            if path.endswith(".sh"):
                active.add("native")
        elif path in {"tests/checkpoint_expeditions.gd", "tools/checkpoint_expeditions_summary.py", ".github/workflows/checkpoint-expeditions.yml", ".github/workflows/destination-smoke.yml"}:
            active.add("routes")
        elif path in {"tests/archive_campaign.gd", ".github/workflows/archive-smoke.yml", ".github/workflows/archive-integration-review.yml"}:
            active.add("archive")
        elif path in {"tests/expedition_endless.gd", "tools/expedition_endless_summary.py", ".github/workflows/expedition-endless.yml"}:
            active.add("endless")
        elif path in {"tools/progression_run_summary.py", ".github/workflows/player-progression.yml"}:
            active.add("progression")
        elif path in {".github/difficulty-experiment.json", "tools/difficulty_summary.py", ".github/workflows/difficulty-experiment.yml"}:
            active.add("fleet")
        elif path == ".github/workflows/playable.yml":
            # CI policy changes must exercise the full ordinary campaign and exports on PR/main.
            active |= {"ordinary", "native"}
        elif path.startswith(("tools/ios-", "tools/android-", "tools/generate-", "native/", "ios/", "android/")) or path in {".github/workflows/ios-build.yml", ".github/workflows/android.yml"}:
            active.add("native")
        elif path.startswith(("docs/", "tests/", ".github/")) or path.endswith((".md", ".txt")):
            pass  # Core regression remains unconditional.
        else:
            # Unknown dependencies must never silently suppress gameplay checks.
            active |= set(FLAGS)
    return active


def self_test():
    a = "var hp = 1\nfunc archive_sealed_factor():\n\treturn 0.1\nfunc ordinary():\n\treturn 1\n"
    b = a.replace("0.1", "0.2")
    pair = lambda _: (a, b)
    assert select(["scripts/simulation.gd"], pair) == {"archive", "native"}
    assert select(["scripts/simulation.gd"], lambda _: (a, b.replace("return 1", "return 2"))) == set(FLAGS)
    assert select(["scripts/simulation.gd"], lambda _: (a, b.replace("hp = 1", "hp = 2"))) == set(FLAGS)
    assert select(["scripts/simulation.gd"], lambda _: (a, b + "func new_helper():\n\tpass\n")) == set(FLAGS)
    assert select(["scripts/hidden_sector.gd"], pair) == {"archive", "native"}
    assert select(["scripts/main.gd"], pair) == {"native"}
    assert select(["scripts/expedition_rules.gd"], pair) == set(FLAGS)
    assert select(["tests/archive_campaign.gd"], pair) == {"archive"}
    assert select(["docs/example.md"], pair) == set()
    assert select(["unknown.runtime"], pair) == set(FLAGS)
    assert select([".github/difficulty-experiment.json"], pair) == {"fleet"}
    assert select(["tests/balance_matrix.gd"], pair) == BALANCE
    assert select([".github/workflows/playable.yml"], pair) == {"ordinary", "native"}
    print("CI scope contract passed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", default="workflow_dispatch")
    parser.add_argument("--base", default="")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    paths = []
    reason = "explicit/manual full scope"
    active = set(FLAGS)
    if args.event in {"pull_request", "push"}:
        try:
            if not args.base or set(args.base) == {"0"}:
                raise ValueError("missing base")
            base = git("merge-base", args.base, args.head).strip() if args.event == "pull_request" else args.base
            paths = [p for p in git("diff", "--name-only", "--no-renames", "-z", base, args.head).split("\0") if p]
            active = select(paths, lambda p: (git("show", f"{base}:{p}"), git("show", f"{args.head}:{p}")))
            reason = "conservative change scope"
        except (OSError, subprocess.CalledProcessError, UnicodeError, ValueError) as exc:
            reason = f"could not classify safely: {type(exc).__name__}; running all gates"
    lines = [f"{name}={'true' if name in active else 'false'}" for name in FLAGS]
    print(reason, *paths, *lines, sep="\n")
    if os.getenv("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write("\n".join(lines) + "\n")
    if os.getenv("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write("## Test selection\n\n" + reason + "\n\n" + "\n".join("- " + line for line in lines) + "\n")


if __name__ == "__main__":
    main()
