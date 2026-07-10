import { getHomeContent } from './content';
import { getPayloadClient } from './payload';
import { HOME_SLUG } from '../globals/slugs';

// Explicit factory (not bare `jest.mock('./payload')`): automocking without one
// still requires the real module to inspect its shape, which pulls in the ESM-only
// `payload` package and fails with "Cannot use import statement outside a module"
// under this workspace's babel-jest transform (node_modules untransformed).
jest.mock('./payload', () => ({ getPayloadClient: jest.fn() }));

it('reads the home global by the shared slug constant', async () => {
  const findGlobal = jest.fn().mockResolvedValue({ hero: { headline: 'x' } });
  (getPayloadClient as jest.Mock).mockResolvedValue({ findGlobal });
  await getHomeContent();
  expect(findGlobal).toHaveBeenCalledWith({ slug: HOME_SLUG });
});
