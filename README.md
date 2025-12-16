# Les 5 - CD-Ready Pipeline

![CI/CD Pipeline](https://github.com/AnneKluytmans/novi-devops-docker-multi-job-workflow/actions/workflows/cicd.yml/badge.svg)

## Quick Start

### Lokaal draaien

```bash
# Installeer dependencies
npm install

# Start development server
npm run dev

# Of: start production server
npm start
```

### Docker

```bash
# Build image
docker build -t novi-devops-2025-11-les-5 .

# Run container
docker run -p 3000:3000 novi-devops-2025-11-les-5
```

### Van GHCR (na opdracht)

```bash
# Pull image
docker pull ghcr.io/annekluytmans/my-app:latest

# Run container
docker run -p 3000:3000 ghcr.io/annekluytmans/my-app:latest
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Welcome message |
| GET | `/health` | Health check |
| GET | `/api/items` | Get all items |
| GET | `/api/items/:id` | Get item by ID |
| POST | `/api/items` | Create new item |

## Development

```bash
npm install
npm test
npm start
```

## Tests

```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage
```

## Project Structure

```
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions workflow
├── src/
│   ├── index.js            # Express app
│   └── data.js             # Data module
├── tests/
│   ├── api.test.js         # API tests
│   └── data.test.js        # Data module tests
├── Dockerfile              # Multi-stage Docker build
├── package.json
└── README.md
```
