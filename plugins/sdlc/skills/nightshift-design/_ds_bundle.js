/* @ds-bundle: {"format":3,"namespace":"NightshiftDesignSystem_983007","components":[{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"InstallSnippet","sourcePath":"components/core/InstallSnippet.jsx"},{"name":"AgentCard","sourcePath":"components/data/AgentCard.jsx"},{"name":"CommandCard","sourcePath":"components/data/CommandCard.jsx"},{"name":"Table","sourcePath":"components/data/Table.jsx"},{"name":"Footer","sourcePath":"components/site/Footer.jsx"},{"name":"NavBar","sourcePath":"components/site/NavBar.jsx"},{"name":"CodeBlock","sourcePath":"components/terminal/CodeBlock.jsx"},{"name":"Pipeline","sourcePath":"components/terminal/Pipeline.jsx"},{"name":"Terminal","sourcePath":"components/terminal/Terminal.jsx"},{"name":"TermLine","sourcePath":"components/terminal/Terminal.jsx"}],"sourceHashes":{"components/core/Badge.jsx":"f7fb4f95a6e2","components/core/Button.jsx":"7c4be54db476","components/core/Card.jsx":"26bd77acef7a","components/core/InstallSnippet.jsx":"e6d80bbca7af","components/data/AgentCard.jsx":"6d687aa1a963","components/data/CommandCard.jsx":"d73420c1679a","components/data/Table.jsx":"3db859464453","components/site/Footer.jsx":"b7b269af9be5","components/site/NavBar.jsx":"866c034fce09","components/terminal/CodeBlock.jsx":"653d3fdf09a7","components/terminal/Pipeline.jsx":"bc0e7b7a8c12","components/terminal/Terminal.jsx":"ef67b5c2c997","ui_kits/docs/layout.jsx":"ee72a276097b","ui_kits/marketing/sections.jsx":"da5a4675df24"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.NightshiftDesignSystem_983007 = window.NightshiftDesignSystem_983007 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift Badge / Pill — compact status & metadata label.
 * Tones map to the semantic palette; `dot` adds a status indicator,
 * `mono` (default) gives the terminal-texture label look.
 */
function Badge({
  children,
  tone = 'neutral',
  dot = false,
  solid = false,
  mono = true,
  size = 'md',
  ...rest
}) {
  const tones = {
    neutral: {
      fg: 'var(--text-muted)',
      bg: 'rgba(255,255,255,0.05)',
      bd: 'var(--border-default)',
      dotc: 'var(--moon-400)'
    },
    accent: {
      fg: 'var(--terra-300)',
      bg: 'var(--terra-tint)',
      bd: 'var(--border-accent)',
      dotc: 'var(--accent)'
    },
    info: {
      fg: 'var(--indigo-300)',
      bg: 'var(--indigo-tint)',
      bd: 'rgba(124,147,240,0.4)',
      dotc: 'var(--indigo-400)'
    },
    success: {
      fg: 'var(--green-400)',
      bg: 'var(--green-tint)',
      bd: 'rgba(110,196,138,0.4)',
      dotc: 'var(--success)'
    },
    warning: {
      fg: 'var(--amber-400)',
      bg: 'var(--amber-tint)',
      bd: 'rgba(224,164,88,0.4)',
      dotc: 'var(--warning)'
    },
    danger: {
      fg: 'var(--red-400)',
      bg: 'var(--red-tint)',
      bd: 'rgba(224,101,111,0.4)',
      dotc: 'var(--danger)'
    }
  };
  const t = tones[tone] || tones.neutral;
  const pad = size === 'sm' ? '2px 8px' : '4px 10px';
  const fs = size === 'sm' ? 11 : 12;
  const solidStyle = solid ? {
    background: t.dotc,
    color: 'var(--text-on-accent)',
    borderColor: 'transparent'
  } : {
    background: t.bg,
    color: t.fg,
    borderColor: t.bd
  };
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      padding: pad,
      borderRadius: 'var(--radius-pill)',
      fontFamily: mono ? 'var(--font-mono)' : 'var(--font-sans)',
      fontSize: fs,
      fontWeight: 500,
      lineHeight: 1,
      letterSpacing: mono ? '0.02em' : '0',
      border: '1px solid',
      whiteSpace: 'nowrap',
      ...solidStyle
    }
  }, rest), dot && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: '50%',
      background: solid ? 'currentColor' : t.dotc,
      flex: 'none'
    }
  }), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift Button — the primary action primitive.
 * Variants: primary (terracotta), secondary (surface), ghost (text), danger.
 * Monospace label option for terminal/command affordances.
 */
function Button({
  children,
  variant = 'primary',
  size = 'md',
  mono = false,
  disabled = false,
  loading = false,
  iconLeft = null,
  iconRight = null,
  fullWidth = false,
  onClick,
  type = 'button',
  ...rest
}) {
  const sizes = {
    sm: {
      padding: '0 12px',
      height: 32,
      fontSize: 13,
      gap: 6,
      radius: 'var(--radius-sm)'
    },
    md: {
      padding: '0 18px',
      height: 40,
      fontSize: 14,
      gap: 8,
      radius: 'var(--radius-md)'
    },
    lg: {
      padding: '0 24px',
      height: 48,
      fontSize: 15,
      gap: 10,
      radius: 'var(--radius-md)'
    }
  };
  const s = sizes[size] || sizes.md;
  const variants = {
    primary: {
      background: 'var(--accent)',
      color: 'var(--text-on-accent)',
      border: '1px solid transparent',
      boxShadow: '0 1px 0 rgba(255,255,255,0.18) inset, 0 6px 18px var(--terra-glow)'
    },
    secondary: {
      background: 'var(--surface-raised)',
      color: 'var(--text-strong)',
      border: '1px solid var(--border-strong)',
      boxShadow: 'var(--elev-1)'
    },
    ghost: {
      background: 'transparent',
      color: 'var(--text-body)',
      border: '1px solid transparent',
      boxShadow: 'none'
    },
    danger: {
      background: 'transparent',
      color: 'var(--danger)',
      border: '1px solid var(--red-tint)',
      boxShadow: 'none'
    }
  };
  const v = variants[variant] || variants.primary;
  const [hover, setHover] = React.useState(false);
  const hoverStyle = !disabled && !loading && hover ? {
    primary: {
      background: 'var(--accent-hover)'
    },
    secondary: {
      background: 'var(--surface-overlay)',
      borderColor: 'var(--border-strong)'
    },
    ghost: {
      background: 'var(--surface-raised)',
      color: 'var(--text-strong)'
    },
    danger: {
      background: 'var(--red-tint)'
    }
  }[variant] : {};
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    disabled: disabled || loading,
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: s.gap,
      height: s.height,
      padding: s.padding,
      borderRadius: s.radius,
      fontFamily: mono ? 'var(--font-mono)' : 'var(--font-sans)',
      fontSize: s.fontSize,
      fontWeight: 600,
      letterSpacing: mono ? '0' : '-0.01em',
      width: fullWidth ? '100%' : 'auto',
      cursor: disabled || loading ? 'not-allowed' : 'pointer',
      opacity: disabled ? 0.45 : 1,
      transition: 'background var(--dur-fast) var(--ease-out), transform var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out)',
      transform: !disabled && !loading && hover ? 'translateY(-1px)' : 'translateY(0)',
      whiteSpace: 'nowrap',
      ...v,
      ...hoverStyle
    }
  }, rest), loading && /*#__PURE__*/React.createElement(Spinner, null), !loading && iconLeft, children, !loading && iconRight);
}
function Spinner() {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      width: 14,
      height: 14,
      borderRadius: '50%',
      border: '2px solid currentColor',
      borderTopColor: 'transparent',
      display: 'inline-block',
      animation: 'ns-spin 0.7s linear infinite'
    }
  }, /*#__PURE__*/React.createElement("style", null, `@keyframes ns-spin{to{transform:rotate(360deg)}}`));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift Card — the base surface container.
 * `glow` lifts it with an accent ring (for featured/hero cards);
 * `interactive` adds hover elevation for clickable cards.
 */
