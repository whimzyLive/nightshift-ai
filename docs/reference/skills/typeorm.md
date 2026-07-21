---
title: 'typeorm'
description: 'Use when defining TypeORM entities, writing migrations, or building repository/query-builder code in TypeScript. Covers entity and relation decorators, the Data Mapper pattern, migrations, the query builder, transactions, and multi-database configuration.'
---

# typeorm

Use when defining TypeORM entities, writing migrations, or building repository/query-builder code in TypeScript. Covers entity and relation decorators, the Data Mapper pattern, migrations, the query builder, transactions, and multi-database configuration.

---

**Source:** `skills/typeorm/SKILL.md`

# TypeORM Development Guidelines

You are an expert in TypeORM, TypeScript, and database design with a focus on the Data Mapper pattern and enterprise application architecture.

## Core Principles

- TypeORM supports both Active Record and Data Mapper patterns
- Uses TypeScript decorators for entity and column definitions
- Supports MySQL, PostgreSQL, MariaDB, SQLite, MS SQL Server, Oracle, and more
- Works in Node.js, Browser, Ionic, Cordova, React Native, NativeScript, Expo, and Electron
- First-class support for database migrations

## TypeScript Configuration

Required settings in tsconfig.json:

```json
{
  "compilerOptions": {
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "strict": true,
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node"
  }
}
```

`experimentalDecorators` and `emitDecoratorMetadata` are both mandatory — without
them decorators won't compile and column metadata won't resolve.

## Entity Definition

A representative entity uses a generated primary key, typed `@Column`s, and the
managed timestamp columns:

```typescript
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: 'varchar', length: 255, unique: true })
  email!: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  name!: string | null;

  @Column({ type: 'boolean', default: true })
  isActive!: boolean;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
```

For the full primary-key options (UUID, custom, composite), the complete column
decorator/option set (numeric, enum, JSON, soft-delete, version), and all relation
types (one-to-one, one-to-many/many-to-one, many-to-many), see
[reference.md](reference.md).

## Data Source Configuration

```typescript
// data-source.ts
import { DataSource } from 'typeorm';
import { User } from './entities/User';
import { Post } from './entities/Post';

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,

  // Entity configuration
  entities: [User, Post],
  // Or use glob pattern: entities: ["src/entities/**/*.ts"]

  // Migrations
  migrations: ['src/migrations/**/*.ts'],

  // Synchronize - NEVER use in production
  synchronize: false,

  // Logging
  logging: process.env.NODE_ENV === 'development',

  // Connection pool
  poolSize: 10,

  // SSL (for production)
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
});

// Initialize connection
AppDataSource.initialize()
  .then(() => console.log('Data Source initialized'))
  .catch((error) => console.error('Error initializing Data Source:', error));
```

## Quick Guidance

- **Get a repository** with `AppDataSource.getRepository(Entity)`, then use
  `find`, `findOne`, `create`, `save`, `update`, `delete`, and `softDelete`.
- **Load relations explicitly** with `relations: ['posts']` (or a
  `leftJoinAndSelect` in the query builder) instead of `eager: true`, to avoid
  N+1 query storms.
- **Never use `synchronize: true` in production** — generate and run migrations
  for every schema change.
- **Index** columns you frequently filter or look up via `@Index()`.
- **Always `release()`** a manually created `QueryRunner` in a `finally` block.

Full API detail — repository methods, custom repositories, the query builder,
migrations, transactions, framework integration, and best practices — lives in
the reference.

## Additional resources

- For the full entity/relation/query-builder/migration reference, see [reference.md](reference.md)
- To scaffold a new entity file, run [scripts/new-entity.sh](scripts/new-entity.sh) `<EntityName>`
- To scaffold a new timestamped migration, run [scripts/new-migration.sh](scripts/new-migration.sh) `<MigrationName>`
