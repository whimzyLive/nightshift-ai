import { notFound } from 'next/navigation';

import { RenderBlocks } from '../../../components/pages/render-blocks';
import { getPageBySlug, getPublishedPageSlugs } from '../../../lib/pages';

import type { Metadata } from 'next';

// A brand-new CMS page (not in the build-time matrix) compiles + serves
// statically on its first visitor hit instead of 404ing.
export const dynamicParams = true;

// NOTE: deliberately NO `dynamic = 'force-dynamic'` and NO cookies()/headers()/
// searchParams reads anywhere in this route — any of those opts the route out
// of the static cache and defeats ISR (spec: static-path isolation guarantee).

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
