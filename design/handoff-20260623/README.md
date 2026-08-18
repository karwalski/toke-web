# Handoff: toke — Website rebuild (Coin Gold identity)

## Overview
This package contains the locked **toke** brand identity ("Coin Gold") and a full style guide, prepared so you can rebuild the toke marketing/docs website to match. toke is a programming language designed from first principles to minimise the number of tokens an LLM has to generate — 40–75% fewer than Python, C, or Java for an equivalent program. The brand metaphor is **a token is currency**: a minted coin, an arcade payout, an "admit one" ticket — value, earned and not wasted.

## About the design files
The files in this bundle are **design references created in HTML** — they show the intended look, type, colour, and voice of the brand. They are **not** production code to copy verbatim. Your task is to **recreate this identity in the website's target environment** using its established patterns and component library. If no codebase exists yet, pick the most appropriate stack (e.g. Next.js + Tailwind, or Astro for a docs/marketing site) and implement the system there. Re-derive the tokens below into that stack's idioms (CSS variables, Tailwind theme, etc.) rather than pasting inline styles.

> Note on existing site: the current tokelang.dev styling/colours can be **disregarded** — this Coin Gold system replaces them.

## Fidelity
**High-fidelity.** Colours, typography, spacing, and component treatments are final. Reproduce them exactly. The HTML guide is the source of truth for hex values and type; this README restates them so you can implement from the README alone.

---

## Design tokens

### Colour — light mode
| Token | Hex | Role |
|---|---|---|
| `--bg` | `#FBF7EF` | Page background (warm cream) |
| `--surface` | `#FFFFFF` | Cards, panels |
| `--ink` | `#1A1712` | Primary text |
| `--muted` | `#6B6356` | Secondary text |
| `--hairline` | `#ECE5D7` | Borders, dividers |
| `--gold` | `#E0A82E` | Primary accent (buttons, badges, coin) |
| `--gold-deep` | `#C68A1A` | Links & gold text on light (AA-safe) |
| `--on-gold` | `#14110B` | Text/icons on a gold fill |

### Colour — dark mode (primary surface for the brand)
| Token | Hex | Role |
|---|---|---|
| `--bg` | `#14110B` | Page background (espresso) |
| `--surface` | `#1F1A11` | Cards, panels |
| `--elevated` | `#2A2317` | Elevated surfaces & borders/lines |
| `--text` | `#F5EFE2` | Primary text |
| `--muted` | `#9A9082` | Secondary text |
| `--gold` | `#F0C04A` | Accent, brightened so it carries on dark |
| `--on-gold` | `#14110B` | Text/icons on a gold fill |

### Colour — secondary / accents
| Token | Hex | Role |
|---|---|---|
| `--ticket-red` | `#E5533C` | **Optional secondary**, reserved for the "admit one" / ticket motif ONLY. Never for UI state or general accent. |
| `--syntax-type` (light) | `#2F8F7F` | Code: types & values |
| `--syntax-type` (dark) | `#6FC2B2` | Code: types & values |

**Usage rule:** gold is an accent, never a background field — keep it to ~10% of any surface so it stays valuable. Lead with espresso (dark) or cream (light). Don't set body copy in gold; don't use off-system gradients; don't flood backgrounds in gold.

### Typography
Two families, two jobs.
- **JetBrains Mono** — the "machine" voice: wordmark, code, numerals, labels/eyebrows. Weights 400 / 500 / 700 / 800. Display/wordmark uses ExtraBold (800) with **−4px** tracking at large sizes (scale tracking down proportionally; ~−2 to −3px at 40–54px).
- **Space Grotesk** — the "human" voice: headlines, UI, body, marketing. Weights 400 / 500 / 600 / 700.

Google Fonts import:
```
https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;700;800&display=swap
```

Type scale (font-family / size / weight / tracking):
| Role | Family | Size | Weight | Tracking | Notes |
|---|---|---|---|---|---|
| Display / wordmark | JetBrains Mono | 56–76px | 800 | −4px | lowercase always |
| H2 | Space Grotesk | 34px | 700 | −1px | |
| H3 / lockup | JetBrains Mono | 28–54px | 800 | −2 to −3px | |
| Body | Space Grotesk | 16px | 400 | 0 | line-height 1.6–1.7, color `--muted` on light |
| UI / button | Space Grotesk | 14px | 600 | 0 | |
| Label / eyebrow | JetBrains Mono | 12px | 500–700 | +2px | UPPERCASE, color `--gold-deep` |
| Caption | — | 13px | 400 | 0 | color `--muted` |

### Spacing & radius
- Section vertical rhythm: ~56px top padding, dividers via 1px `--hairline`.
- Card padding: 20–32px depending on density.
- Radius: **8px** for cards/panels/buttons, **10px** for larger framed panels, **999px** for pills/badges, **50%** for the coin.
- Gaps: use fl/grid `gap` of 12–20px between sibling cards; 40px between major columns.
- Shadows: the brand is largely flat/bordered. Use borders (`--hairline` light / `--elevated` dark) over drop shadows. The coin is the one place for depth (see below).

---

