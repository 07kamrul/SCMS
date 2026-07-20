# Start Manual

Quick instructions to run this project. For full details see [README.md](README.md).

## Backend (Docker — recommended)

```bash
cd /root/opt/SCMS
cp .env.example .env                  # first time only
cp backend/.env.example backend/.env  # first time only; set a real JWT_SECRET_KEY
docker compose up -d                  # starts db, redis, minio, backend
```

Backend runs migrations automatically on start, then serves at:

- API docs: http://localhost:18000/docs
- Health: http://localhost:18000/api/v1/health
- MinIO console: http://localhost:19001

First time only, seed demo data:

```bash
docker compose exec backend python seed.py
```

### Stop / restart

```bash
docker compose down       # stop and remove containers (data volumes kept)
docker compose up -d      # start again
docker compose logs -f backend   # tail backend logs
docker compose ps         # check status
```

## Mobile (Flutter)

```bash
cd mobile
flutter run --dart-define-from-file=env/local.json   # targets local docker compose backend
```

## Demo credentials (after `seed.py`)

| Role | Email | Password |
|---|---|---|
| Company Owner | owner@demo.com | owner123 |
| HR Admin | hr@demo.com | hr123456 |
| Project Engineer | pe@demo.com | pe123456 |
| Site Engineer | se@demo.com | se123456 |
| Employee | emp@demo.com | emp12345 |