function Card({
  children,
  glow = false,
  interactive = false,
  padding = 24,
  as: Tag = 'div',
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement(Tag, _extends({
    onMouseEnter: interactive ? () => setHover(true) : undefined,
    onMouseLeave: interactive ? () => setHover(false) : undefined,
    style: {
      background: 'var(--surface-card)',
      border: '1px solid',
      borderColor: glow ? 'var(--border-accent)' : hover ? 'var(--border-strong)' : 'var(--border-default)',
      borderRadius: 'var(--radius-lg)',
      padding,
      boxShadow: glow ? '0 0 0 1px var(--terra-glow), var(--elev-3)' : interactive && hover ? 'var(--elev-3)' : 'var(--elev-1)',
      transform: interactive && hover ? 'translateY(-2px)' : 'translateY(0)',
      transition: 'transform var(--dur-base) var(--ease-out), box-shadow var(--dur-base) var(--ease-out), border-color var(--dur-base) var(--ease-out)',
      cursor: interactive ? 'pointer' : 'default',
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/InstallSnippet.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift InstallSnippet — a copy-to-clipboard command line.
 * The signature "install in 60 seconds" affordance. Renders a mono prompt,
 * the command, and a copy button that confirms inline.
 */
function InstallSnippet({
  command = '/plugin install sdlc@nightshift',
  prompt = '$',
  label,
  ...rest
}) {
  const [copied, setCopied] = React.useState(false);
  const [hover, setHover] = React.useState(false);
  function copy() {
    try {
      navigator.clipboard?.writeText(command);
    } catch (e) {/* noop */}
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  }
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8
    }
  }, rest), label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 12,
      letterSpacing: '0.14em',
      textTransform: 'uppercase',
      color: 'var(--text-dim)'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      background: 'var(--surface-terminal)',
      border: '1px solid',
      borderColor: hover ? 'var(--border-accent)' : 'var(--border-strong)',
      borderRadius: 'var(--radius-md)',
      padding: '14px 14px 14px 18px',
      fontFamily: 'var(--font-mono)',
      fontSize: 14,
      transition: 'border-color var(--dur-base) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--code-prompt)',
      userSelect: 'none'
    }
  }, prompt), /*#__PURE__*/React.createElement("code", {
    style: {
      color: 'var(--moon-100)',
      flex: 1,
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, command), /*#__PURE__*/React.createElement("button", {
    onClick: copy,
    "aria-label": "Copy command",
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      background: copied ? 'var(--green-tint)' : 'var(--surface-raised)',
      color: copied ? 'var(--success)' : 'var(--text-muted)',
      border: '1px solid',
      borderColor: copied ? 'rgba(110,196,138,0.4)' : 'var(--border-default)',
      borderRadius: 'var(--radius-sm)',
      padding: '6px 12px',
      fontFamily: 'var(--font-mono)',
      fontSize: 12,
      fontWeight: 500,
      cursor: 'pointer',
      whiteSpace: 'nowrap',
      transition: 'all var(--dur-fast) var(--ease-out)'
    }
  }, copied ? 'copied ✓' : 'copy')));
}
Object.assign(__ds_scope, { InstallSnippet });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/InstallSnippet.jsx", error: String((e && e.message) || e) }); }

// components/data/AgentCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift AgentCard — a role in the AI software team.
 * Shows the agent's name (mono), what it owns, an avatar glyph (monogram),
 * and an optional status. Used in the "meet your team" grid.
 */
