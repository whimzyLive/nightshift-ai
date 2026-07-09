import styles from './feature-card.module.css';

export interface FeatureCardProps {
  icon: string;
  title: string;
  description: string;
  href?: string;
}

export function FeatureCard({ icon, title, description, href }: FeatureCardProps) {
  const content = (
    <div className={styles.card}>
      <span className={styles.icon}>{icon}</span>
      <h3 className={styles.title}>{title}</h3>
      <p className={styles.description}>{description}</p>
    </div>
  );

  if (href) {
    return (
      <a href={href} target="_blank" rel="noreferrer" className={styles.link}>
        {content}
      </a>
    );
  }
  return content;
}

export default FeatureCard;
