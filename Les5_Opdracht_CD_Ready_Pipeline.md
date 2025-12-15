# Opdracht Les 5: Bouw een CD-Ready Pipeline

## Wat ga je bouwen?

Een complete CI pipeline die:
1. ✅ Tests draait in een aparte job
2. ✅ Een Docker image bouwt met unieke tag
3. ✅ De image pusht naar GitHub Container Registry
4. ✅ Klaar is voor deployment in Les 6

---

## Deel 1: Multi-Job Workflow

### Stap 1.1: Maak twee jobs

Pas je `.github/workflows/ci.yml` aan naar deze structuur:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  # Job 1: Testen
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        run: npm test

  # Job 2: Bouwen (wacht op test)
  build:
    needs: test  # 👈 BELANGRIJK: wacht tot test klaar is
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .
```

### Stap 1.2: Test de workflow

```bash
git add .
git commit -m "Add multi-job workflow"
git push
```

**Check in GitHub:**
- Ga naar Actions tab
- Je ziet nu twee jobs: `test` en `build`
- `build` start pas als `test` groen is

### Checkpoint 1
- [ ] Workflow heeft twee jobs
- [ ] Build job wacht op test job (`needs: test`)
- [ ] Beide jobs draaien succesvol

---

## Deel 2: Docker Image Bouwen

### Stap 2.1: Zorg dat je een Dockerfile hebt

Als je nog geen Dockerfile hebt, maak er een:

```dockerfile
# Dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

### Stap 2.2: Verbeter de build job

Update je build job met de juiste image naam voor GHCR:

```yaml
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker tag ghcr.io/${{ github.repository }}:${{ github.sha }} ghcr.io/${{ github.repository }}:latest
      
      - name: List images
        run: docker images
```

### Stap 2.3: Begrijp de image tag

```
ghcr.io / jouw-username / jouw-repo : abc123def
   │            │             │           │
   │            │             │           └── Tag (commit SHA)
   │            │             └── Repository naam
   │            └── GitHub username
   └── GitHub Container Registry
```

### Checkpoint 2
- [ ] Dockerfile bestaat en is correct
- [ ] Docker image wordt gebouwd in CI
- [ ] Image heeft SHA tag én latest tag

---

## Deel 3: Push naar GHCR

### Stap 3.1: Voeg permissions toe

GitHub Container Registry vereist speciale permissions:

```yaml
  build:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write  # 👈 NIEUW: nodig voor GHCR push
    steps:
      # ... rest van de steps
```

### Stap 3.2: Login en push

Voeg login en push steps toe:

```yaml
  build:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to GitHub Container Registry
        run: echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Build Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker tag ghcr.io/${{ github.repository }}:${{ github.sha }} ghcr.io/${{ github.repository }}:latest

      - name: Push to GHCR
        run: |
          docker push ghcr.io/${{ github.repository }}:${{ github.sha }}
          docker push ghcr.io/${{ github.repository }}:latest
```

### Stap 3.3: Maak package public (optioneel)

Na de eerste push:
1. Ga naar je GitHub profiel
2. Klik op "Packages"
3. Klik op je package
4. Settings → Change visibility → Public

### Stap 3.4: Verifieer de push

Na een succesvolle workflow:
1. Ga naar je repository op GitHub
2. Kijk rechts bij "Packages"
3. Je zou je image moeten zien

**Of via command line:**
```bash
docker pull ghcr.io/jouw-username/jouw-repo:latest
```

### Checkpoint 3
- [ ] Permissions zijn toegevoegd
- [ ] Login naar GHCR werkt
- [ ] Image is gepusht naar GHCR
- [ ] Image is zichtbaar in GitHub Packages

---

## 🏷Deel 4: Badge & Afronding

### Stap 4.1: Voeg workflow badge toe

1. Ga naar Actions tab
2. Klik op je workflow
3. Klik "..." → "Create status badge"
4. Kopieer de markdown

### Stap 4.2: Update README

```markdown
# Mijn Project

![CI/CD Pipeline](https://github.com/JOUW-USERNAME/JOUW-REPO/actions/workflows/ci.yml/badge.svg)

## Quick Start

```bash
# Pull de image
docker pull ghcr.io/JOUW-USERNAME/JOUW-REPO:latest

# Run de container
docker run -p 3000:3000 ghcr.io/JOUW-USERNAME/JOUW-REPO:latest
```

## Development

```bash
npm install
npm test
npm start
```


### Checkpoint 4
- [ ] Badge is toegevoegd aan README
- [ ] README bevat pull instructies

---

## Bonus Opdrachten

### Bonus A: Aparte Push Job (3 jobs)

Splits build en push in aparte jobs:

```yaml
jobs:
  test:
    # ... test job

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
      - name: Save image
        run: docker save ghcr.io/${{ github.repository }}:${{ github.sha }} > image.tar
      - uses: actions/upload-artifact@v4
        with:
          name: docker-image
          path: image.tar

  push:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      packages: write
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: docker-image
      - name: Load image
        run: docker load < image.tar
      - name: Login to GHCR
        run: echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      - name: Push image
        run: docker push ghcr.io/${{ github.repository }}:${{ github.sha }}
```

### Bonus B: Matrix Build

Test op meerdere Node versies:

```yaml
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm test
```

### Bonus C: Branch Tag

Tag de image ook met de branch naam:

```yaml
      - name: Build and tag
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker tag ghcr.io/${{ github.repository }}:${{ github.sha }} ghcr.io/${{ github.repository }}:${{ github.ref_name }}
```

### Bonus D: Eigen Secret

1. Maak een secret aan:
   - Settings → Secrets → New repository secret
   - Naam: `MY_SECRET`
   - Waarde: iets willekeurigs

2. Gebruik in workflow:
```yaml
      - name: Use secret
        run: echo "Secret length: ${#MY_SECRET}"
        env:
          MY_SECRET: ${{ secrets.MY_SECRET }}
```

---

## Troubleshooting

### "Permission denied" bij push naar GHCR

**Oorzaak:** `permissions: packages: write` ontbreekt.

**Oplossing:**
```yaml
build:
  permissions:
    contents: read
    packages: write
```

### "unauthorized" bij docker login

**Oorzaak:** GITHUB_TOKEN heeft niet de juiste rechten.

**Oplossing:** Check dat je `permissions` correct hebt ingesteld op job niveau.

### Image niet zichtbaar in Packages

**Mogelijke oorzaken:**
1. Push is nog niet klaar
2. Repository naam mismatch (hoofdlettergevoelig!)
3. Package is private

**Oplossing:** Check de workflow logs voor errors.

### "needs" job wordt geskipt

**Oorzaak:** De job waar je op wacht is gefaald.

**Oplossing:** Fix eerst de falende job.

### Docker build faalt

**Check:**
1. Bestaat Dockerfile in root?
2. Is de syntax correct?
3. Werkt `docker build` lokaal?

---

## Complete Workflow (Referentie)

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        run: npm test

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to GitHub Container Registry
        run: echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Build Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker tag ghcr.io/${{ github.repository }}:${{ github.sha }} ghcr.io/${{ github.repository }}:latest

      - name: Push to GHCR
        run: |
          docker push ghcr.io/${{ github.repository }}:${{ github.sha }}
          docker push ghcr.io/${{ github.repository }}:latest
```

---

## Resources

- [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker build-push-action](https://github.com/docker/build-push-action)
- [GitHub Actions: Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
