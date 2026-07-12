import { render, screen } from '@testing-library/react';

import { ArgumentRail } from './argument-rail';
import { useScrollProgress } from './scroll-progress';

import type { WhySdlcArgument } from '../../lib/why-sdlc';

// `@payloadcms/richtext-lexical/react` ships plain ESM with no CJS build —
// see the identical mock + comment in faq-preview.spec.tsx.
jest.mock('@payloadcms/richtext-lexical/react', () => ({
  RichText: ({
    data,
  }: {
    data: {
      root: { children: Array<{ children?: Array<{ text?: string }> }> };
    };
  }) => {
    const text = data.root.children
      .flatMap((node) => node.children ?? [])
      .map((leaf) => leaf.text ?? '')
      .join('');
    return <p>{text}</p>;
  },
}));

jest.mock('./scroll-progress', () => ({ useScrollProgress: jest.fn() }));

const mockUseScrollProgress = useScrollProgress as jest.Mock;

function richText(text: string): WhySdlcArgument['body'] {
  return {
    root: {
      type: 'root',
      direction: 'ltr',
      format: '',
      indent: 0,
      version: 1,
      children: [
        {
          type: 'paragraph',
          version: 1,
          children: [{ type: 'text', version: 1, text, format: 0 }],
        },
      ],
    },
  } as unknown as WhySdlcArgument['body'];
}

const FIVE_ARGS: WhySdlcArgument[] = [
  {
    eyebrow: '// 01 · the trend',
    heading: 'Abstraction that takes the wheel',
    body: richText('body 1'),
  },
  {
    eyebrow: '// 02 · the answer',
    heading: 'The lifecycle you already trust',
    body: richText('body 2'),
  },
  {
    eyebrow: '// 03 · hard gates',
    heading: 'Hard gates return control',
    body: richText('body 3'),
  },
  {
    eyebrow: '// 04 · no one-shot',
    heading: 'No building it all in one shot',
    body: richText('body 4'),
  },
  {
    eyebrow: '// 05 · builds like you',
    heading: 'It builds the way you would',
    body: richText('body 5'),
  },
];

describe('ArgumentRail', () => {
  beforeEach(() => {
    mockUseScrollProgress
      .mockReset()
      .mockReturnValue({ reached: 0, active: 0 });
  });

  it('renders one card per args row, tagged data-why-sec, with eyebrow/heading/body', () => {
    const { container } = render(<ArgumentRail args={FIVE_ARGS} />);
    FIVE_ARGS.forEach((arg, i) => {
      const sec = container.querySelector(`[data-why-sec="${i}"]`);
      expect(sec).not.toBeNull();
      expect(sec?.textContent).toContain(arg.heading);
    });
    expect(screen.getByText('01 · the trend')).toBeTruthy();
    expect(screen.getByText('body 1')).toBeTruthy();
  });

  it('renders one gate node per present section — does not assume exactly 5', () => {
    const threeArgs = FIVE_ARGS.slice(0, 3);
    const { container } = render(<ArgumentRail args={threeArgs} />);
    expect(container.querySelectorAll('[data-gate-state]')).toHaveLength(3);
  });

  it('shows passed/current/idle gate states from { reached, active }', () => {
    mockUseScrollProgress.mockReturnValue({ reached: 2, active: 1 });
    const { container } = render(<ArgumentRail args={FIVE_ARGS} />);
    const nodes = Array.from(container.querySelectorAll('[data-gate-state]'));
    expect(nodes[0].getAttribute('data-gate-state')).toBe('passed');
    expect(nodes[0].textContent).toBe('✓');
    expect(nodes[1].getAttribute('data-gate-state')).toBe('current');
    expect(nodes[1].textContent).toBe('⊘');
    expect(nodes[2].getAttribute('data-gate-state')).toBe('idle');
    expect(nodes[2].textContent).toBe('⊘');
    expect(nodes[3].getAttribute('data-gate-state')).toBe('idle');
    expect(nodes[4].getAttribute('data-gate-state')).toBe('idle');
  });

  it('shows the active illustration and the n/5 · caption footer for active', () => {
    mockUseScrollProgress.mockReturnValue({ reached: 3, active: 2 });
    render(<ArgumentRail args={FIVE_ARGS} />);
    expect(
      screen.getByText('3/5 · five gates — control returns at each'),
    ).toBeTruthy();
  });
});
