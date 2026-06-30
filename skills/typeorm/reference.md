# TypeORM Reference

Detailed reference material for TypeORM: the full entity/column option set, all
relation types, the repository and query-builder API, migrations, transactions,
framework integration, best practices, and a common-mistakes table.

## Entity Definition

### Primary Key Options

```typescript
// Auto-increment
@PrimaryGeneratedColumn()
id: number;

// UUID
@PrimaryGeneratedColumn("uuid")
id: string;

// Custom primary key
@PrimaryColumn()
id: string;

// Composite primary key
@Entity()
export class OrderItem {
  @PrimaryColumn()
  orderId: number;

  @PrimaryColumn()
  productId: number;
}
```

### Column Decorators

```typescript
@Entity()
export class Product {
  @PrimaryGeneratedColumn()
  id: number;

  // String columns
  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  // Numeric columns
  @Column({ type: 'decimal', precision: 10, scale: 2 })
  price: number;

  @Column({ type: 'int', default: 0 })
  stock: number;

  // Boolean
  @Column({ type: 'boolean', default: true })
  isAvailable: boolean;

  // JSON
  @Column({ type: 'jsonb', nullable: true })
  metadata: Record<string, any> | null;

  // Enum
  @Column({
    type: 'enum',
    enum: ['active', 'inactive', 'pending'],
    default: 'pending',
  })
  status: 'active' | 'inactive' | 'pending';

  // Timestamps
  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @DeleteDateColumn()
  deletedAt: Date | null; // For soft deletes

  // Version column for optimistic locking
  @VersionColumn()
  version: number;
}
```

## Relationships

### One-to-One

```typescript
@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @OneToOne(() => Profile, (profile) => profile.user, { cascade: true })
  @JoinColumn()
  profile: Profile;
}

@Entity()
export class Profile {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  bio: string;

  @OneToOne(() => User, (user) => user.profile)
  user: User;
}
```

### One-to-Many / Many-to-One

```typescript
@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @OneToMany(() => Post, (post) => post.author)
  posts: Post[];
}

@Entity()
export class Post {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  title: string;

  @ManyToOne(() => User, (user) => user.posts, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;

  @Column()
  authorId: number; // Explicit foreign key column
}
```

### Many-to-Many

```typescript
@Entity()
export class Post {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  title: string;

  @ManyToMany(() => Tag, (tag) => tag.posts)
  @JoinTable({
    name: 'post_tags',
    joinColumn: { name: 'post_id' },
    inverseJoinColumn: { name: 'tag_id' },
  })
  tags: Tag[];
}

@Entity()
export class Tag {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  name: string;

  @ManyToMany(() => Post, (post) => post.tags)
  posts: Post[];
}
```

## Repository Pattern

### Basic Repository Usage

```typescript
import { AppDataSource } from './data-source';
import { User } from './entities/User';

const userRepository = AppDataSource.getRepository(User);

// Find all
const users = await userRepository.find();

// Find with conditions
const activeUsers = await userRepository.find({
  where: { isActive: true },
});

// Find one
const user = await userRepository.findOne({
  where: { id: 1 },
});

// Find or fail
const user = await userRepository.findOneOrFail({
  where: { id: 1 },
});

// Save
const newUser = userRepository.create({
  email: 'user@example.com',
  name: 'John Doe',
});
await userRepository.save(newUser);

// Update
await userRepository.update({ id: 1 }, { name: 'Jane Doe' });

// Delete
await userRepository.delete({ id: 1 });

// Soft delete (requires @DeleteDateColumn)
await userRepository.softDelete({ id: 1 });
```

### Custom Repository

```typescript
import { Repository, DataSource } from 'typeorm';
import { User } from './entities/User';

export class UserRepository extends Repository<User> {
  constructor(private dataSource: DataSource) {
    super(User, dataSource.createEntityManager());
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.findOne({ where: { email } });
  }

  async findActiveUsers(): Promise<User[]> {
    return this.find({
      where: { isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findWithPosts(userId: number): Promise<User | null> {
    return this.findOne({
      where: { id: userId },
      relations: ['posts'],
    });
  }
}
```

### Query Builder

```typescript
const users = await userRepository
  .createQueryBuilder('user')
  .leftJoinAndSelect('user.posts', 'post')
  .where('user.isActive = :isActive', { isActive: true })
  .andWhere('post.publishedAt IS NOT NULL')
  .orderBy('user.createdAt', 'DESC')
  .skip(0)
  .take(10)
  .getMany();

// With raw results
const result = await userRepository
  .createQueryBuilder('user')
  .select('COUNT(*)', 'count')
  .where('user.isActive = :isActive', { isActive: true })
  .getRawOne();

// Insert with query builder
await userRepository
  .createQueryBuilder()
  .insert()
  .into(User)
  .values([
    { email: 'user1@example.com', name: 'User 1' },
    { email: 'user2@example.com', name: 'User 2' },
  ])
  .execute();
```

## Migrations

### Creating Migrations

```bash
# Generate migration from entity changes
npx typeorm migration:generate src/migrations/CreateUsers -d src/data-source.ts

# Create empty migration
npx typeorm migration:create src/migrations/SeedUsers

# Run migrations
npx typeorm migration:run -d src/data-source.ts

# Revert last migration
npx typeorm migration:revert -d src/data-source.ts
```

### Migration File Structure