function AgentCard({
  name,
  owns,
  glyph,
  tone = 'accent',
  status,
  standby = false,
  ...rest
}) {
  const tones = {
    accent: {
      ring: 'var(--terra-tint)',
      fg: 'var(--terra-400)',
      bd: 'rgba(217,119,87,0.3)'
    },
    info: {
      ring: 'var(--indigo-tint)',
      fg: 'var(--indigo-400)',
      bd: 'rgba(124,147,240,0.3)'
    },
    cyan: {
      ring: 'rgba(79,179,196,0.14)',
      fg: 'var(--cyan-400)',
      bd: 'rgba(79,179,196,0.3)'
    },
    green: {
      ring: 'var(--green-tint)',
      fg: 'var(--green-400)',
      bd: 'rgba(110,196,138,0.3)'
    }
  };
  const t = tones[tone] || tones.accent;
  const monogram = glyph || (name ? name.split('-').map(w => w[0]).join('').slice(0, 2).toUpperCase() : '');
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", _extends({
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      background: 'var(--surface-card)',
      border: '1px solid',
      borderColor: hover ? 'var(--border-strong)' : 'var(--border-default)',
      borderRadius: 'var(--radius-lg)',
      padding: 18,
      opacity: standby ? 0.66 : 1,
      boxShadow: hover ? 'var(--elev-2)' : 'var(--elev-1)',
      transform: hover ? 'translateY(-2px)' : 'translateY(0)',
      transition: 'all var(--dur-base) var(--ease-out)',
      ...rest.style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 38,
      height: 38,
      flex: 'none',
      borderRadius: 'var(--radius-md)',
      background: t.ring,
      border: '1px solid',
      borderColor: t.bd,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: 'var(--font-mono)',
      fontSize: 14,
      fontWeight: 700,
      color: t.fg
    }
  }, monogram), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 14,
      fontWeight: 500,
      color: 'var(--moon-100)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, name), standby && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      letterSpacing: '0.1em',
      textTransform: 'uppercase',
      color: 'var(--text-dim)'
    }
  }, "standby"))), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: 0,
      fontFamily: 'var(--font-sans)',
      fontSize: 13,
      lineHeight: 1.5,
      color: 'var(--text-muted)'
    }
  }, owns), status && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      color: t.fg
    }
  }, status));
}
Object.assign(__ds_scope, { AgentCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/AgentCard.jsx", error: String((e && e.message) || e) }); }

// components/data/CommandCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift CommandCard — a slash-command reference entry for the docs.
 * Shows the command, its argument signature, a one-line description, and
 * the agent(s) it dispatches.
 */
function CommandCard({
  command,
  args,
  description,
  agents = [],
  output,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", _extends({
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      background: 'var(--surface-card)',
      border: '1px solid',
      borderColor: hover ? 'var(--border-accent)' : 'var(--border-default)',
      borderRadius: 'var(--radius-lg)',
      padding: 18,
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      transition: 'border-color var(--dur-base) var(--ease-out)',
      ...rest.style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 8,
      flexWrap: 'wrap'
    }
  }, /*#__PURE__*/React.createElement("code", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 15,
      fontWeight: 700,
      color: 'var(--terra-400)'
    }
  }, command), args && /*#__PURE__*/React.createElement("code", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 13,
      color: 'var(--text-dim)'
    }
  }, args)), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: 0,
      fontFamily: 'var(--font-sans)',
      fontSize: 14,
      lineHeight: 1.55,
      color: 'var(--text-body)'
    }
  }, description), output && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 12,
      color: 'var(--text-muted)',
      background: 'var(--surface-terminal)',
      border: '1px solid var(--border-soft)',
      borderRadius: 'var(--radius-sm)',
      padding: '8px 10px',
      lineHeight: 1.6
    }
  }, output), agents.length > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexWrap: 'wrap',
      gap: 6,
      marginTop: 2
    }
  }, agents.map(a => /*#__PURE__*/React.createElement("span", {
    key: a,
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      color: 'var(--text-muted)',
      border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-pill)',
      padding: '2px 9px'
    }
  }, a))));
}
Object.assign(__ds_scope, { CommandCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/CommandCard.jsx", error: String((e && e.message) || e) }); }

// components/data/Table.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift Table — a quiet data table on the night palette.
 * Pass `columns` and `rows`; cells render strings or React nodes.
 * Hairline rows, mono headers, hover row highlight.
 */
function Table({
  columns = [],
  rows = [],
  dense = false,
  ...rest
}) {
  const pad = dense ? '8px 12px' : '12px 16px';
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      background: 'var(--surface-card)',
      ...rest.style
    }
  }, rest), /*#__PURE__*/React.createElement("table", {
    style: {
      width: '100%',
      borderCollapse: 'collapse',
      fontFamily: 'var(--font-sans)'
    }
  }, /*#__PURE__*/React.createElement("thead", null, /*#__PURE__*/React.createElement("tr", {
    style: {
      background: 'rgba(255,255,255,0.02)'
    }
  }, columns.map(c => /*#__PURE__*/React.createElement("th", {
    key: c.key,
    style: {
      textAlign: c.align || 'left',
      padding: pad,
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      fontWeight: 500,
      letterSpacing: '0.1em',
      textTransform: 'uppercase',
      color: 'var(--text-dim)',
      borderBottom: '1px solid var(--border-default)',
      whiteSpace: 'nowrap'
    }
  }, c.header)))), /*#__PURE__*/React.createElement("tbody", null, rows.map((row, ri) => /*#__PURE__*/React.createElement(Row, {
    key: ri,
    row: row,
    columns: columns,
    pad: pad,
    last: ri === rows.length - 1
  })))));
}
function Row({
  row,
  columns,
  pad,
  last
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("tr", {
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      background: hover ? 'rgba(255,255,255,0.03)' : 'transparent',
      transition: 'background var(--dur-fast) var(--ease-out)'
    }
  }, columns.map(c => /*#__PURE__*/React.createElement("td", {
    key: c.key,
    style: {
      textAlign: c.align || 'left',
      padding: pad,
      fontSize: 14,
      color: c.muted ? 'var(--text-muted)' : 'var(--text-body)',
      fontFamily: c.mono ? 'var(--font-mono)' : 'var(--font-sans)',
      borderBottom: last ? 'none' : '1px solid var(--border-soft)'
    }
  }, row[c.key])));
}
Object.assign(__ds_scope, { Table });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/Table.jsx", error: String((e && e.message) || e) }); }

// components/site/Footer.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift Footer — site footer with brand lockup, column nav,
 * and a quiet night-sky base. Columns passed as structured data.
 */
function Footer({
  logoSrc = '../../assets/logomark.svg',
  tagline = 'Your AI software team that ships while you sleep.',
  columns = [],
  bottomNote = 'MIT © whimzyLive',
  builtOn = 'Built on Claude Code — agents, commands, skills, and hooks all the way down.',
  ...rest
}) {
  return /*#__PURE__*/React.createElement("footer", _extends({
    style: {
      background: 'var(--bg-void)',
      borderTop: '1px solid var(--border-default)',
      padding: '56px 28px 28px',
      ...rest.style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 'var(--container-max)',
      margin: '0 auto',
      display: 'flex',
      flexWrap: 'wrap',
      gap: 48,
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 320
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: logoSrc,
    width: 26,
    height: 26,
    alt: ""
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontWeight: 700,
      fontSize: 16,
      color: 'var(--moon-100)'
    }
  }, "night", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, "shift"))), /*#__PURE__*/React.createElement("p", {
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 14,
      lineHeight: 1.6,
      color: 'var(--text-muted)',
      margin: 0
    }
  }, tagline)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexWrap: 'wrap',
      gap: 56
    }
  }, columns.map(col => /*#__PURE__*/React.createElement("div", {
    key: col.title,
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      letterSpacing: '0.14em',
      textTransform: 'uppercase',
      color: 'var(--text-dim)'
    }
  }, col.title), col.items.map(it => /*#__PURE__*/React.createElement("a", {
    key: it,
    href: "#",
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 14,
      color: 'var(--text-muted)',
      textDecoration: 'none'
    },
    onMouseEnter: e => e.currentTarget.style.color = 'var(--text-strong)',
    onMouseLeave: e => e.currentTarget.style.color = 'var(--text-muted)'
  }, it)))))), /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 'var(--container-max)',
      margin: '40px auto 0',
      paddingTop: 22,
      borderTop: '1px solid var(--border-soft)',
      display: 'flex',
      flexWrap: 'wrap',
      gap: 12,
      justifyContent: 'space-between',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 12,
      color: 'var(--text-dim)'
    }
  }, builtOn), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 12,
      color: 'var(--text-dim)'
    }
  }, bottomNote)));
}
Object.assign(__ds_scope, { Footer });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/site/Footer.jsx", error: String((e && e.message) || e) }); }

// components/site/NavBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift NavBar — top navigation with logo lockup, links, GitHub stars,
 * and a primary CTA. Sticky, with a translucent night backdrop blur.
 */