## The logo / wordmark
- Always lowercase **toke**, JetBrains Mono ExtraBold, tight negative tracking.
- The **coin** is a gold sphere to the left of the wordmark; its diameter == the wordmark's cap-height.
  - Light coin gradient: `radial-gradient(circle at 34% 32%, #F6D277 0%, #E0A82E 48%, #B07D15 100%)` + `inset 0 -2px 4px rgba(0,0,0,.22)`.
  - Dark coin gradient: `radial-gradient(circle at 34% 32%, #F6D277 0%, #F0C04A 48%, #C68A1A 100%)` + glow `0 0 18px rgba(240,192,74,.45)`.
- **Clearspace:** one coin-diameter on all sides.
- **Minimum size:** 17px tall (digital) / 8mm (print).
- **Don'ts:** no uppercase/capitalisation; never set the wordmark in the sans; never recolour the coin.

## Code blocks & syntax
Code is the product — give it a restrained **three-colour** scheme, never rainbow highlighting:
| Class | Light | Dark | Applies to |
|---|---|---|---|
| Sigils & keywords | `#C68A1A` | `#F0C04A` | `m=` `f=` `$` `<` (return) |
| Types & values | `#2F8F7F` | `#6FC2B2` | `i64` `@i64` `0` |
| Punctuation | `#a39a88` (light) | `#7c7768` (dark) | `; { } ( ) :` |
| Identifiers / base | `#3a352b` (light) | `#d8d0c0` (dark) | names |

Code block chrome: rounded 10px container, header bar with three muted dots + filename (e.g. `sum.tk`) + a gold token-count pill on the right (e.g. `13 toke tok`). Real toke syntax to use in examples:
```
m=sum;
f=sum(arr:@i64):i64{
  $t:i64=0;
  <t;};
```
Context: `<0;` is `return 0;` (4 tokens → 1), and the close pattern `<0;}` collapses to a single token under toke's purpose-built BPE tokenizer. Other real tokens: `m=` (module), `f=` (function), `$` type sigils, `@()` arrays, `.tki` interface contracts, `--legacy` flag (80-char profile vs the default 55-char "toke").

## Voice & persona
**Terse. Exact. Dry.** A senior engineer who stopped trying to impress you and just tells you the number. Four principles: (1) Economical — cut every token that doesn't earn its place; (2) Exact — real numbers over adjectives (40–75%, not "tons"); (3) Confident — state it plainly, no hype, no exclamation marks; (4) Dry wit — a flat one-liner beats a slogan.

- **Sounds like toke:** "40–75% fewer tokens than Python." · "`return 0;` is four tokens. We made it one." · "Compiles correctly 100% of the time. We checked."
- **Not toke:** "The revolutionary, game-changing AI-first language!" · "Unleash unlimited productivity 🚀" · "honestly kind of a big deal you guys." (No emoji, no exclamation, no hype.)

Approved descriptor line: **"A language built for AI."** Brand line: **"Write less. Mean more."** / "A token is currency. Spend it well."

## Components (states)
- **Primary button:** gold fill (`--gold` light / `#F0C04A` dark), `--on-gold` text, 8px radius, 11px × 20px padding, Space Grotesk 600/14px. Hover: darken ~6%.
- **Secondary button:** transparent, 1.5px border (`--ink` light / `#4a4231` dark), matching text colour.
- **Tertiary/link button:** `--gold-deep` (light) / `#F0C04A` (dark) text, trailing "→".
- **Badge / pill:** 999px radius, JetBrains Mono. Gold filled (`−42% tokens`), neutral filled (`v0.3 default`), outline (`--legacy`), and the red `admit one` (ticket motif only).
- **Ticket motif:** espresso card split by a vertical dashed perforation (`2px dashed #3a3221`); left stub = `ADMIT ONE` eyebrow + gold value; right stub = vertical mono code (`<0;}`).
- **Coin:** see logo section — also used solo as app icon / favicon.

## Screens to build (suggested site map)
These weren't designed as final pages — recreate the *system* across the standard marketing/docs structure. Apply the tokens above.
- **Home / hero** — dark espresso hero, big coin + wordmark, "A language built for AI." descriptor, the −42% / admit-one / version pills, primary + secondary CTA, a live code block showing token savings.
- **Why toke / token economics** — the "token is currency" explainer, before/after token counts (Python `return 0;` vs `<0;`), the 40–75% stat.
- **Docs** — light cream surface, mono labels/eyebrows in gold-deep, three-colour code blocks, `.tki` interface contracts, stdlib (30+ modules).
- **Playground / API** — console.tokelang.dev style: API key, free tier (1,000 tokens / 6 hrs), `api.tokelang.dev/v1/generate` example; `toke-7b-gate2` model.

## Files in this bundle
- `toke Style Guide.dc.html` — the full style guide (source of truth). Open in a browser to see every token, lockup, and component rendered.
- `toke Brand Colours.dc.html` — the original four-direction colour exploration; **Option A · Coin Gold** is the locked choice. Kept for context only.
- `support.js` — runtime needed to open the `.dc.html` files locally. Not part of the website; reference only.

## Assets
No raster/vector assets ship in this bundle — the coin is pure CSS (radial-gradient sphere) and can be reproduced as such or exported to SVG/PNG for favicon use. All fonts are Google Fonts (free). Imagery on the real site should use real product screenshots / terminal captures, not decorative stock.
