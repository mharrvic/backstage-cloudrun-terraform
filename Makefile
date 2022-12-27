.PHONY: 

deploy:
	gcloud builds submit --config cloudbuild.yaml --project terraform-cloudrun-371209