function NavBar({
  logoSrc = '../../assets/logomark.svg',
  brand = 'nightshift',
  links = [],
  stars = '1.2k',
  ctaLabel = 'Install',
  onCta,
  active,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("header", _extends({
    style: {
      position: 'sticky',
      top: 0,
      zIndex: 50,
      height: 'var(--nav-height)',
      display: 'flex',
      alignItems: 'center',
      gap: 28,
      padding: '0 28px',
      background: 'rgba(13,13,24,0.72)',
      borderBottom: '1px solid var(--border-default)',
      backdropFilter: 'blur(14px)',
      WebkitBackdropFilter: 'blur(14px)',
      ...rest.style
    }
  }, rest), /*#__PURE__*/React.createElement("a", {
    href: "#",
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      textDecoration: 'none'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: logoSrc,
    width: 28,
    height: 28,
    alt: ""
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontWeight: 700,
      fontSize: 17,
      letterSpacing: '-0.4px',
      color: 'var(--moon-100)'
    }
  }, "night", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, "shift"))), /*#__PURE__*/React.createElement("nav", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 4,
      flex: 1
    }
  }, links.map(l => /*#__PURE__*/React.createElement("a", {
    key: l.label,
    href: l.href || '#',
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 14,
      fontWeight: 500,
      color: active === l.label ? 'var(--text-strong)' : 'var(--text-muted)',
      padding: '7px 12px',
      borderRadius: 'var(--radius-sm)',
      textDecoration: 'none',
      transition: 'color var(--dur-fast) var(--ease-out)'
    },
    onMouseEnter: e => e.currentTarget.style.color = 'var(--text-strong)',
    onMouseLeave: e => e.currentTarget.style.color = active === l.label ? 'var(--text-strong)' : 'var(--text-muted)'
  }, l.label))), /*#__PURE__*/React.createElement("a", {
    href: "#",
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 8,
      fontFamily: 'var(--font-mono)',
      fontSize: 13,
      color: 'var(--text-body)',
      border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-sm)',
      padding: '6px 12px',
      textDecoration: 'none'
    }
  }, /*#__PURE__*/React.createElement(GitHubGlyph, null), " ", /*#__PURE__*/React.createElement("span", null, stars)), /*#__PURE__*/React.createElement("button", {
    onClick: onCta,
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      height: 38,
      padding: '0 18px',
      background: 'var(--accent)',
      color: 'var(--text-on-accent)',
      border: 'none',
      borderRadius: 'var(--radius-md)',
      fontFamily: 'var(--font-sans)',
      fontSize: 14,
      fontWeight: 600,
      cursor: 'pointer',
      boxShadow: '0 6px 18px var(--terra-glow)'
    }
  }, ctaLabel));
}
function GitHubGlyph() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 16 16",
    fill: "currentColor",
    "aria-hidden": "true",
    style: {
      color: 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z"
  }));
}
Object.assign(__ds_scope, { NavBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/site/NavBar.jsx", error: String((e && e.message) || e) }); }

// components/terminal/CodeBlock.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift CodeBlock — a syntax-tinted code surface with optional
 * filename header, line numbers, and a copy button. Tokens are passed as
 * structured spans so it stays framework-free (no highlighter dependency).
 */
function CodeBlock({
  code = '',
  language = 'bash',
  filename,
  showLineNumbers = false,
  copyable = true,
  ...rest
}) {
  const [copied, setCopied] = React.useState(false);
  const lines = String(code).replace(/\n$/, '').split('\n');
  function copy() {
    try {
      navigator.clipboard?.writeText(code);
    } catch (e) {/* noop */}
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: 'var(--surface-terminal)',
      border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-md)',
      overflow: 'hidden',
      fontFamily: 'var(--font-mono)',
      ...rest.style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '9px 12px 9px 14px',
      borderBottom: '1px solid var(--border-soft)',
      background: 'rgba(255,255,255,0.02)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--text-body)'
    }
  }, filename || language), filename && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--text-dim)'
    }
  }, language)), copyable && /*#__PURE__*/React.createElement("button", {
    onClick: copy,
    "aria-label": "Copy code",
    style: {
      background: 'transparent',
      border: 'none',
      cursor: 'pointer',
      color: copied ? 'var(--success)' : 'var(--text-dim)',
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      padding: '2px 6px'
    }
  }, copied ? 'copied ✓' : 'copy')), /*#__PURE__*/React.createElement("pre", {
    style: {
      margin: 0,
      padding: '14px 16px',
      overflowX: 'auto',
      fontSize: 13,
      lineHeight: 1.7
    }
  }, /*#__PURE__*/React.createElement("code", null, lines.map((ln, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex'
    }
  }, showLineNumbers && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 28,
      flex: 'none',
      color: 'var(--moon-500)',
      userSelect: 'none',
      textAlign: 'right',
      marginRight: 16
    }
  }, i + 1), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--moon-200)',
      whiteSpace: 'pre'
    }
  }, highlight(ln)))))));
}

/** Lightweight token tinting for shell / conventional-commit style lines. */
function highlight(line) {
  // Comments
  if (line.trimStart().startsWith('#')) {
    return /*#__PURE__*/React.createElement("span", {
      style: {
        color: 'var(--code-comment)'
      }
    }, line);
  }
  const parts = [];
  let rest = line;
  // leading prompt
  const promptMatch = rest.match(/^(\s*)([$>])\s/);
  if (promptMatch) {
    parts.push(/*#__PURE__*/React.createElement("span", {
      key: "ind"
    }, promptMatch[1]));
    parts.push(/*#__PURE__*/React.createElement("span", {
      key: "p",
      style: {
        color: 'var(--code-prompt)'
      }
    }, promptMatch[2], " "));
    rest = rest.slice(promptMatch[0].length);
  }
  // conventional-commit prefix
  const ccMatch = rest.match(/^(feat|fix|docs|chore|refactor|test|perf|build|ci|style)(\([^)]+\))?(!)?:/);
  if (ccMatch) {
    parts.push(/*#__PURE__*/React.createElement("span", {
      key: "cc",
      style: {
        color: 'var(--code-fn)'
      }
    }, ccMatch[1]));
    if (ccMatch[2]) parts.push(/*#__PURE__*/React.createElement("span", {
      key: "scope",
      style: {
        color: 'var(--code-num)'
      }
    }, ccMatch[2]));
    if (ccMatch[3]) parts.push(/*#__PURE__*/React.createElement("span", {
      key: "bang",
      style: {
        color: 'var(--danger)'
      }
    }, "!"));
    parts.push(/*#__PURE__*/React.createElement("span", {
      key: "colon",
      style: {
        color: 'var(--code-punct)'
      }
    }, ":"));
    rest = rest.slice(ccMatch[0].length);
  }
  parts.push(/*#__PURE__*/React.createElement("span", {
    key: "rest"
  }, rest));
  return parts;
}
Object.assign(__ds_scope, { CodeBlock });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/terminal/CodeBlock.jsx", error: String((e && e.message) || e) }); }

// components/terminal/Pipeline.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift Pipeline — the spec→plan→impl→review→PR flow as connected blocks.
 * Each stage shows a command/label and an optional agent + status.
 * Renders horizontally on wide layouts, stacking with vertical connectors when narrow.
 */
