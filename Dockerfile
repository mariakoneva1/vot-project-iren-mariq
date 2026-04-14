FROM python:3.12-slim

ENV APP_ENV=production \
    APP_HOST=0.0.0.0 \
    PORT=8000 \
    DATA_DIR=/data

WORKDIR /srv/app

RUN adduser --disabled-password --gecos "" appuser

COPY app ./app

RUN mkdir -p /data && chown -R appuser:appuser /srv/app /data

USER appuser

EXPOSE 8000

CMD ["python", "-m", "app.server"]

