# Atomic Design — Expanded Hierarchy Reference

Detailed, framework-neutral guidance for each of the five atomic design levels. See
[../SKILL.md](../SKILL.md) for the overview, decomposition workflow, and decision heuristics — this
file expands each level with its definition, defining trait, an abstract example, and the boundary
rule that separates it from the level above.

## Atoms

**Definition:** the smallest indivisible UI building blocks — a piece of text, a single input
field, a single control, an icon. Atoms are the raw materials; on their own they're often not very
useful, but every larger piece is built from them.

**Defining trait:** an atom has no meaningful sub-parts. It cannot be split further without losing
its function — splitting an atom yields fragments, not smaller working pieces.

**Abstract example:** a single label element, a single text-input control, a single button
control, a single icon glyph. Each stands alone as one functional unit.

**Boundary rule:** if an element has no internal composition worth naming separately, it stays an
atom. The moment you find yourself describing it as "two things working together," it has crossed
into molecule territory.

## Molecules

**Definition:** a small group of atoms bonded together to accomplish one specific, reusable
purpose. Molecules give atoms context and start to become genuinely useful pieces of interface.

**Defining trait:** a molecule combines two or more atoms for a single job, and that job is
reusable across different contexts — the same molecule can be dropped into many organisms
unchanged.

**Abstract example:** a _search-field_ molecule composed of a _label_ atom, a _text-input_ atom,
and a _button_ atom, all working together to accept and submit a search query.

**Boundary rule:** a grouping becomes a molecule once at least two atoms combine for one clear,
reusable purpose. If the grouping only makes sense in one specific place and isn't reused, it may
still just be an ad hoc arrangement of atoms rather than a true molecule — but naming it as a
molecule is still useful once it has a single clear responsibility.

## Organisms

**Definition:** relatively complex groupings of molecules and/or atoms that form a distinct,
identifiable section of an interface. Organisms are the sections a user would point to and name —
"the header," "the results list," "the summary panel."

**Defining trait:** an organism forms a standalone, recognisable region on its own. Unlike a
molecule, it isn't just a small reusable helper — it's a complete section that could be described
independently of the rest of the layout.

**Abstract example:** a page header organism composed of a logo atom, a navigation-links molecule,
and a search-field molecule, together forming the recognisable top section of a screen. Another
example: a grid of item-summary organisms, each built from an image atom, a title atom, and a
price molecule.

**Boundary rule:** a grouping becomes an organism once it reads as a standalone, nameable region of
the interface rather than a small supporting helper. If you could point at it and say "that's the
X section," it's an organism.

## Templates

**Definition:** page-level layout skeletons that place organisms into a structure, using
placeholder content rather than real data. Templates focus purely on arrangement — where each
organism sits relative to the others.

**Defining trait:** templates are concerned with structure and arrangement, not with real,
specific content. A template answers "what goes where," not "what does it say."

**Abstract example:** a listing-page template that arranges a header organism at the top, a filter
organism along one side, and a placeholder grid of item-summary organisms in the main area — with
generic filler text and images standing in for real content.

**Boundary rule:** as long as the content shown is generic or placeholder, the artifact is a
template. The moment the placeholders are replaced with real, specific content, it stops being a
template.

## Pages

**Definition:** specific instances of a template populated with real, representative content.
Pages are what an actual user ultimately sees and interacts with.

**Defining trait:** a page is the concrete, testable end state of the system — real headlines,
real prices, real user data occupying the template's structure.

**Abstract example:** the listing-page template above, rendered with an actual set of items, real
prices, and real images — this concrete, filled-in version is the page.

**Boundary rule:** a page is the same structure as its template, but with every placeholder
replaced by real, representative content. Pages are also where the whole system gets validated —
real content can reveal layout problems (overflow, awkward wrapping, uneven lengths) that
placeholder content in a template never would.
