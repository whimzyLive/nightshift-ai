## 06 · Conversational FAQ

Bold questions, brief answers. The page reads like an honest interview with the product. Often each Q/A is a collapsible accordion.

- **Heading:** each section _is_ a question — a short, direct phrase ending in `?`.
- **Body:** answer in 2–4 short paragraphs immediately below the question.
- **Divider:** thin rule between Q/A pairs, or zero rule and a paper-colour swap.
- **Button:** typographic link inside answers ("Read the full policy →"); one outlined CTA at the foot.
- **Image:** sparse — maybe one diagram per long answer; mostly text.
- **Reveal:** none on load; accordion expand uses 200 ms `--ease-out` on `grid-template-rows: 0fr → 1fr`.

Reach for it near pricing, for products that meet skepticism, for educational/regulated industries.

Avoid as the _primary_ page. FAQ usually pairs with another macrostructure that opens the page.

Reference: many SaaS pricing pages, Casper, Substack help pages.

**Sample opening lines** (imitate the _specificity_ — questions are real questions, answers are short and concrete):

> _"What is this for? — A single-binary CLI for parsing log streams from stdin."_ — names the form factor, names the input
> _"How is this different from X? — It's about time."_ — cron.com — answers obliquely, with a phrase that has weight
> _"Who built this? — Three of us, in Lisbon, since 2014."_ — date + place + count, no marketing

```html
<section class="faq">
  <details>
    <summary><h2>How long does setup take?</h2></summary>
    <div class="answer">…</div>
  </details>
  <details>…</details>
</section>
```

---
