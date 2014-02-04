
DEST= /auto/gliese_d/projects/repacketizer/

all:
	@echo nothing to do

copy:
	@for f in *.v *.hex ; do \
		cmp -s $$f $(DEST)/$$f || ( \
			echo copying $$f ; \
			cp $$f $(DEST)/$$f ) ; \
	done
