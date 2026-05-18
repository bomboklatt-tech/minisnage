.PHONY: vm vm-uboot rpi4 rpi5 rockpro64 all run-vm run-vm-uboot update check clean help shell

NOM := nix run --inputs-from . 'nixpkgs\#nix-output-monitor' --

help:
	@echo "Targets:"
	@echo "  make vm           - build VM qcow2 for the host arch (via nom)"
	@echo "  make vm-uboot     - build aarch64 u-boot test image (mirrors SBC boot path)"
	@echo "  make rpi4         - build Raspberry Pi 4 SD image (via nom)"
	@echo "  make rpi5         - build Raspberry Pi 5 SD image (via nom)"
	@echo "  make rockpro64    - build RockPro64 SD image (via nom)"
	@echo "  make all          - build all four"
	@echo "  make run-vm       - boot the UEFI VM in QEMU"
	@echo "  make run-vm-uboot - boot the u-boot VM in QEMU (SBC-like boot path)"
	@echo "  make shell      - enter devshell (nom, qemu)"
	@echo "  make check      - nix flake check"
	@echo "  make update     - nix flake update"
	@echo "  make clean      - remove ./result symlinks"

vm:
	$(NOM) build .#vm

vm-uboot:
	$(NOM) build .#vm-uboot

rpi4:
	$(NOM) build .#rpi4

rpi5:
	$(NOM) build .#rpi5

rockpro64:
	$(NOM) build .#rockpro64

all: vm rpi4 rpi5 rockpro64

run-vm: vm
	nix run .#run-vm

run-vm-uboot: vm-uboot
	nix run .#run-vm-uboot

shell:
	nix develop

check:
	nix flake check

update:
	nix flake update

clean:
	rm -f result result-*
