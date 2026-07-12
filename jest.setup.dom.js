// jsdom polyfills for Motion (motion.dev) + GSAP driven components.
// jsdom ships none of these; without them any component that calls
// matchMedia (reduced-motion), uses Motion `whileInView`
// (IntersectionObserver), or measures layout (ResizeObserver) throws on
// render. matchMedia reports `matches: false` for every query, so
// `prefers-reduced-motion: no-preference` is false in tests and GSAP/Motion
// setup guarded behind it stays inert — components render statically.
if (typeof window !== 'undefined') {
  if (typeof window.matchMedia !== 'function') {
    window.matchMedia = (query) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener() {},
      removeListener() {},
      addEventListener() {},
      removeEventListener() {},
      dispatchEvent() {
        return false;
      },
    });
  }

  if (typeof window.IntersectionObserver !== 'function') {
    class IntersectionObserverMock {
      observe() {}
      unobserve() {}
      disconnect() {}
      takeRecords() {
        return [];
      }
    }
    window.IntersectionObserver = IntersectionObserverMock;
    global.IntersectionObserver = IntersectionObserverMock;
  }

  if (typeof window.ResizeObserver !== 'function') {
    class ResizeObserverMock {
      observe() {}
      unobserve() {}
      disconnect() {}
    }
    window.ResizeObserver = ResizeObserverMock;
    global.ResizeObserver = ResizeObserverMock;
  }

  if (typeof window.scrollTo !== 'function') {
    window.scrollTo = () => {};
  }
}