function Pipeline({
  stages = [],
  orientation = 'horizontal',
  ...rest
}) {
  const horizontal = orientation === 'horizontal';
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: 'flex',
      flexDirection: horizontal ? 'row' : 'column',
      alignItems: horizontal ? 'stretch' : 'stretch',
      gap: 0,
      ...rest.style
    }
  }, rest), stages.map((st, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: i
  }, /*#__PURE__*/React.createElement(Stage, _extends({}, st, {
    horizontal: horizontal
  })), i < stages.length - 1 && /*#__PURE__*/React.createElement(Connector, {
    horizontal: horizontal,
    done: st.status === 'done'
  }))));
}
function Stage({
  command,
  label,
  agent,
  status = 'idle',
  horizontal
}) {
  const states = {
    idle: {
      bd: 'var(--border-default)',
      cmd: 'var(--text-muted)',
      glow: 'none'
    },
    active: {
      bd: 'var(--border-accent)',
      cmd: 'var(--terra-400)',
      glow: 'var(--glow-accent)'
    },
    done: {
      bd: 'rgba(110,196,138,0.35)',
      cmd: 'var(--success)',
      glow: 'none'
    }
  };
  const s = states[status] || states.idle;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: horizontal ? 0 : undefined,
      background: 'var(--surface-card)',
      border: '1px solid',
      borderColor: s.bd,
      borderRadius: 'var(--radius-md)',
      padding: '14px 16px',
      boxShadow: s.glow,
      display: 'flex',
      flexDirection: 'column',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 13,
      fontWeight: 500,
      color: s.cmd
    }
  }, status === 'done' ? '✓ ' : '', command), label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-sans)',
      fontSize: 13,
      color: 'var(--text-strong)'
    }
  }, label), agent && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 11,
      color: 'var(--text-dim)'
    }
  }, agent));
}
function Connector({
  horizontal,
  done
}) {
  const color = done ? 'var(--success)' : 'var(--moon-500)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: horizontal ? '0 6px' : '4px 0',
      color,
      fontFamily: 'var(--font-mono)',
      fontSize: 14,
      flex: 'none'
    }
  }, horizontal ? '→' : '↓');
}
Object.assign(__ds_scope, { Pipeline });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/terminal/Pipeline.jsx", error: String((e && e.message) || e) }); }

// components/terminal/Terminal.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * nightshift Terminal — a window frame with traffic lights + title bar,
 * and a dark body for terminal output. Pass `lines` for structured output
 * or arbitrary children. The signature surface of the brand.
 */
function Terminal({
  title = 'zsh — nightshift',
  lines = null,
  children,
  showDot = true,
  minHeight,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: 'var(--surface-terminal)',
      border: '1px solid var(--border-strong)',
      borderRadius: 'var(--radius-lg)',
      overflow: 'hidden',
      boxShadow: 'var(--elev-3)',
      fontFamily: 'var(--font-mono)',
      ...rest.style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '11px 14px',
      background: 'linear-gradient(180deg, rgba(255,255,255,0.04), transparent)',
      borderBottom: '1px solid var(--border-default)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      gap: 7
    }
  }, /*#__PURE__*/React.createElement(Dot, {
    c: "#ff5f57"
  }), /*#__PURE__*/React.createElement(Dot, {
    c: "#febc2e"
  }), /*#__PURE__*/React.createElement(Dot, {
    c: "#28c840"
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      textAlign: 'center',
      fontSize: 12,
      color: 'var(--text-dim)',
      letterSpacing: '0.02em',
      marginRight: 46,
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, title)), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 18px',
      fontSize: 13,
      lineHeight: 1.75,
      minHeight,
      color: 'var(--moon-200)'
    }
  }, lines ? lines.map((ln, i) => /*#__PURE__*/React.createElement(TermLine, _extends({
    key: i
  }, normalize(ln)))) : children));
}
function Dot({
  c
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 12,
      borderRadius: '50%',
      background: c,
      display: 'inline-block'
    }
  });
}
function normalize(ln) {
  if (typeof ln === 'string') return {
    text: ln
  };
  return ln;
}

/**
 * A single terminal line. `tone` colors the glyph + text;
 * `prompt` renders a leading prompt; `agent` renders an agent name in accent.
 */
function TermLine({
  text,
  tone = 'default',
  prompt,
  agent,
  indent = 0,
  dim = false
}) {
  const tones = {
    default: 'var(--moon-200)',
    success: 'var(--success)',
    warning: 'var(--warning)',
    danger: 'var(--danger)',
    info: 'var(--info)',
    muted: 'var(--text-dim)',
    accent: 'var(--terra-400)'
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      paddingLeft: indent * 18,
      color: dim ? 'var(--text-dim)' : tones[tone],
      whiteSpace: 'pre-wrap'
    }
  }, prompt && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--code-prompt)',
      marginRight: 8
    }
  }, prompt), agent && /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--terra-400)'
    }
  }, agent), agent && text ? ' ' : '', text);
}
Object.assign(__ds_scope, { Terminal, TermLine });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/terminal/Terminal.jsx", error: String((e && e.message) || e) }); }

