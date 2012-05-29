SUBDIRS = policycoreutils setools

all:
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	done
	@echo "!! "
	@echo "!! Do not forget to run the tests with Python 2 and with Python 3"
	@echo "!! "

