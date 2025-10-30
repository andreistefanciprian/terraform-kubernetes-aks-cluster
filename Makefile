TF_TARGET=
TF_PLAN_FILE=$(TF_TARGET)-tf.tfplan
TF_EXEC=docker compose run terraform
TF_EXTRA_OPS=
TFSTATE_CONTAINER=$(shell docker compose run --rm terraform -chdir=tf_bucket output -raw container_name 2>/dev/null || echo "")
TFSTATE_STORAGE_ACCOUNT=$(shell docker compose run --rm terraform -chdir=tf_bucket output -raw storage_account_name 2>/dev/null || echo "")
TFSTATE_RESOURCE_GROUP=$(shell docker compose run --rm terraform -chdir=tf_bucket output -raw resource_group_name 2>/dev/null || echo "")
TFSTATE_DIR=tfstate/$(TF_TARGET)

all: plan

clean-orphan-containers:
	@docker rm -f $$(docker ps -aq --filter "name=terraform-kubernetes-aks-cluster-terraform-run") 2>/dev/null || echo "No matching containers to remove."

clean:
	@rm -rf $(TF_TARGET)/.terraform
	@rm -rf $(TF_TARGET)/terraform.tfstate.backup
	@rm -rf $(TF_TARGET)/terraform.tfstate
	@rm -rf $(TF_TARGET)/.terraform.lock.hcl
	@rm -rf $(TF_TARGET)/$(TF_PLAN_FILE)

get:
	$(TF_EXEC) -chdir=$(TF_TARGET) get
	$(TF_EXEC) -chdir=$(TF_TARGET) fmt

init: clean get clean-orphan-containers
	$(TF_EXEC) -chdir=$(TF_TARGET) init \
		-backend-config 'resource_group_name=$(TFSTATE_RESOURCE_GROUP)' \
		-backend-config 'storage_account_name=$(TFSTATE_STORAGE_ACCOUNT)' \
		-backend-config 'container_name=$(TFSTATE_CONTAINER)' \
		-backend-config 'key=$(TFSTATE_DIR)/terraform.tfstate' \
		-input=false

plan: init
	$(TF_EXEC) -chdir=$(TF_TARGET) plan -input=false -out=$(TF_PLAN_FILE)

deploy: plan
	$(TF_EXEC) -chdir=$(TF_TARGET) apply $(TF_PLAN_FILE) && rm $(TF_PLAN_FILE)

deploy-auto-approve: init
	$(TF_EXEC) -chdir=$(TF_TARGET) apply -input=false -auto-approve

destroy: init
	$(TF_EXEC) -chdir=$(TF_TARGET) destroy $(TF_EXTRA_OPS)

destroy-auto-approve: init
	$(TF_EXEC) -chdir=$(TF_TARGET) destroy -input=false -auto-approve

verify_version: 
	$(TF_EXEC) version

show-backend-config:
	@echo "Backend Configuration:"
	@echo "  Resource Group: $(TFSTATE_RESOURCE_GROUP)"
	@echo "  Storage Account: $(TFSTATE_STORAGE_ACCOUNT)"
	@echo "  Container: $(TFSTATE_CONTAINER)"
	@echo "  Key: $(TFSTATE_DIR)/terraform.tfstate"