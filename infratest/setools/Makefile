SUBDIRS = sesearch findcon seinfo

all:
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	done

