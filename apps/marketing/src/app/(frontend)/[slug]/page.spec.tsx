import { render, screen } from '@testing-library/react';

import CmsPage, { dynamicParams, generateStaticParams } from './page';
import { getPageBySlug, getPublishedPageSlugs } from '../../../lib/pages';

jest.mock('../../../lib/pages', () => ({
  getPageBySlug: jest.fn(),
  getPublishedPageSlugs: jest.fn(),
}));
jest.mock('../../../components/pages/render-blocks', () => ({
  RenderBlocks: ({ blocks }: { blocks: unknown[] }) => (
    <div data-testid="render-blocks">{blocks.length}</div>
  ),
}));
const notFound = jest.fn(() => {
  throw new Error('NEXT_NOT_FOUND');
});
jest.mock('next/navigation', () => ({ notFound: () => notFound() }));

const mockGetPageBySlug = getPageBySlug as jest.Mock;
const mockGetSlugs = getPublishedPageSlugs as jest.Mock;

beforeEach(() => {
  mockGetPageBySlug.mockReset();
  mockGetSlugs.mockReset();
  notFound.mockClear();
});

it('opts into first-hit rendering for unknown slugs', () => {
  expect(dynamicParams).toBe(true);
});

it('generateStaticParams returns the published slug matrix', async () => {
  mockGetSlugs.mockResolvedValue([{ slug: 'a' }, { slug: 'b' }]);
  expect(await generateStaticParams()).toEqual([{ slug: 'a' }, { slug: 'b' }]);
});

it('awaits params and renders the page blocks', async () => {
  mockGetPageBySlug.mockResolvedValue({ title: 'About', content: [{}, {}] });
  const ui = await CmsPage({ params: Promise.resolve({ slug: 'about' }) });
  render(ui);
  expect(mockGetPageBySlug).toHaveBeenCalledWith('about');
  expect(screen.getByTestId('render-blocks').textContent).toBe('2');
});

it('calls notFound() when no published page matches', async () => {
  mockGetPageBySlug.mockResolvedValue(null);
  await expect(
    CmsPage({ params: Promise.resolve({ slug: 'missing' }) }),
  ).rejects.toThrow('NEXT_NOT_FOUND');
  expect(notFound).toHaveBeenCalled();
});
