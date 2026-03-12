# ==============================================================================
# Makefile for Registry Provisioner
# ==============================================================================

.PHONY: help cert-gen manifest-mgmt manifest-workload clean

help:
	@echo "======================================================================"
	@echo " Registry Provisioner - Command Interface"
	@echo "======================================================================"
	@echo "Usage:"
	@echo "  make cert-gen                  - Generate Root CA and Server certificates."
	@echo "  make manifest-mgmt             - Render Mgmt cluster manifests."
	@echo "                                   (Optional: Add PASS=\"<password>\")"
	@echo "  make manifest-workload IP=<IP> - Render Workload cluster manifests."
	@echo "  make clean                     - Remove all generated files/directories."
	@echo "======================================================================"

cert-gen:
	@echo "-> Initiating Certificate Generation..."
	@chmod +x cert-generator.sh
	@./cert-generator.sh

manifest-mgmt:
	@echo "-> Initiating Management Manifest Generation..."
	@chmod +x manifest-generator.sh
	@./manifest-generator.sh mgmt "$(PASS)"

manifest-workload:
ifndef IP
	$(error [ERROR] IP argument is missing. Usage: make manifest-workload IP=192.168.100.10)
endif
	@echo "-> Initiating Workload Manifest Generation for Gateway IP: $(IP)..."
	@chmod +x manifest-generator.sh
	@./manifest-generator.sh workload $(IP)

clean:
	@echo "-> Initiating Workspace Cleanup..."
	@chmod +x clean.sh
	@./clean.sh
