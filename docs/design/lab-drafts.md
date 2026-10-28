# The Lab: three drafts (for Albert to choose)

Status: **mock-ups, nothing works yet** (2026-10-28). Albert: "a big animated sprite of Robbie in the middle, which
changes when we change upgrades... design the whole thing so that it is easy to use, intuitive... make 3 drafts".

All three share the room: the hangar behind the console, cold riveted steel, one warm work lamp over Bathy, and the
two wheels at the top right: what you **owe** the Company and what you have **in hand** to spend (see
`lab-parts-and-pay.md`). Bathy is the real model, rendered with the parts on: the Company's parts are navy enamel
and dark bronze, hung on his warm brass, so you can see at a glance what a hull carries. The parts and prices are the
ones in the parts list.

Images: `docs/art/lab/lab_draft_a.jpg`, `lab_draft_b.jpg`, `lab_draft_c.jpg` (all three: `lab_drafts_all.jpg`).
Drawn by `game/tools/lab_drafts.gd`; Bathy by `tools/art/lab_bathy.py`.

## A. The hoist (hands on)

Bathy hangs from a chain hoist under the lamp. Every part hangs on a **pegboard** on the left: the ones you own as
real parts, the rest as chalk outlines with a price tag. Type plates hang on a rack at the right, and below it is the
requisition hatch, where a form goes up the tube to buy something (or your scrip goes in against your debt).

- **To fit a part:** take it off the board and drag it onto Bathy. The socket it fits glows as you bring it near,
  and a grease-pencil note says what it changes. Let go and it clunks on, and Bathy's face reacts. Drag a part off
  him to take it off.
- **To buy:** tap a chalk outline and its form goes in the hatch. Press SEND UP.
- **What he'll be:** five dials on the bench (charge, hull, speed, noise, light), each with a red ghost needle where
  the part you're holding would put it.
- Good: the most physical and the warmest. It feels like a workshop, and very Papers, Please.
- Risky: dragging onto a small socket is fiddly on a tablet; with 40 parts the board gets crowded; prices and
  details hide on small tags.

## B. The catalogue (paperwork)

The Company's **equipment catalogue** lies open on the bench, with a tab for each socket and one each for type
plates and card-reader slots. Each page is one part: a big engraving of it, its name and price on the left, what it
does in plain words on the right, and a **NOW / WITH IT** table of what would change. Bathy turns on a turntable
beside it, and his **fitting sheet** is clipped to the wall: what's in each socket, with the one you're looking at
circled in red pencil.

- **To buy:** stamp REQUISITION on the page. The part comes down the tube.
- **To fit:** on a part you own, the stamp reads FIT instead.
- **To look round him:** drag Bathy on the turntable.
- Good: the easiest to read and compare (every number is right there); it fits the Company's voice; plenty of room
  for the strange parts' stories.
- Risky: page-turning is slow once you know what you want; Bathy is a picture beside the book, not the thing you
  work on.

## C. The socket ring (one tap at a time)

Bathy is big in the middle with his **six sockets** in a ring round him, each joined by a line to where it sits on
his hull: hatch, lamp, drive, tool, belly, hull. Tap a socket and a **drawer** of every part that fits it slides up
along the bottom, as cards: FITTED, owned (TAP TO FIT), for sale (BUY 4,000), or locked until a later sector. Tap a
card and Bathy changes at once, so you see him with it before you pay. The bars on the left show this hull now
(white) and with the card you tapped (amber, or red for what gets worse). The panel on the right holds your type
plates and reader slots.

- **To buy:** tap the card's price. **To fit:** tap a card you own. **To compare:** tap through the drawer and
  watch Bathy and the bars change.
- Good: the fastest and clearest on the tablet: big targets, two taps to anything, nothing to drag, and Bathy really
  is the middle of the screen; it grows easily (more parts are just more cards in the drawer).
- Risky: the most "game menu" of the three, the least like a place; the cards have room for one line of text.

## My recommendation

**C, dressed in A's room.** C is the one a player will understand in five seconds and use without thinking, and
the Lab will be visited after every sector, so speed matters most. Keep A's hoist and lamp as the room around it,
and borrow B's **NOW / WITH IT** table: a long press on a card opens it as a full catalogue page, with the part's
story.
