# Les 6: Continuous Deployment naar Render.com

## Fase 1: Render.com Setup (15 minuten)

### Stap 1.1: Render Account
1. Ga naar [render.com](https://render.com)
2. Klik **Get Started for Free**
3. Kies **Sign up with GitHub** (dit koppelt direct je repositories)

### Stap 1.2: Nieuwe Web Service
1. Klik **New +** → **Web Service**
2. Selecteer je repository uit les 5, of je geforkte repo voor les 6
3. Als je hem niet ziet: klik **Configure account** om toegang te geven

### Stap 1.3: Configuratie
| Setting | Waarde |
|---------|--------|
| **Name** | `devops-app-[jouw-naam]` |
| **Region** | Frankfurt (EU) |
| **Branch** | `main` |
| **Runtime** | Docker |
| **Instance Type** | Free |

### Stap 1.4: Environment Variables
Klik **Advanced** → **Add Environment Variable**:

| Key | Value |
|-----|-------|
| `NODE_ENV` | `production` |

> ⚠️ **Let op:** Render zet automatisch een `PORT` variable. Je app MOET hierop luisteren!

### Stap 1.5: Create Web Service
Klik **Create Web Service** en wacht op de eerste deploy.

---

## Fase 2: App Aanpassen voor Render (15 minuten)

Je app uit les 5 moet mogelijk aangepast worden om op Render te werken.

### Stap 2.1: PORT Environment Variable
Open je `app.js` en controleer de port configuratie:

```javascript
// ❌ Dit werkt NIET op Render:
const port = 3000;

// ✅ Dit werkt WEL:
const port = process.env.PORT || 3000;
```

### Stap 2.2: Health Endpoint (aanbevolen)
Voeg een health endpoint toe voor Render's health checks:

```javascript
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});
```

### Stap 2.3: Dockerfile Check
Zorg dat je Dockerfile correct is:

```dockerfile
# Je multi-stage Dockerfile uit les 5
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY ../../../Downloads/devops-opdrachten%202/les6-render-deployment .

FROM node:18-alpine
WORKDIR /app
COPY --from=build /app .

# Belangrijk: EXPOSE is documentatie, Render gebruikt PORT env var
EXPOSE 10000

# Security: draai niet als root
USER node

CMD ["node", "app.js"]
```

### Stap 2.4: Commit en Push
```bash
git add .
git commit -m "feat: prepare for Render deployment"
git push origin main
```

Render detecteert de push en start automatisch een nieuwe deployment!

---

## Fase 3: Deploy Hook in Workflow (20 minuten)

Nu gaan we de deployment **triggeren vanuit onze GitHub Actions workflow**. Dit geeft meer controle: deploy alleen als alle tests slagen.

### Stap 3.1: Deploy Hook Ophalen
1. Ga naar je Render dashboard → je service
2. Klik **Settings** → scroll naar **Deploy Hook**
3. Kopieer de URL (ziet eruit als `https://api.render.com/deploy/srv-xxx?key=yyy`)

### Stap 3.2: Secret Toevoegen in GitHub
1. Ga naar je GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Klik **New repository secret**
3. Name: `RENDER_DEPLOY_HOOK`
4. Value: plak de Deploy Hook URL
5. Klik **Add secret**

### Stap 3.3: Deploy Job Toevoegen
Open je `.github/workflows/ci.yml` (of hoe je workflow ook heet) en voeg een deploy job toe:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  # === Je bestaande jobs uit les 5 ===
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ... je bestaande build steps ...

  test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      # ... je bestaande test steps ...

  push-image:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      # ... je bestaande push steps ...

  # === NIEUWE DEPLOY JOB ===
  deploy:
    name: Deploy to Render
    runs-on: ubuntu-latest
    needs: push-image  # Wacht tot image gepusht is
    if: github.ref == 'refs/heads/main'  # Alleen op main branch
    
    steps:
      - name: Trigger Render Deploy
        run: |
          curl -X POST "${{ secrets.RENDER_DEPLOY_HOOK }}"
          echo "Deployment triggered!"
      
      - name: Wait for deployment
        run: |
          echo "Deployment started. Check Render dashboard for status."
          echo "URL: https://jouw-app.onrender.com"
```

### Stap 3.4: Commit en Test
```bash
git add .
git commit -m "feat: add deployment to CI/CD pipeline"
git push origin main
```

Bekijk de Actions tab in GitHub - je ziet nu een extra "Deploy to Render" job!

---

## Fase 4: Testen en Verificatie (10 minuten)

### Stap 4.1: Check GitHub Actions
1. Ga naar je repo → **Actions**
2. Klik op de laatste workflow run
3. Verifieer dat alle jobs slagen: build → test → push-image → deploy

### Stap 4.2: Check Render Dashboard
1. Ga naar [dashboard.render.com](https://dashboard.render.com)
2. Klik op je service
3. Bekijk de **Events** - je ziet de deployment triggered door de webhook

### Stap 4.3: Test de Live App
Open je Render URL en test:
- `/` - Root endpoint
- `/health` - Health check
- `/api/greeting?name=DevOps` - API endpoint (als je die hebt)

### Stap 4.4: Test de Complete Flow
Maak een kleine wijziging om de hele pipeline te testen:

```javascript
// In app.js, verander de versie
version: '1.1.0',  // was 1.0.0
```

```bash
git add .
git commit -m "chore: bump version to 1.1.0"
git push origin main
```

Volg de flow:
1. GitHub Actions start (build → test → push → deploy)
2. Render ontvangt webhook
3. Render bouwt nieuwe image
4. App is live met nieuwe versie!

---

## Acceptatiecriteria

Je opdracht is geslaagd als:

- [ ] Je app draait op een `.onrender.com` URL
- [ ] De GitHub Actions workflow heeft een `deploy` job
- [ ] Push naar main triggert automatisch deployment
- [ ] Het `/health` endpoint werkt
- [ ] Je kunt de versie bumpen en de wijziging live zien

---

## Troubleshooting

### Deploy hook werkt niet
- Check of de secret correct is ingesteld (geen extra spaties)
- Test de hook handmatig: `curl -X POST "jouw-hook-url"`

### App start niet op Render
- Check of je luistert op `process.env.PORT`
- Bekijk de logs in Render dashboard
- Zorg dat je luistert op `0.0.0.0`, niet `localhost`

### Health check faalt
- Endpoint moet status 200 teruggeven
- App moet binnen 5 minuten opstarten

### "Service unavailable" na inactiviteit
- Normaal op gratis tier - services stoppen na 15 min inactiviteit
- Eerste request na inactiviteit duurt 30-60 sec (cold start)

---

## Bonus Opdrachten

### Bonus 1: Deployment Status Check
Voeg een stap toe die wacht tot de deployment klaar is:

```yaml
- name: Wait for deployment to be live
  run: |
    echo "Waiting for deployment..."
    sleep 60
    curl -f https://jouw-app.onrender.com/health || exit 1
    echo "Deployment successful!"
```

### Bonus 2: Slack/Discord Notificatie
Stuur een bericht naar Slack of Discord na succesvolle deployment:

```yaml
- name: Notify Slack
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"✅ Deployment successful!"}' \
      ${{ secrets.SLACK_WEBHOOK }}
```

### Bonus 3: Environment-specifieke Deployments
Maak aparte jobs voor staging en production:

```yaml
deploy-staging:
  if: github.ref == 'refs/heads/develop'
  # ... deploy naar staging

deploy-production:
  if: github.ref == 'refs/heads/main'
  # ... deploy naar production
```



## Meer Informatie

- [Render Deploy Hooks](https://render.com/docs/deploy-hooks)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Render Environment Variables](https://render.com/docs/environment-variables)