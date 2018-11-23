TARGET = /usr/local/bin
SOURCE = $(shell pwd)
FILES = $(shell ls | grep -E "\.(pl|sh)$$" )

all: install
	@echo "Finished."

.PHONY: make
install:
	@echo "Installing the utilities to $(TARGET)"
	@for FILE in $(FILES); \
			do \
				echo -e "\tInstalling $$FILE to $(TARGET)"; \
				sudo rm -f $(TARGET)/$$FILE; \
				sudo ln -s $(SOURCE)/$$FILE $(TARGET); \
			done