// ui_kits/docs/layout.jsx
try { (() => {
/* nightshift docs home — layout components.
 * Sidebar nav, content prose, command reference grid.
 */
const NSd = window.NightshiftDesignSystem_983007;
const {
  CommandCard,
  CodeBlock,
  Badge,
  Table,
  InstallSnippet,
  Button
} = NSd;
const C = v => `var(--${v})`;
const NAV = [{
  group: 'Getting started',
  items: ['Overview', 'Install', 'Quickstart', 'Project context']
}, {
  group: 'Commands',
  items: ['/auto', '/spec', '/plan', '/impl', '/review']
}, {
  group: 'The team',
  items: ['Agents overview', 'Handoff protocol', 'Standby roles']
}, {
  group: 'Extend',
  items: ['Add a skill', 'Bind to a role', 'Adapters']
}];
function Sidebar({
  active = 'Overview'
}) {
  return /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 248,
      flex: 'none',
      borderRight: `1px solid ${C('border-default')}`,
      padding: '28px 18px',
      position: 'sticky',
      top: 'var(--nav-height)',
      height: 'calc(100vh - var(--nav-height))',
      overflowY: 'auto',
      boxSizing: 'border-box',
      background: C('bg-page')
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      marginBottom: 20
    }
  }, /*#__PURE__*/React.createElement("input", {
    placeholder: "Search docs\u2026",
    readOnly: true,
    style: {
      width: '100%',
      boxSizing: 'border-box',
      background: C('surface-terminal'),
      border: `1px solid ${C('border-default')}`,
      borderRadius: 'var(--radius-md)',
      padding: '8px 12px 8px 32px',
      color: C('text-muted'),
      fontFamily: C('font-mono'),
      fontSize: 12
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 11,
      top: 8,
      color: C('text-dim'),
      fontSize: 13
    }
  }, "\u2315"), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      right: 10,
      top: 7,
      fontFamily: C('font-mono'),
      fontSize: 10,
      color: C('text-dim'),
      border: `1px solid ${C('border-default')}`,
      borderRadius: 4,
      padding: '1px 5px'
    }
  }, "\u2318K")), NAV.map(sec => /*#__PURE__*/React.createElement("div", {
    key: sec.group,
    style: {
      marginBottom: 22
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: C('font-mono'),
      fontSize: 11,
      letterSpacing: '0.12em',
      textTransform: 'uppercase',
      color: C('text-dim'),
      marginBottom: 8,
      paddingLeft: 10
    }
  }, sec.group), sec.items.map(it => {
    const on = it === active;
    const mono = it.startsWith('/');
    return /*#__PURE__*/React.createElement("a", {
      key: it,
      href: "#",
      style: {
        display: 'block',
        padding: '6px 10px',
        borderRadius: 'var(--radius-sm)',
        fontFamily: mono ? C('font-mono') : C('font-sans'),
        fontSize: 13.5,
        color: on ? C('terra-400') : C('text-muted'),
        background: on ? C('terra-tint') : 'transparent',
        textDecoration: 'none',
        marginBottom: 1,
        borderLeft: on ? `2px solid ${C('accent')}` : '2px solid transparent'
      }
    }, it);
  }))));
}
function Content() {
  return /*#__PURE__*/React.createElement("main", {
    style: {
      flex: 1,
      minWidth: 0,
      padding: '40px 48px 80px',
      maxWidth: 880
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      fontFamily: C('font-mono'),
      fontSize: 12,
      color: C('text-dim'),
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement("span", null, "Docs"), /*#__PURE__*/React.createElement("span", null, "/"), /*#__PURE__*/React.createElement("span", null, "Getting started"), /*#__PURE__*/React.createElement("span", null, "/"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: C('text-muted')
    }
  }, "Overview")), /*#__PURE__*/React.createElement("span", {
    className: "ns-eyebrow"
  }, "// sdlc plugin"), /*#__PURE__*/React.createElement("h1", {
    style: {
      fontSize: 40,
      letterSpacing: '-0.025em',
      color: C('moon-100'),
      margin: '12px 0 16px'
    }
  }, "Overview"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 17,
      lineHeight: 1.65,
      color: C('text-body'),
      margin: '0 0 14px'
    }
  }, "nightshift installs a repo-agnostic software-delivery team into Claude Code. Its flagship plugin,", /*#__PURE__*/React.createElement("code", {
    style: {
      fontFamily: C('font-mono'),
      color: C('terra-400'),
      background: C('terra-tint'),
      padding: '1px 6px',
      borderRadius: 4,
      margin: '0 4px'
    }
  }, "sdlc"), ", gives you 11 specialized agents and 10 slash commands \u2014 the whole lifecycle, one verb at a time."), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 15,
      lineHeight: 1.65,
      color: C('text-muted'),
      margin: '0 0 28px'
    }
  }, "It is ", /*#__PURE__*/React.createElement("strong", {
    style: {
      color: C('moon-100')
    }
  }, "not"), " a wrapper that writes code for you. It's a process engine that makes a senior team's discipline the default \u2014 spec before plan, plan before code, review before merge, tests as the gate."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      marginBottom: 36
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: "success",
    dot: true
  }, "repo-agnostic"), /*#__PURE__*/React.createElement(Badge, {
    tone: "info"
  }, "11 agents"), /*#__PURE__*/React.createElement(Badge, {
    tone: "accent"
  }, "10 commands"), /*#__PURE__*/React.createElement(Badge, {
    tone: "neutral"
  }, "MIT")), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 24,
      letterSpacing: '-0.01em',
      color: C('moon-100'),
      margin: '0 0 14px',
      paddingBottom: 10,
      borderBottom: `1px solid ${C('border-soft')}`
    }
  }, "Install in 60 seconds"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 15,
      lineHeight: 1.6,
      color: C('text-muted'),
      margin: '0 0 16px'
    }
  }, "In any Claude Code session:"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      marginBottom: 36
    }
  }, /*#__PURE__*/React.createElement(InstallSnippet, {
    command: "/plugin marketplace add whimzyLive/nightshift-ai",
    prompt: "$"
  }), /*#__PURE__*/React.createElement(InstallSnippet, {
    command: "/plugin install sdlc@nightshift",
    prompt: "$"
  })), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 24,
      letterSpacing: '-0.01em',
      color: C('moon-100'),
      margin: '0 0 18px',
      paddingBottom: 10,
      borderBottom: `1px solid ${C('border-soft')}`
    }
  }, "Command reference"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 12,
      marginBottom: 36
    }
  }, /*#__PURE__*/React.createElement(CommandCard, {
    command: "/auto",
    args: "<TICKET>",
    description: "The whole pipeline, end to end \u2014 ticket in, reviewed PR out.",
    agents: ['product-manager', 'solutions-architect', 'tech-lead', 'principal-engineer', 'qa-engineer']
  }), /*#__PURE__*/React.createElement(CommandCard, {
    command: "/spec",
    description: "Produce the technical design spec for a story. Creates a branch, writes the spec doc, raises a PR.",
    agents: ['solutions-architect'],
    output: "docs/superpowers/specs/PROJ-142.md"
  }), /*#__PURE__*/React.createElement(CommandCard, {
    command: "/plan",
    description: "Break the spec into an ordered, verifiable implementation plan.",
    agents: ['tech-lead']
  }), /*#__PURE__*/React.createElement(CommandCard, {
    command: "/impl",
    description: "Execute the plan with domain agents in dependency order.",
    agents: ['principal-engineer', 'platform-engineer']
  }), /*#__PURE__*/React.createElement(CommandCard, {
    command: "/review",
    args: "",
    description: "Review against the spec, run the quality gate, verify acceptance criteria.",
    agents: ['qa-engineer']
  })), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 24,
      letterSpacing: '-0.01em',
      color: C('moon-100'),
      margin: '0 0 16px',
      paddingBottom: 10,
      borderBottom: `1px solid ${C('border-soft')}`
    }
  }, "Configure your repo"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 15,
      lineHeight: 1.6,
      color: C('text-muted'),
      margin: '0 0 16px'
    }
  }, "Each consuming repo supplies one file \u2014 ", /*#__PURE__*/React.createElement("code", {
    style: {
      fontFamily: C('font-mono'),
      color: C('indigo-400')
    }
  }, ".claude/project/project-context.md"), " \u2014 declaring its constants."), /*#__PURE__*/React.createElement(CodeBlock, {
    filename: ".claude/project/project-context.md",
    language: "markdown",
    code: `# Project Context

| Token            | Value                      |
| ---------------- | -------------------------- |
| Project name     | acme-api                   |
| Jira project key | ACME                       |
| Base branch      | develop                    |
| Package manager  | pnpm                       |
| Typecheck / Test | pnpm typecheck / pnpm test |

## Workspace -> agent
| Path           | Owner             |
| -------------- | ----------------- |
| services/api/  | platform-engineer |
| apps/web/      | web-engineer      |`
  }));
}
function OnThisPage() {
  const items = ['Install in 60 seconds', 'Command reference', 'Configure your repo'];
  return /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 200,
      flex: 'none',
      padding: '40px 20px',
      position: 'sticky',
      top: 'var(--nav-height)',
      height: 'calc(100vh - var(--nav-height))',
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: C('font-mono'),
      fontSize: 11,
      letterSpacing: '0.12em',
      textTransform: 'uppercase',
      color: C('text-dim'),
      marginBottom: 12
    }
  }, "On this page"), items.map((it, i) => /*#__PURE__*/React.createElement("a", {
    key: it,
    href: "#",
    style: {
      display: 'block',
      fontSize: 13,
      color: i === 0 ? C('terra-400') : C('text-muted'),
      textDecoration: 'none',
      padding: '5px 0',
      lineHeight: 1.4
    }
  }, it)));
}
window.DocsLayout = {
  Sidebar,
  Content,
  OnThisPage
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/docs/layout.jsx", error: String((e && e.message) || e) }); }

// ui_kits/marketing/sections.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* nightshift marketing site — section components.
 * Composes design-system primitives from the bundle namespace.
 * Attached to window so index.html can mount them.
 */
const NS = window.NightshiftDesignSystem_983007;
const {
  Terminal,
  AgentCard,
  InstallSnippet,
  NavBar,
  Footer,
  Pipeline,
  Button,
  Badge,
  CommandCard
} = NS;
const COLOR = v => `var(--${v})`;

/* ---------- Animated /auto pipeline terminal ---------- */
const PIPELINE_LINES = [{
  prompt: '$',
  text: '/auto PROJ-142'
}, {
  text: ''
}, {
  text: 'Reading ticket PROJ-142 from Jira…',
  tone: 'muted'
}, {
  agent: 'product-manager',
  text: '→ wrote PRD · 4 acceptance criteria',
  tone: 'accent'
}, {
  agent: 'solutions-architect',
  text: '→ technical spec · 2 new endpoints',
  tone: 'accent'
}, {
  agent: 'tech-lead',
  text: '→ ordered plan · 7 verifiable steps',
  tone: 'accent'
}, {
  agent: 'principal-engineer',
  text: '→ dispatching domain engineers…',
  tone: 'accent'
}, {
  text: 'platform-engineer  ✓ implemented, 142 tests green',
  tone: 'muted',
  indent: 1
}, {
  text: 'web-engineer       ✓ UI wired, a11y pass',
  tone: 'muted',
  indent: 1
}, {
  agent: 'qa-engineer',
  text: '→ quality gate passed · ACs verified',
  tone: 'success'
}, {
  text: '→ opened PR #318 · commented on PROJ-142',
  tone: 'success'
}, {
  prompt: '$',
  text: '▌',
  tone: 'accent'
}];
function AnimatedTerminal() {
  const [count, setCount] = React.useState(0);
  React.useEffect(() => {
    if (count >= PIPELINE_LINES.length) {
      const reset = setTimeout(() => setCount(0), 4200);
      return () => clearTimeout(reset);
    }
    const speed = PIPELINE_LINES[count] && PIPELINE_LINES[count].text === '' ? 120 : 520;
    const t = setTimeout(() => setCount(c => c + 1), speed);
    return () => clearTimeout(t);
  }, [count]);
  return React.createElement(Terminal, {
    title: 'zsh — acme-api · claude code',
    minHeight: 360,
    lines: PIPELINE_LINES.slice(0, count)
  });
}

/* ---------- Hero ---------- */
function Hero() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      position: 'relative',
      overflow: 'hidden',
      padding: '88px 28px 72px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ns-stars"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1,
      maxWidth: 'var(--container-max)',
      margin: '0 auto',
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 56,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 8,
      marginBottom: 22
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: "accent",
    dot: true
  }, "v0.4.0 \xB7 MIT"), /*#__PURE__*/React.createElement(Badge, {
    tone: "neutral"
  }, "a Claude Code plugin")), /*#__PURE__*/React.createElement("h1", {
    style: {
      fontSize: 'clamp(40px, 5.2vw, 60px)',
      lineHeight: 1.04,
      letterSpacing: '-0.025em',
      fontWeight: 800,
      color: COLOR('moon-100'),
      margin: '0 0 20px'
    }
  }, "Your AI software team", /*#__PURE__*/React.createElement("br", null), "that ships ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('accent')
    }
  }, "while you sleep.")), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 18,
      lineHeight: 1.6,
      color: COLOR('text-muted'),
      maxWidth: 480,
      margin: '0 0 16px'
    }
  }, "A Claude Code plugin that turns one terminal into a full software-delivery team \u2014 PM, architect, tech lead, engineers, QA \u2014 driven straight from your issue tracker."), /*#__PURE__*/React.createElement("p", {
    style: {
      fontFamily: COLOR('font-mono'),
      fontSize: 14,
      color: COLOR('text-dim'),
      margin: '0 0 28px'
    }
  }, "Jira ticket ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('indigo-400')
    }
  }, "\u2192"), " spec", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('indigo-400')
    }
  }, " \u2192"), " plan", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('indigo-400')
    }
  }, " \u2192"), " code", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('indigo-400')
    }
  }, " \u2192"), " review", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('indigo-400')
    }
  }, " \u2192"), " PR."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      marginBottom: 26
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "lg"
  }, "Install in 60 seconds"), /*#__PURE__*/React.createElement(Button, {
    variant: "secondary",
    size: "lg"
  }, "Watch the demo")), /*#__PURE__*/React.createElement(InstallSnippet, {
    command: "/plugin install sdlc@nightshift",
    prompt: "$"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ns-moon-glow"
  }), /*#__PURE__*/React.createElement(AnimatedTerminal, null))));
}

