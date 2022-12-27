.PHONY: 

deploy:
	gcloud builds submit --config cloudbuild.yaml --project your-gcp-project-id