'use client';

import { useEffect, useRef } from 'react';

import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

import { SkyBackdrop } from './sky-backdrop';
import styles from './hero.module.css';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

export interface HeroClientProps {
  headline: string;
  subhead: string;
  ctaLabel: string;
  ctaHref: string;
}

export function HeroClient({
  headline,
  subhead,
  ctaLabel,
  ctaHref,
}: HeroClientProps) {
  const sectionRef = useRef<HTMLElement>(null);
  const sceneRef = useRef<HTMLDivElement>(null);
  const starsFarRef = useRef<HTMLDivElement>(null);
  const starsNearRef = useRef<HTMLDivElement>(null);
  const moonRef = useRef<HTMLDivElement>(null);
  const sunRef = useRef<HTMLDivElement>(null);
  const eyebrowRef = useRef<HTMLParagraphElement>(null);
  const headlineRef = useRef<HTMLHeadingElement>(null);
  const subheadRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLAnchorElement>(null);

  useEffect(() => {
    const section = sectionRef.current;
    const scene = sceneRef.current;
    if (!section || !scene) return;

    const textTargets = [
      eyebrowRef.current,
      headlineRef.current,
      subheadRef.current,
      ctaRef.current,
    ].filter((el): el is NonNullable<typeof el> => el != null);

    const mm = gsap.matchMedia();

    // GSAP only invokes the matchMedia handler when at least one named
    // condition matches (see gsap-core MatchMedia.add). `reduceMotion`
    // alone matches nothing for a default user with no explicit preference,
    // so `allowMotion` is registered as its complement to guarantee the
    // handler always runs.
    mm.add(
      {
        reduceMotion: '(prefers-reduced-motion: reduce)',
        allowMotion: '(prefers-reduced-motion: no-preference)',
      },
      (context) => {
        const { reduceMotion } = context.conditions as {
          reduceMotion: boolean;
          allowMotion: boolean;
        };

        if (reduceMotion) {
          // Simplify: show the final state immediately, no backdrop motion,
          // no mouse parallax, no scroll-linked animation.
          gsap.set(textTargets, { autoAlpha: 1, y: 0 });
          gsap.set(scene, { autoAlpha: 1, rotationX: 0, rotationY: 0 });
          return;
        }

        // Entrance: sky layers reveal back-to-front, then text staggers up.
        const tl = gsap.timeline({ defaults: { ease: 'power3.out' } });
        tl.from(
          [starsFarRef.current, starsNearRef.current],
          { autoAlpha: 0, duration: 1 },
          0,
        )
          .from(moonRef.current, { autoAlpha: 0, x: -30, duration: 0.8 }, 0.15)
          .from(
            sunRef.current,
            { autoAlpha: 0, x: 30, scale: 0.85, duration: 0.8 },
            0.25,
          )
          .from(
            textTargets,
            { autoAlpha: 0, y: 24, duration: 0.6, stagger: 0.12 },
            '-=0.5',
          );

        // Mouse-reactive parallax tilt on the 3D scene only — text stays put.
        const quickRotationX = gsap.quickTo(scene, 'rotationX', {
          duration: 0.6,
          ease: 'power3.out',
        });
        const quickRotationY = gsap.quickTo(scene, 'rotationY', {
          duration: 0.6,
          ease: 'power3.out',
        });

        const handlePointerMove = (event: PointerEvent) => {
          const bounds = section.getBoundingClientRect();
          const relX = (event.clientX - bounds.left) / bounds.width - 0.5;
          const relY = (event.clientY - bounds.top) / bounds.height - 0.5;
          quickRotationY(relX * 10);
          quickRotationX(relY * -8);
        };

        section.addEventListener('pointermove', handlePointerMove);

        // Scroll past the hero: fade + lift the sky backdrop only —
        // transform/opacity, nothing layout-affecting.
        const scrollTween = gsap.to(scene, {
          autoAlpha: 0,
          y: -80,
          ease: 'none',
          scrollTrigger: {
            trigger: section,
            start: 'top top',
            end: 'bottom top',
            scrub: true,
          },
        });

        return () => {
          section.removeEventListener('pointermove', handlePointerMove);
          scrollTween.scrollTrigger?.kill();
          scrollTween.kill();
          tl.kill();
        };
      },
    );

    return () => {
      mm.revert();
    };
  }, []);

  return (
    <section ref={sectionRef} className={styles.hero}>
      <div className={styles.stage} aria-hidden="true">
        <div ref={sceneRef} className={styles.scene}>
          <SkyBackdrop
            starsFarRef={starsFarRef}
            starsNearRef={starsNearRef}
            moonRef={moonRef}
            sunRef={sunRef}
          />
        </div>
      </div>
      <div className={styles.content}>
        <p ref={eyebrowRef} className={styles.eyebrow}>
          // nightshift
        </p>
        <h1 ref={headlineRef} className={styles.headline}>
          {headline}
        </h1>
        <p ref={subheadRef} className={styles.subhead}>
          {subhead}
        </p>
        <a ref={ctaRef} href={ctaHref} className={styles.cta}>
          {ctaLabel}
        </a>
      </div>
    </section>
  );
}

export default HeroClient;
