SUBDIRS = semanage semodule audit2allow rlpkg

all:
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	done