/* ---------- Problem ---------- */
function Problem() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      padding: '72px 28px',
      borderTop: `1px solid ${COLOR('border-soft')}`
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 860,
      margin: '0 auto',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ns-eyebrow"
  }, "// The problem"), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 'clamp(28px, 3.6vw, 40px)',
      lineHeight: 1.12,
      letterSpacing: '-0.02em',
      color: COLOR('moon-100'),
      margin: '18px 0 18px'
    }
  }, "You don't lose time ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('text-dim'),
      textDecoration: 'line-through',
      textDecorationColor: COLOR('moon-500')
    }
  }, "writing code"), ". You lose it in the ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: COLOR('accent')
    }
  }, "connective tissue"), " around it."), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 17,
      lineHeight: 1.65,
      color: COLOR('text-muted'),
      maxWidth: 660,
      margin: '0 auto'
    }
  }, "Turning a vague ticket into a real spec. Breaking that spec into a plan. Keeping the plan honest while you implement. Then reviewing it without rubber-stamping your own work. AI assistants are great at the middle 20%. nightshift automates the other 80% \u2014 the ", /*#__PURE__*/React.createElement("strong", {
    style: {
      color: COLOR('moon-100')
    }
  }, "process"), ".")));
}

/* ---------- How it works ---------- */
const IDEAS = [{
  n: '01',
  title: 'A team, not a megaprompt',
  body: 'Each role is a separate agent with its own system prompt, tools, and memory. Narrow charters mean fewer hallucinations and cleaner handoffs — the same reason real teams specialize.'
}, {
  n: '02',
  title: 'Generic agents, per-repo config',
  body: 'The agents carry zero project specifics. Stack, owned paths, Jira key, base branch, quality gates — all live in one project-context.md the plugin auto-loads every session.'
}, {
  n: '03',
  title: 'The lifecycle is the product',
  body: "Spec → plan → implement → review isn't a suggestion; it's enforced by the commands and the handoff protocol. Tests are the merge gate. Reviews are done by a different agent than the one who wrote the code."
}];
function HowItWorks() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      padding: '72px 28px',
      background: COLOR('bg-void'),
      borderTop: `1px solid ${COLOR('border-default')}`
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 'var(--container-max)',
      margin: '0 auto'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      marginBottom: 44
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ns-eyebrow"
  }, "// How it works"), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 'clamp(28px, 3.6vw, 40px)',
      letterSpacing: '-0.02em',
      color: COLOR('moon-100'),
      margin: '14px 0 0'
    }
  }, "Three ideas do all the heavy lifting")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3, 1fr)',
      gap: 18,
      marginBottom: 40
    }
  }, IDEAS.map(it => /*#__PURE__*/React.createElement("div", {
    key: it.n,
    style: {
      background: COLOR('surface-card'),
      border: `1px solid ${COLOR('border-default')}`,
      borderRadius: 'var(--radius-lg)',
      padding: 26
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: COLOR('font-mono'),
      fontSize: 13,
      fontWeight: 700,
      color: COLOR('accent')
    }
  }, it.n), /*#__PURE__*/React.createElement("h3", {
    style: {
      fontSize: 19,
      color: COLOR('moon-100'),
      margin: '14px 0 10px'
    }
  }, it.title), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 14,
      lineHeight: 1.6,
      color: COLOR('text-muted'),
      margin: 0
    }
  }, it.body)))), /*#__PURE__*/React.createElement(Pipeline, {
    stages: [{
      command: '/spec',
      label: 'Technical spec',
      agent: 'solutions-architect',
      status: 'done'
    }, {
      command: '/plan',
      label: 'Ordered plan',
      agent: 'tech-lead',
      status: 'done'
    }, {
      command: '/impl',
      label: 'Implementation',
      agent: 'principal-engineer',
      status: 'active'
    }, {
      command: '/review',
      label: 'Quality gate',
      agent: 'qa-engineer',
      status: 'idle'
    }, {
      command: 'PR',
      label: 'Ship it',
      agent: 'auto',
      status: 'idle'
    }]
  })));
}