```typescript
import { MigrationInterface, QueryRunner, Table, TableIndex } from 'typeorm';

export class CreateUsers1234567890 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.createTable(
      new Table({
        name: 'users',
        columns: [
          {
            name: 'id',
            type: 'int',
            isPrimary: true,
            isGenerated: true,
            generationStrategy: 'increment',
          },
          {
            name: 'email',
            type: 'varchar',
            length: '255',
            isUnique: true,
          },
          {
            name: 'name',
            type: 'varchar',
            length: '255',
            isNullable: true,
          },
          {
            name: 'is_active',
            type: 'boolean',
            default: true,
          },
          {
            name: 'created_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
          },
          {
            name: 'updated_at',
            type: 'timestamp',
            default: 'CURRENT_TIMESTAMP',
            onUpdate: 'CURRENT_TIMESTAMP',
          },
        ],
      }),
      true,
    );

    await queryRunner.createIndex(
      'users',
      new TableIndex({
        name: 'IDX_USERS_EMAIL',
        columnNames: ['email'],
      }),
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropIndex('users', 'IDX_USERS_EMAIL');
    await queryRunner.dropTable('users');
  }
}
```

## Transactions

```typescript
// Using QueryRunner
const queryRunner = AppDataSource.createQueryRunner();
await queryRunner.connect();
await queryRunner.startTransaction();

try {
  const user = queryRunner.manager.create(User, {
    email: 'user@example.com',
    name: 'User',
  });
  await queryRunner.manager.save(user);

  const post = queryRunner.manager.create(Post, {
    title: 'First Post',
    author: user,
  });
  await queryRunner.manager.save(post);

  await queryRunner.commitTransaction();
} catch (error) {
  await queryRunner.rollbackTransaction();
  throw error;
} finally {
  await queryRunner.release();
}

// Using transaction method
await AppDataSource.transaction(async (manager) => {
  const user = manager.create(User, {
    email: 'user@example.com',
    name: 'User',
  });
  await manager.save(user);

  const post = manager.create(Post, {
    title: 'First Post',
    author: user,
  });
  await manager.save(post);
});
```

## NestJS Integration

```typescript
// app.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './entities/user.entity';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'user',
      password: 'password',
      database: 'db',
      entities: [User],
      synchronize: false,
    }),
    UsersModule,
  ],
})
export class AppModule {}

// users/users.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [UsersService],
  controllers: [UsersController],
})
export class UsersModule {}

// users/users.service.ts
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  findAll(): Promise<User[]> {
    return this.usersRepository.find();
  }

  findOne(id: number): Promise<User | null> {
    return this.usersRepository.findOneBy({ id });
  }
}
```

## Best Practices

### Use Migrations in Production

Never use `synchronize: true` in production. Always use migrations:

```typescript
// Development: Use migrations, not sync
synchronize: false,
```

### Eager vs Lazy Loading

```typescript
// Eager loading - loads relations automatically
@OneToMany(() => Post, (post) => post.author, { eager: true })
posts: Post[];

// Lazy loading - loads relations on access
@OneToMany(() => Post, (post) => post.author)
posts: Promise<Post[]>;

// Explicit loading (recommended)
const user = await userRepository.findOne({
  where: { id: 1 },
  relations: ["posts"],
});
```

### Avoid N+1 Queries

```typescript
// Bad: N+1 queries
const users = await userRepository.find();
for (const user of users) {
  console.log(user.posts); // Separate query for each user
}

// Good: Eager load relations
const users = await userRepository.find({
  relations: ['posts'],
});
```

### Use Indexes

```typescript
@Entity()
@Index(['email'])
@Index(['firstName', 'lastName'])
export class User {
  @Column()
  @Index()
  email: string;

  @Column()
  firstName: string;

  @Column()
  lastName: string;
}
```

### Cascade Operations

```typescript
@OneToMany(() => Post, (post) => post.author, {
  cascade: true, // Saves/removes related posts
  onDelete: "CASCADE", // Database-level cascade
})
posts: Post[];
```

### Naming Strategies

For consistent naming between TypeScript and database:

```typescript
import { DefaultNamingStrategy, NamingStrategyInterface } from "typeorm";
import { snakeCase } from "typeorm/util/StringUtils";

export class SnakeNamingStrategy extends DefaultNamingStrategy implements NamingStrategyInterface {
  tableName(targetName: string, userSpecifiedName: string | undefined): string {
    return userSpecifiedName ? userSpecifiedName : snakeCase(targetName);
  }

  columnName(propertyName: string, customName: string, embeddedPrefixes: string[]): string {
    return snakeCase(embeddedPrefixes.join("_")) + (customName ? customName : snakeCase(propertyName));
  }
}

// Use in data source config
namingStrategy: new SnakeNamingStrategy(),
```

## Common Mistakes

| Mistake | Why it's a problem | Do this instead |
| --- | --- | --- |
| `synchronize: true` in production | Auto-alters schema and can drop or rewrite columns, causing data loss | Keep `synchronize: false` and apply versioned migrations |
| Accessing relations inside a loop | Triggers an N+1 query storm, one query per parent row | Load with `relations: [...]` or a `leftJoinAndSelect` join |
| Marking relations `eager: true` everywhere | Every query over-fetches joined data, hurting performance | Default to explicit `relations` per query; reserve eager for always-needed links |
| Missing `experimentalDecorators` / `emitDecoratorMetadata` | Decorators and column metadata fail to compile or resolve types | Enable both in `tsconfig.json` |
| No index on frequent lookup/filter columns | Full table scans on common queries | Add `@Index()` (or composite `@Index([...])`) to those columns |
| String concatenation in query-builder `where` | Opens SQL injection and breaks parameter binding | Use parameter placeholders: `.where('x = :v', { v })` |
| Forgetting `queryRunner.release()` | Leaks pooled connections until the pool is exhausted | Always `release()` in a `finally` block |
| Editing an already-applied migration | Drifts the schema from migration history across environments | Write a new migration for every schema change |
