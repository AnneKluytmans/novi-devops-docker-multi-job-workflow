# Les 7: Pipeline Optimalisatie & DevSecOps

## Fase 1: Analyseer de Problemen

### Problemen
1. **Geen caching** - Dependencies worden elke keer opnieuw gedownload
2. **Sequentieel** - Jobs wachten onnodig op elkaar
3. **Geen security** - Geen dependency of container scanning
4. **Altijd deploy** - Deployt ook bij PRs (niet alleen main)
5. **Dubbel werk** - Checkout en install in elke job

### Starter Pipeline
```yaml
name: Suboptimal Pipeline

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint  # Wacht onnodig op lint
    steps:
      - uses: actions/checkout@v4
      - run: npm install  # Dubbel werk!
      - run: npm test

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - run: npm install  # Weer dubbel werk!
      - run: npm run build
      - run: docker build -t app:latest .

  deploy:
    runs-on: ubuntu-latest
    needs: build
    steps:  # Deployt bij ELKE push, ook PRs!
      - run: echo "Deploying..."
```

---

## Fase 2: Caching Toevoegen

### npm Cache
```yaml
- name: Setup Node.js with cache
  uses: actions/setup-node@v4
  with:
    node-version: '18'
    cache: 'npm'  # Cachet node_modules automatisch
```

### Docker Layer Cache
```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3

- name: Build with cache
  uses: docker/build-push-action@v5
  with:
    context: .
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### ✅ Verwachte verbetering
- Eerste run: ~3 minuten
- Volgende runs: ~1 minuut (70% sneller!)

---

## Fase 3: Parallellisatie

### Jobs die parallel kunnen draaien
```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps: # ...

  test:
    runs-on: ubuntu-latest
    # GEEN needs: lint - draait parallel!
    steps: # ...

  security-scan:
    runs-on: ubuntu-latest
    # Draait ook parallel
    steps: # ...

  build:
    runs-on: ubuntu-latest
    needs: [lint, test, security-scan]  # Wacht op alle checks
    steps: # ...
```

### Matrix voor meerdere Node versies
```yaml
test:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      node-version: [18, 20]
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ matrix.node-version }}
```

---

## Fase 4: Security Scanning

### Dependency Scanning (npm audit)
```yaml
security-audit:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: npm audit --audit-level=high
      continue-on-error: true  # Fail niet direct
    
    - name: Upload audit report
      if: always()
      run: npm audit --json > audit-report.json
```

### Container Scanning (Trivy)
```yaml
container-scan:
  runs-on: ubuntu-latest
  needs: build
  steps:
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'app:latest'
        format: 'table'
        exit-code: '1'
        severity: 'CRITICAL,HIGH'
```

### CodeQL (SAST)
```yaml
codeql:
  runs-on: ubuntu-latest
  permissions:
    security-events: write
  steps:
    - uses: actions/checkout@v4
    - uses: github/codeql-action/init@v3
      with:
        languages: javascript
    - uses: github/codeql-action/analyze@v3
```

---

## Fase 5: Slimme Conditionals

### Deploy alleen op main
```yaml
deploy:
  needs: [build, container-scan]
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  runs-on: ubuntu-latest
```

### Skip bij bepaalde commits
```yaml
jobs:
  build:
    if: "!contains(github.event.head_commit.message, '[skip ci]')"
```

### Conditional steps
```yaml
- name: Deploy to staging
  if: github.ref == 'refs/heads/develop'
  run: # ...

- name: Deploy to production
  if: github.ref == 'refs/heads/main'
  run: # ...
```

---

## ✅ Acceptatiecriteria

Je geoptimaliseerde pipeline moet:

- [ ] npm dependencies cachen
- [ ] Docker layers cachen
- [ ] lint en test parallel draaien
- [ ] Security scan bevatten (npm audit of Trivy)
- [ ] Alleen deployen naar main branch
- [ ] Minstens 50% sneller zijn dan de originele

---

## 📊 Vergelijking

| Aspect | Suboptimaal | Geoptimaliseerd |
|--------|-------------|-----------------|
| **Tijd** | ~5 min | ~2 min |
| **Caching** | ❌ Geen | ✅ npm + Docker |
| **Parallellisatie** | ❌ Sequentieel | ✅ lint/test/scan parallel |
| **Security** | ❌ Geen | ✅ npm audit + Trivy |
| **Conditionals** | ❌ Altijd deploy | ✅ Alleen main |

---

## 📚 Bronnen

- [GitHub Actions Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [Docker Build Cache](https://docs.docker.com/build/cache/)
- [Trivy Container Scanner](https://aquasecurity.github.io/trivy/)
- [GitHub CodeQL](https://codeql.github.com/)