/* ---------- Meet your team (11 agents) ---------- */
const TEAM = [{
  name: 'product-manager',
  owns: 'Vague idea → PRD with binary acceptance criteria',
  tone: 'accent'
}, {
  name: 'solutions-architect',
  owns: 'PRD → technical design / spec',
  tone: 'accent'
}, {
  name: 'scrum-master',
  owns: 'Story slicing, mapping, splitting',
  tone: 'info'
}, {
  name: 'tech-lead',
  owns: 'Spec → ordered, verifiable implementation plan',
  tone: 'info'
}, {
  name: 'principal-engineer',
  owns: 'Orchestrates the build, dispatches domain agents in dependency order',
  tone: 'accent'
}, {
  name: 'platform-engineer',
  owns: 'Backend / infrastructure / serverless',
  tone: 'cyan'
}, {
  name: 'web-engineer',
  owns: 'Web UI',
  tone: 'cyan'
}, {
  name: 'mobile-engineer',
  owns: 'Mobile apps',
  tone: 'cyan',
  standby: true
}, {
  name: 'database-administrator',
  owns: 'Schema, migrations, data',
  tone: 'cyan'
}, {
  name: 'sync-engineer',
  owns: 'Offline / sync layer',
  tone: 'cyan',
  standby: true
}, {
  name: 'qa-engineer',
  owns: 'Always-on review → quality gate → AC verification → PR',
  tone: 'green'
}];
function Team() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      padding: '72px 28px',
      borderTop: `1px solid ${COLOR('border-default')}`
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 'var(--container-max)',
      margin: '0 auto'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      marginBottom: 44
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ns-eyebrow"
  }, "// Meet your team"), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 'clamp(28px, 3.6vw, 40px)',
      letterSpacing: '-0.02em',
      color: COLOR('moon-100'),
      margin: '14px 0 12px'
    }
  }, "Eleven specialists, one terminal"), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 15,
      color: COLOR('text-muted'),
      margin: 0
    }
  }, "Standby roles activate only when your project-context.md says your project has them.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fill, minmax(248px, 1fr))',
      gap: 14
    }
  }, TEAM.map(a => /*#__PURE__*/React.createElement(AgentCard, _extends({
    key: a.name
  }, a))))));
}

/* ---------- Install ---------- */
function Install() {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      padding: '80px 28px',
      background: COLOR('bg-void'),
      borderTop: `1px solid ${COLOR('border-default')}`,
      position: 'relative',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ns-moon-glow",
    style: {
      top: '-120px',
      right: '-80px',
      left: 'auto'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1,
      maxWidth: 720,
      margin: '0 auto',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "ns-eyebrow"
  }, "// Install in 60 seconds"), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 'clamp(28px, 3.6vw, 40px)',
      letterSpacing: '-0.02em',
      color: COLOR('moon-100'),
      margin: '14px 0 28px'
    }
  }, "Two lines in any Claude Code session"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 12,
      textAlign: 'left'
    }
  }, /*#__PURE__*/React.createElement(InstallSnippet, {
    command: "/plugin marketplace add whimzyLive/nightshift-ai",
    prompt: "$"
  }), /*#__PURE__*/React.createElement(InstallSnippet, {
    command: "/plugin install sdlc@nightshift",
    prompt: "$"
  })), /*#__PURE__*/React.createElement("p", {
    style: {
      fontSize: 14,
      color: COLOR('text-dim'),
      marginTop: 22
    }
  }, "That's it. The shared workflow skills it depends on install automatically.")));
}
window.MarketingSections = {
  Hero,
  Problem,
  HowItWorks,
  Team,
  Install,
  NavBar,
  Footer
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/marketing/sections.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.InstallSnippet = __ds_scope.InstallSnippet;

__ds_ns.AgentCard = __ds_scope.AgentCard;

__ds_ns.CommandCard = __ds_scope.CommandCard;

__ds_ns.Table = __ds_scope.Table;

__ds_ns.Footer = __ds_scope.Footer;

__ds_ns.NavBar = __ds_scope.NavBar;

__ds_ns.CodeBlock = __ds_scope.CodeBlock;

__ds_ns.Pipeline = __ds_scope.Pipeline;

__ds_ns.Terminal = __ds_scope.Terminal;

__ds_ns.TermLine = __ds_scope.TermLine;

})();
