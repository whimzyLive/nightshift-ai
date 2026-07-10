import type { RefObject } from 'react';

import styles from './sky-backdrop.module.css';

export interface SkyBackdropProps {
  starsFarRef: RefObject<HTMLDivElement | null>;
  starsNearRef: RefObject<HTMLDivElement | null>;
  moonRef: RefObject<HTMLDivElement | null>;
  sunRef: RefObject<HTMLDivElement | null>;
}

// Purely decorative — the sun/moon/star layers carry no content, so the
// whole backdrop is aria-hidden by the parent Hero. Depth comes from each
// layer sitting at a different translateZ inside a perspective ancestor.
export function SkyBackdrop({
  starsFarRef,
  starsNearRef,
  moonRef,
  sunRef,
}: SkyBackdropProps) {
  return (
    <>
      <div ref={starsFarRef} className={`${styles.layer} ${styles.starsFar}`} />
      <div
        ref={starsNearRef}
        className={`${styles.layer} ${styles.starsNear}`}
      />
      <div ref={moonRef} className={`${styles.layer} ${styles.moon}`} />
      <div ref={sunRef} className={`${styles.layer} ${styles.sun}`} />
    </>
  );
}

export default SkyBackdrop;
