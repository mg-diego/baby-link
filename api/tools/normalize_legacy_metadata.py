"""Normaliza los metadatos con formatos antiguos (importación del CSV) al formato de la app.

- Pañales: condition "pee" / "poo" / "both, pee:medium..." / "seco" -> wet / dirty / mixed / clean
- Lactancia: type "breast" -> "nursing"; lado en condition (L/R/Both) -> side (Izquierdo/Derecho/Ambos)

Es reversible: el valor original se guarda en metadata._legacy y `--revert` lo restaura.

Uso (desde api/):
    python -m tools.normalize_legacy_metadata --baby-id <uuid>            # simulación (no escribe)
    python -m tools.normalize_legacy_metadata --baby-id <uuid> --apply
    python -m tools.normalize_legacy_metadata --baby-id <uuid> --revert
"""
import argparse
from collections import Counter

from services.analytics.diapers import DiaperStats

LEGACY_KEY = "_legacy"
DIAPER_KIND_TO_CONDITION = {"wet": "wet", "dirty": "dirty", "mixed": "mixed", "dry": "clean"}
SIDES = {"l": "Izquierdo", "left": "Izquierdo", "r": "Derecho", "right": "Derecho", "both": "Ambos"}


MISSING_KEY = "_missing"  # claves que no existían antes (revert las elimina)


def _remember(meta: dict, legacy: dict, key: str) -> None:
    """Guarda el valor original de `key` (o que no existía) la primera vez que se toca."""
    if key in legacy or key in legacy.get(MISSING_KEY, []):
        return
    if key in meta:
        legacy[key] = meta[key]
    else:
        legacy.setdefault(MISSING_KEY, []).append(key)


def normalize(category: str, metadata: dict | None) -> dict | None:
    """Metadata normalizada, o None si ya está bien o no se sabe interpretar."""
    meta = dict(metadata or {})
    legacy = dict(meta.get(LEGACY_KEY) or {})
    changed = False

    if category == "diaper":
        target = DIAPER_KIND_TO_CONDITION.get(DiaperStats._diaper_kind(meta))
        if target and meta.get("condition") != target:
            _remember(meta, legacy, "condition")
            meta["condition"] = target
            changed = True

    elif category == "feed":
        if str(meta.get("type") or "").lower() == "breast":
            _remember(meta, legacy, "type")
            meta["type"] = "nursing"
            changed = True
        side = SIDES.get(str(meta.get("condition") or "").strip().lower())
        if meta.get("type") == "nursing" and side and not meta.get("side"):
            _remember(meta, legacy, "condition")
            _remember(meta, legacy, "side")
            meta["side"] = side
            meta.pop("condition")
            changed = True

    if not changed:
        return None
    meta[LEGACY_KEY] = legacy
    return meta


def revert(metadata: dict | None) -> dict | None:
    meta = dict(metadata or {})
    legacy = dict(meta.pop(LEGACY_KEY, None) or {})
    if not legacy:
        return None
    for key in legacy.pop(MISSING_KEY, []):
        meta.pop(key, None)
    meta.update(legacy)
    return meta


def main():
    from core.pagination import fetch_all
    from dependencies import get_supabase

    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--baby-id", required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="escribir los cambios")
    mode.add_argument("--revert", action="store_true", help="deshacer una normalización anterior")
    args = parser.parse_args()

    db = get_supabase()
    rows = fetch_all(lambda: (
        db.table("baby_events").select("id, category, metadata")
        .eq("baby_id", args.baby_id).in_("category", ["diaper", "feed"]).order("id")
    ))

    changes, summary = [], Counter()
    for row in rows:
        new = revert(row["metadata"]) if args.revert else normalize(row["category"], row["metadata"])
        if new is None:
            continue
        old = row["metadata"] or {}
        if args.revert:
            summary[(row["category"], "revert")] += 1
        else:
            field = "condition" if row["category"] == "diaper" else ("side" if "side" in new and "side" not in old else "type")
            summary[(row["category"], f"{old.get('condition') if field != 'type' else old.get('type')} -> {new.get(field)}")] += 1
        changes.append((row["id"], new))

    for (category, change), count in sorted(summary.items(), key=lambda kv: -kv[1]):
        print(f"  {category:<7} {change:<45} {count:>6}")
    print(f"\n{len(changes)} de {len(rows)} eventos cambiarían.")

    if not (args.apply or args.revert):
        print("Simulación: no se ha escrito nada. Añade --apply para aplicarlo.")
        return
    for i, (event_id, metadata) in enumerate(changes, 1):
        db.table("baby_events").update({"metadata": metadata}).eq("id", event_id).execute()
        if i % 200 == 0:
            print(f"  {i}/{len(changes)}")
    print("Hecho.")


if __name__ == "__main__":
    main()
