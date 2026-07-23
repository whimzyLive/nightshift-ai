import { notFound } from 'next/navigation';

import { RenderBlocks } from '../../../components/pages/render-blocks';
import { getPageBySlug, getPublishedPageSlugs } from '../../../lib/pages';

import type { Metadata } from 'next';

export const dynamicParams = true;

export async function generateStaticParams(): Promise<Array<{ slug: string }>> {
  return getPublishedPageSlugs();
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const page = await getPageBySlug(slug);
  return page ? { title: page.title } : {};
}

export default async function CmsPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const page = await getPageBySlug(slug);
  if (!page) notFound();
  return <RenderBlocks blocks={page.content} />;
}
