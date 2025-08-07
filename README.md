# Project Gamma - Logistics System

Project Gamma is a backend system for logistics management, designed as an in-depth study of modern software architectures in the **Node.js** ecosystem. The application is built as a **Modular Monolith** with **NestJS** and **TypeScript**, strictly applying the principles of **Clean Architecture**, **Domain-Driven Design (DDD)**, and **CQRS (Command Query Responsibility Segregation)**.

The application handles asynchronous internal communication and task decoupling with **RabbitMQ**. The database interaction with **PostgreSQL** is managed by **Prisma ORM**, and high-performance caching is handled by **Redis**.

The project is test-oriented at all levels and features a CI/CD pipeline using **GitHub Actions**.

## 📚 Documentation

For a detailed explanation of the business domain, user roles, core entities, and business rules, please refer to the documentation folder:

- 🇧🇷 **[Documentação de Domínio e Regras de Negócio (PT-BR)](./docs/pt-br/rules.md)**
- 🇬🇧 **[Domain and Business Rules Documentation (EN)](./docs/en/rules.md)**

## ✨ Core Features

- **Shipment Management**: Creation and lifecycle management of shipments.
- **Real-time Tracking**: Public and private tracking of shipment status.
- **Route Planning**: Management of routes, trucks, and warehouses.
- **User Control**: Role-based access control for Admins, Dispatchers, and Drivers.
- **Asynchronous Processing**: Event-driven jobs for validation, notifications, and auditing.

## 🛠️ Tech Stack & Architectural Patterns

This section details the modern, "overengineered" stack chosen to maximize learning and robustness.

### Architecture & Patterns

- **Language**: **TypeScript**
- **Core Framework**: **NestJS**
- **Architecture**: **Clean Architecture**, with a clear separation between Domain, Application, and Infrastructure layers, implemented in a **Modular Monolith**.
- **Design Patterns**:
  - **Domain-Driven Design (DDD)**: For modeling the business core.
  - **CQRS (Command Query Responsibility Segregation)**: Using the `@nestjs/cqrs` module to separate write (Commands) and read (Queries) operations.
  - **Event Sourcing (Optional Advanced)**: For critical use cases where the full history of changes (events) is the source of truth.

### Database & Persistence

- **Relational Database**: **PostgreSQL**
- **ORM / Query Builder**: **Prisma**
- **Caching**: **Redis**, integrated via `@nestjs/cache-manager`.

### API & Asynchronous Communication

- **External API**: **REST API**, to expose the system's functionalities following best practices.
- **Internal Asynchronous Communication**:
  - **Message Queues**: **RabbitMQ**, to process domain events, notifications, and background tasks in a decoupled manner within the monolith, increasing API responsiveness and resilience.

### Security & Authentication

- **Authentication**: **Passport.js**, via `@nestjs/passport` and `passport-jwt` for a JWT-based authentication strategy.
- **Password Hashing**: **bcrypt**.
- **Data Validation**: `class-validator` and `class-transformer` for automatic DTO validation.

### Testing

- **Testing Framework**: **Jest**
- **Unit Tests**: Focused on domain classes, use cases (Command/Query Handlers), and services.
- **Integration Tests**: Testing the interaction between NestJS modules, especially with the database.
- **E2E Tests**: Using **Supertest** (integrated with NestJS) to test the API endpoints.
- **Test Infrastructure**: **Testcontainers**, to spin up databases and other services in Docker containers during integration tests.

### DevOps & Observability

- **Containerization**: **Docker** and **Docker Compose** for the development environment.
- **CI/CD**: **GitHub Actions** for automating builds, tests, and linting on every push/pull request.
- **Observability**:
  - **Tracing**: **OpenTelemetry**, to trace requests through complex flows and asynchronous events within the application.
  - **Logging**: Structured logging with **Pino** or **Winston**.
  - **Monitoring**: **Prometheus** for metrics collection and **Grafana** for visualization.

### API Documentation

- **REST API**: Automatic documentation with **Swagger**, via `@nestjs/swagger`.

## 🚀 Getting Started

1.  **Clone the repository:**
    ```bash
    git clone <your-repository-url>
    cd project-gamma
    ```
2.  **Install dependencies:**
    ```bash
    npm install
    ```
3.  **Set up your environment variables:**
    - Copy the `.env.example` file to `.env` and fill in the required values (database credentials, JWT secret, etc.).
4.  **Run the database and other services with Docker:**
    ```bash
    docker-compose up -d
    ```
5.  **Run the Prisma migrations:**
    ```bash
    npx prisma migrate dev
    ```
6.  **Start the application in development mode:**
    `bash
    npm run start:dev
    `
    The application will be available at `http://localhost:3000`. The Swagger API documentation will be at `http://localhost:3000/api`.
