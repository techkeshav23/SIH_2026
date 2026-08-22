# KalaSetu — UI Audit & Feature Map
### Multi-agent examination: what we HAVE vs what a professional app SHOULD have

> Produced by a 4-agent audit (inventory · artisan gaps · buyer gaps · cross-cutting/accessibility).
> Prioritised for SIH PS 26090 (low-literacy artisans, MoSJE) — the scoring axis rewards
> **voice-first, multilingual, accessible, real AI, govt-integrated**.

---

## ✅ What we HAVE today

**Screens (8):** Login (role toggle + OTP + demo mode) · Home (product list, offline drafts) ·
Create/Studio (photo→AI enhance, text→AI listing EN+HI, price suggest, publish) ·
Product Detail (edit listing/price, publish) · Dashboard (earnings + stat cards) ·
Incoming Orders (accept/reject) · Marketplace (feed + B2B inquiry) · Buyer Home (browse + order + pay).

**Navigation:** artisan sidebar (drawer) + bottom nav (4 tabs); buyer sidebar + bottom nav (2 tabs).

**Systems:** warm design system + reusable components (KHeader/KCard/KStatusPill/KNetImage/K states/confirmDialog) ·
demo mode (fully offline canned data) · offline draft queue + sync · role-aware auth + token refresh ·
status pills localized (hi/en) · price/qty validation · confirm dialogs · error/empty/loading states.

**Backend wired:** OTP auth (both roles) · product CRUD · AI (image enhance, text catalog, pricing) ·
order lifecycle (accept→pay→paid) · mock payments · dashboard stats · buyer feed + inquiry.

---

## ❌ What's MISSING — prioritised

### 🔴 P0 — highest leverage (PS scoring + credibility)
| # | Feature | Why it matters | Effort |
|---|---|---|---|
| 1 | **Real voice cataloging** (mic + record UI, waveform, re-record) | Flagship AI feature is currently a *stub* ("coming soon") + text box — undercuts the whole low-literacy premise. Backend `catalogFromVoice` exists, unused. | L |
| 2 | **Full Hindi localization** | Hindi is the default, yet ~85% of screens render hardcoded English once past the headers (dashboard, orders, market, buyer, detail, all snackbars/dialogs). Biggest PS-fit gap. | L |
| 3 | **Text-to-speech "read aloud"** on every screen | Core low-literacy accessibility — icon+voice must replace reading. Zero audio output today. | M |
| 4 | **Buyer Product Detail Page** (+ make tiles tappable) | Buyers can't even open a product (only an "Order" button). Biggest missing marketplace surface. | M |
| 5 | **Search + category filters** | `buyerFeed(category:)` already supported by API but no UI. Grid-only browse doesn't scale. Cheap, high-leverage. | S/M |
| 6 | **Onboarding + language picker** (first-run, voice-narrated) + camera/mic permission priming | Users land cold; a 3-slide icon+audio intro + explicit language choice sets up every downstream low-literacy interaction. | M |
| 7 | **Profile / Shop setup + Settings screen** | `UserModel` has name/craftType/region but no screen to edit them; no settings home for language/text-size/read-aloud. Buyer trust needs the artisan story. | M |
| 8 | **Order detail + status timeline** (both sides) | Orders are single accept/reject cards; tapping does nothing. No view of buyer, product, or where an order stands. | M |

### 🟡 P1 — strongly expected / differentiators
- **Notifications centre + push + unread badge** (order/inquiry/payment events surface nowhere) — L
- **Payout details: bank/UPI + Aadhaar KYC** capture (earnings shown but no way to get paid) — M
- **Multiple product images + gallery-vs-camera** (single, camera-only today) — M
- **Ratings & reviews** (zero trust signals) — M/L
- **Artisan storefront page** ("all products by this seller", story, region) — M
- **Help & Support** (IVR/toll-free callback + how-to videos) — S
- **Product delete / unlist / out-of-stock** (only create + edit-price today) — S
- **Real before/after image slider** (currently a static placeholder) — S
- **Pricing explainability UI** (comparables, confidence, "why this price") — M
- **Fulfilment / mark-shipped step** on accepted orders (lifecycle dead-ends at `accepted`) — M
- **DPDP consent screen** (govt product handling voice/photos/PII) — S
- **Cart & multi-item checkout** (buyer, one-at-a-time today) — L
- **Buyer profile + saved addresses** (orders have no delivery destination) — M
- **Semantics/labels on icon-only controls** (TalkBack reads nothing) — M
- **Large-text / high-contrast mode + 48dp tap targets** — M

### 🟢 P2 — polish & maturity
- Dark mode · Haptics + micro-interactions · Skeleton loaders · quality Devanagari/regional font ·
  product variants (size/colour) · share product/storefront deep-link · wishlist ·
  B2B RFQ/quote-negotiate + MOQ/tiered pricing · delivery/pincode estimate ·
  real UPI payment options · unify the two marketplace surfaces (buyer "Order" vs artisan "Inquire").

---

## 🎯 Recommended next batch (best ROI for the demo/pitch)
A tight, high-impact set that hits the PS scoring axis and looks like a real app:

1. **Buyer Product Detail Page + tappable tiles** (P0-4) — unlocks the whole buyer half
2. **Search + category chips** (P0-5) — cheap, instantly feels like a marketplace
3. **Profile/Shop + Settings screen** (P0-7) — fills the biggest "missing screen" hole
4. **Order detail + timeline** (P0-8) — makes orders feel real
5. **Full Hindi localization** (P0-2) — the single biggest PS-fit win
6. **Read-aloud (TTS)** (P0-3) — signature low-literacy feature

*(Voice cataloging (P0-1) needs a new recorder package — worth doing but slightly higher risk after the earlier `record` build conflict; recommend as a focused follow-up.)*

---
*Audit v1 · read-only · no code changed.*
