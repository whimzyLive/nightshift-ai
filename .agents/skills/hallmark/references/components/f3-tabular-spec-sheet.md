### F3 · Tabular spec sheet

Each row is a feature; columns hold name, value, footnote. Hairline rules between rows. Tabular numerics.
_Use when:_ features compare quantitatively.
_Don't confuse with:_ F1 Bento (which is non-tabular and visually rhythmic).

```html
<table class="spec-sheet tnum">
  <tr>
    <th>Latency</th>
    <td>p99 &lt; 50 ms</td>
    <td class="muted">measured externally</td>
  </tr>
  <tr>
    …
  </tr>
</table>
```
