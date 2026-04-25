#!/bin/bash
# Deploy to Google Cloud Run with CPU boost enabled for cold starts
gcloud run deploy sentinel-core \
    --source . \
    --port 8080 \
    --allow-unauthenticated \
    --cpu-boost \
    --region us-central1 \
    --memory 2Gi \
    --cpu 2
