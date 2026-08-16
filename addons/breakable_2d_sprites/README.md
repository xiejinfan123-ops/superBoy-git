# Breakable 2D Sprites

Traces a sprite's alpha-channel silhouette into a polygon, shatters it into Voronoi shards, and builds a ready-to-place, breakable scene from the result.

This file ships inside the addon itself, so it's here whether you installed via the Asset Library, copied the folder manually, or cloned the whole repo.

Requires Godot 4.6 or newer — tested on 4.6 and 4.7.1. (4.3–4.5 may work too since the only newer API used is `@export_storage`, but that's unverified. 4.0–4.2 definitely aren't supported.)

## 1. Enable the plugin

**Project → Project Settings → Plugins** → enable **Breakable 2D Sprites**.

A "Breakable 2D Sprites" tab appears in the editor dock (right side by default).

## 2. Trace a sprite

1. **Texture** — pick any sprite with a transparent background (drag from the FileSystem dock, or use the picker's browse button). The alpha channel is what gets traced.
2. **Item Name** — required; becomes the output filename.
3. Leave **Max Points** and **Target Scale (px)** at their defaults (`0` = unlimited / native pixel size) unless you specifically want to cap point count or normalize size across differently-sized sprites. **Alpha Threshold** and **Simplify (px)**, under the collapsed **Advanced** section, are edge-case knobs (soft/glowy edges, or wanting an exact simplification level) — hover either for a tooltip explaining when you'd actually need them.
4. Click **Generate Pieces**. This traces the silhouette *and* shatters it into shards in one step — the preview shows the outline plus the shard breakdown as colored, cracked-looking overlays.

## 3. Tune the shatter (optional)

Adjust **Shard Count** and **Random Seed** (use **Reroll** to try a new pattern at the same count) until it looks right. Above ~300 shards the editor will visibly pause for a moment — the underlying Voronoi construction cost grows roughly with the cube of shard count.

## 4. Build the scene

Click **Build Scene**. This saves `res://built_items/<item_name>.tscn` in *your* project — a fully self-contained scene, not a reference back to this addon.

## 5. Place it in your game

Drag that `.tscn` from the FileSystem dock into any scene. It appears immediately with the correct sprite, position, and collision shape — Build Scene pre-builds the visible nodes, so it's not an empty placeholder that only draws itself once you press Play. It's solid by default (blocks movement) as soon as it's placed. Resizing it afterward via the node's Transform/Scale works too — the sprite, collision, and (when it breaks) the pieces and their outward impulse all scale proportionally.

## 6. Make it breakable

Every built item's root is an `ItemShapeBreakableItem` (`extends StaticBody2D`). Pick **one** of these to trigger a break:

**Automatic (physics layer)** — select the placed item, open the Inspector's **Hit Detection** group, set **Hit Detection Mask** to whichever physics layer your bullets/projectiles are on. This starts at `0` (disabled) on purpose, so a freshly-placed item doesn't break itself against the floor it's resting on.

**Manual (from code)** — call `take_hit()` directly from any weapon, bullet, or hitscan script. Works no matter how your projectiles are built:

```gdscript
# e.g. inside a bullet's body_entered/area_entered handler
func _on_body_entered(body: Node) -> void:
    if body.has_method("take_hit"):
        body.take_hit(global_position)
    queue_free() # destroy the bullet
```

`global_position` just aims the outward impulse — shards nearer the hit fly harder.

### Other properties worth knowing (Inspector, grouped)

| Group | Property | Default | What it does |
|---|---|---|---|
| Hit Detection | `hits_to_break` | `1` | Raise for multi-hit items |
| Hit Detection | `required_group` | `""` | If set, an automatic hit only counts when the other body/area is also in this group |
| Break Physics | `min_impulse` / `max_impulse` | `80` / `220` | Outward force range applied to each shard |
| Break Physics | `piece_angular_impulse` | `4.0` | Random spin applied to shards |
| Break Physics | `piece_gravity_scale` | `0.6` | Gravity scale for spawned pieces |
| Break Physics | `piece_lifetime` | `6.0` | Seconds before a piece auto-frees; `0` = never (watch performance if you leave debris piling up) |

Connect the `broken(shard_count: int)` signal (fires right before the item frees itself) to trigger sound, particles, or scoring.

## What breaking actually does

The intact `StaticBody2D` swaps to one `RigidBody2D` per shard — each with its own correctly-UV-mapped `Polygon2D` and matching `CollisionPolygon2D` — flung outward from the impact point, then despawns itself.

## Testing without wiring it into a real level

`test_scene/breakable_sandbox.tscn` ships with the addon for exactly this: open it, drag a built `.tscn` in, press Play, and click it. It duck-types on `take_hit()`, so it works for whatever you drop in without any setup. `test_scene/sample_art/` has a few sprites with transparent backgrounds if you want something to trace immediately, before using your own art.

## License

MIT — see [LICENSE](LICENSE) (bundled in this folder, so it travels with the addon wherever it's installed).
