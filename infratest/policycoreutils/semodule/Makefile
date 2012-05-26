all: base dontaudit

base: dontaudit
	@echo "[semodule] rebuild base policy (re-enable dontaudit too)"
	semodule -B

dontaudit:
	@echo "[semodule] disable dontaudit statements"
	semodule -DB

list:
	@echo "[semodule] listing loaded SELinux modules"
	semodule -l | grep -q userdomain
